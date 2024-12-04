import UIKit
import MapKit
import CoreLocation

// JSON 数据模型
struct FoodData: Codable {
    var food_venues: [Venue]
}

enum VenueStatus: String, Codable {
    case favorite = "favorite"
    case disliked = "disliked"
    case normal = "normal"
}

// 餐厅模型
struct Venue: Codable {
    let name: String
    let building: String
    let lat: String
    let lon: String
    let description: String
    let opening_times: [String]
    let amenities: [String]?
    let photos: [String]?
    let URL: URL?
    
    var distance: Double? // store distance
    var status: VenueStatus = .normal // default status is normal

    // Exclude `status` and `distance` to avoid affecting JSON decoding
    enum CodingKeys: String, CodingKey {
        case name, building, lat, lon, description, opening_times, amenities, photos, URL
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    
    @IBOutlet weak var myMap: MKMapView! // map
    @IBOutlet weak var theTable: UITableView! // table
    
    var locationManager = CLLocationManager() // manage the location of user
    var venues: [Venue] = [] // store data of venues after decoding
    var firstRun = true //check whether this is the first time to use
    var startTrackingTheUser = false
    var selectedVenue: Venue? // the select venue
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set map and agent
        myMap.delegate = self
        theTable.delegate = self
        theTable.dataSource = self
        
        // initialise location manager
        setupLocationManager()
        
        fetchVenueData()
        
        loadStatuses()
    }
    
    // MARK: - initialise location manager
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // set location accuracy
        locationManager.requestWhenInUseAuthorization() // Request user authorization
        locationManager.startUpdatingLocation() // Start updating location
        myMap.showsUserLocation = true // Display user location on a map
    }
    
    // MARK: - Handling location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        let latitude = userLocation.coordinate.latitude
        let longitude = userLocation.coordinate.longitude
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Set the map area when positioning for the first time
        if firstRun {
            firstRun = false
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: location, span: span)
            myMap.setRegion(region, animated: true)
            
            // Delayed enabling of location tracking
            Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(startUserTracking), userInfo: nil, repeats: false)
        }
        
        // Keep the map centered on the user's location
        if startTrackingTheUser {
            myMap.setCenter(location, animated: true)
        }

        // refresh UI in real time
        updateUI()
    }

    
    // Enable user location tracking
    @objc func startUserTracking() {
        startTrackingTheUser = true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    // MARK: - Retrieving and parsing JSON data
    func fetchVenueData() {
        guard let url = URL(string: "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/eating_venues/data.json") else {
            print("Invalid URL")
            loadFromJSONFile() // If the URL is invalid, try to load the local cache
            return
        }
        
        // Using URLSession to initiate network requests
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                
                // If the network request fails, load the local cache
                DispatchQueue.main.async {
                    self.loadFromJSONFile()
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                
                // If no data is received, load the local cache
                DispatchQueue.main.async {
                    self.loadFromJSONFile()
                }
                return
            }
            
            // Parsing data using JSONDecoder
            do {
                let decoder = JSONDecoder()
                let foodData = try decoder.decode(FoodData.self, from: data)
                self.venues = foodData.food_venues // Store parsed restaurant data
                
                // Save the latest data to local cache
                self.saveToJSONFile()
                
                // Load the user's saved favorite status
                self.loadStatuses()
                
                // Update UI must be done on the main thread
                DispatchQueue.main.async {
                    self.updateUI()
                }
            } catch let decodingError {
                print("Error decoding JSON: \(decodingError)")
                
                // If JSON decoding fails, load the local cache
                DispatchQueue.main.async {
                    self.loadFromJSONFile()
                }
            }
        }
        task.resume()
    }

    
    // Update UI: refresh table and add map annotations
    func updateUI() {
        // Get the user's current location
        guard let userLocation = locationManager.location else {
            print("User location is unavailable")
            return
        }

        // Calculate the distance between each restaurant and the user
        for i in 0..<venues.count {
            if let latitude = Double(venues[i].lat), let longitude = Double(venues[i].lon) {
                let venueLocation = CLLocation(latitude: latitude, longitude: longitude)
                venues[i].distance = userLocation.distance(from: venueLocation)
            } else {
                venues[i].distance = nil
            }
        }

        // Sort by distance from nearest to farthest
        venues.sort { (venue1, venue2) -> Bool in
            guard let distance1 = venue1.distance, let distance2 = venue2.distance else {
                return false
            }
            return distance1 < distance2
        }

        // Refresh the table view
        theTable.reloadData()
        
        // Update map annotations
        addAnnotationsToMap()
    }


    
    // MARK: -Adding markers to the map
    func addAnnotationsToMap() {
        myMap.removeAnnotations(myMap.annotations) // Clear old annotations
        
        for venue in venues {
            guard let latitude = Double(venue.lat), let longitude = Double(venue.lon) else {
                continue
            }
            let annotation = MKPointAnnotation()
            annotation.title = venue.name
            annotation.subtitle = venue.building
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            myMap.addAnnotation(annotation)
        }
    }

    
    // MARK: - Table View Data Source Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return venues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        let venue = venues[indexPath.row]

        // Set restaurant name
        content.text = venue.name
        
        // Setting distance and building information
        if let distance = venue.distance {
            let formattedDistance = distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance)
            content.secondaryText = "\(venue.building) - \(formattedDistance)"
        } else {
            content.secondaryText = venue.building
        }
        
        // Create a Like Button
            let favoriteButton = UIButton(type: .system)
            favoriteButton.tag = indexPath.row
            favoriteButton.addTarget(self, action: #selector(toggleFavoriteStatus(_:)), for: .touchUpInside)

            // Set the button icon according to the state
            switch venue.status {
            case .favorite:
                favoriteButton.setTitle("❤️", for: .normal)
            case .disliked:
                favoriteButton.setTitle("🖤", for: .normal)
            case .normal:
                favoriteButton.setTitle("🤍", for: .normal)
            }

            // Setting the button layout
            favoriteButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            cell.accessoryView = favoriteButton // 将按钮作为单元格的 accessoryView

        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - Table click event
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedVenue = venues[indexPath.row]
        performSegue(withIdentifier: "toDetail", sender: self)
    }
    
    // MARK: - Map marker click event
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        guard let venue = venues.first(where: { $0.name == annotation.title }) else { return }
        selectedVenue = venue
        performSegue(withIdentifier: "toDetail", sender: self)
    }
    
    // MARK: - Ready to jump to the details page
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDetail",
           let detailVC = segue.destination as? DetailViewController {
            detailVC.venue = selectedVenue // Trans data to the details page
        }
    }
    
    //Click the Like button
    @objc func toggleFavoriteStatus(_ sender: UIButton) {
        let rowIndex = sender.tag
        var venue = venues[rowIndex]

        // Switch status
        switch venue.status {
        case .normal:
            venue.status = .favorite
        case .favorite:
            venue.status = .disliked
        case .disliked:
            venue.status = .normal
        }

        venues[rowIndex] = venue

        saveStatuses() // Save status
        theTable.reloadRows(at: [IndexPath(row: rowIndex, section: 0)], with: .automatic)
    }
    
    func saveStatuses() {
        let statuses = venues.reduce(into: [String: String]()) { result, venue in
            result[venue.name] = venue.status.rawValue
        }
        UserDefaults.standard.set(statuses, forKey: "VenueStatuses")
        UserDefaults.standard.synchronize() // 确保立即保存
    }

    func loadStatuses() {
        if let savedStatuses = UserDefaults.standard.dictionary(forKey: "VenueStatuses") as? [String: String] {
            for i in 0..<venues.count {
                if let statusRawValue = savedStatuses[venues[i].name],
                   let status = VenueStatus(rawValue: statusRawValue) {
                    venues[i].status = status
                }
            }
        }
    }


    // MARK: - Save data to a local JSON file
    func saveToJSONFile() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentURL = urls.first else { return }
        let fileURL = documentURL.appendingPathComponent("venues.json")
        
        do {
            let data = try JSONEncoder().encode(venues)
            try data.write(to: fileURL)
            print("Data saved to \(fileURL)")
        } catch {
            print("Failed to save data to JSON file: \(error)")
        }
    }

    // MARK: - Loading data from a local JSON file
    func loadFromJSONFile() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentURL = urls.first else { return }
        let fileURL = documentURL.appendingPathComponent("venues.json")
        
        do {
            // Check if a file exists
            guard fileManager.fileExists(atPath: fileURL.path) else {
                print("No cached data found.")
                return
            }
            
            let data = try Data(contentsOf: fileURL)
            venues = try JSONDecoder().decode([Venue].self, from: data)
            print("Data loaded from \(fileURL)")
            updateUI()
        } catch {
            print("Failed to load data from JSON file: \(error)") 
        }
    }


}

