import UIKit
import MapKit
import CoreLocation

struct FoodData: Codable {
    var food_venues: [Venue]
}

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
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var myMap: MKMapView!
    @IBOutlet weak var theTable: UITableView!
    
    var locationManager = CLLocationManager()
    var venues: [Venue] = []
    var firstRun = true
    var startTrackingTheUser = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        myMap.delegate = self
        theTable.delegate = self
        theTable.dataSource = self
        
        setupLocationManager()
        fetchVenueData()
    }


    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        myMap.showsUserLocation = true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        let latitude = userLocation.coordinate.latitude
        let longitude = userLocation.coordinate.longitude
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        if firstRun {
            firstRun = false
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: location, span: span)
            myMap.setRegion(region, animated: true)
            
            Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(startUserTracking), userInfo: nil, repeats: false)
        }
        
        if startTrackingTheUser {
            myMap.setCenter(location, animated: true)
        }
    }
    
    @objc func startUserTracking() {
        startTrackingTheUser = true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    func fetchVenueData() {
        guard let url = URL(string: "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/eating_venues/data.json") else {
            print("Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let foodData = try decoder.decode(FoodData.self, from: data)
                self.venues = foodData.food_venues
                
                DispatchQueue.main.async {
                    self.updateUI()
                }
            } catch let decodingError {
                print("Error decoding JSON: \(decodingError)")
            }
        }
        
        task.resume()
    }
    
    func updateUI() {
        theTable.reloadData()
        addAnnotationsToMap()
    }
    
    func addAnnotationsToMap() {
        myMap.removeAnnotations(myMap.annotations)
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return venues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        let venue = venues[indexPath.row]
        content.text = venue.name
        content.secondaryText = venue.building
        cell.contentConfiguration = content
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 获取点击的场所
        let venue = venues[indexPath.row]
        
        // 将纬度和经度转换为 CLLocationCoordinate2D
        guard let latitude = Double(venue.lat), let longitude = Double(venue.lon) else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // 设置地图的显示区域，居中到场所位置
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        myMap.setRegion(region, animated: true)
        
        // 遍历地图上的标注并选中匹配的标注
        for annotation in myMap.annotations {
            if let title = annotation.title, title == venue.name {
                myMap.selectAnnotation(annotation, animated: true)
                break
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // 确保标注是我们添加的
        guard let annotation = view.annotation else { return }
        guard let venue = venues.first(where: { $0.name == annotation.title }) else { return }
        
        // 创建并显示弹窗
        let alert = UIAlertController(
            title: venue.name,
            message: """
            Building: \(venue.building)
            Description: \(venue.description)
            Opening Times: \(venue.opening_times.joined(separator: ", "))
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }


}

