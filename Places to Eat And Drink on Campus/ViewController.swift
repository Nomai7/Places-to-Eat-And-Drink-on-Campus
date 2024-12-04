import UIKit
import MapKit
import CoreLocation

// JSON 数据模型
struct FoodData: Codable {
    var food_venues: [Venue] // 餐饮场所列表
}

enum VenueStatus: String, Codable {
    case favorite = "favorite"  // 喜欢
    case disliked = "disliked" // 不喜欢
    case normal = "normal"     // 默认
}

// 餐厅模型
struct Venue: Codable {
    let name: String // 餐厅名称
    let building: String // 所在建筑
    let lat: String // 纬度
    let lon: String // 经度
    let description: String // 描述信息
    let opening_times: [String] // 营业时间
    let amenities: [String]? // 设施
    let photos: [String]? // 图片
    let URL: URL? // 餐厅官网链接
    
    var distance: Double? // 临时存储距离，用于排序
    var status: VenueStatus = .normal // 默认值为正常状态

    // 排除 `status` 和 `distance`，避免影响 JSON 解码
    enum CodingKeys: String, CodingKey {
        case name, building, lat, lon, description, opening_times, amenities, photos, URL
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    // 连接到 Storyboard 的 IBOutlet
    @IBOutlet weak var myMap: MKMapView! // 地图视图
    @IBOutlet weak var theTable: UITableView! // 表格视图
    
    var locationManager = CLLocationManager() // 用于获取用户位置的管理器
    var venues: [Venue] = [] // 存储解析后的餐饮场所数据
    var firstRun = true // 用于控制是否首次定位
    var startTrackingTheUser = false // 是否开始跟踪用户位置
    var selectedVenue: Venue? // 选中的餐饮场所，用于数据传递到详情页面
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置地图和表格的代理
        myMap.delegate = self
        theTable.delegate = self
        theTable.dataSource = self
        
        // 初始化位置管理器
        setupLocationManager()
        
        // 获取餐饮场所数据
        fetchVenueData()
        
        loadStatuses() // 加载喜爱状态
    }
    
    // MARK: - 初始化位置管理器
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 设置定位精度
        locationManager.requestWhenInUseAuthorization() // 请求用户授权
        locationManager.startUpdatingLocation() // 开始更新位置
        myMap.showsUserLocation = true // 在地图上显示用户位置
    }
    
    // MARK: - 处理位置更新
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        let latitude = userLocation.coordinate.latitude
        let longitude = userLocation.coordinate.longitude
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // 首次定位时设置地图区域
        if firstRun {
            firstRun = false
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: location, span: span)
            myMap.setRegion(region, animated: true)
            
            // 延迟启用位置跟踪
            Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(startUserTracking), userInfo: nil, repeats: false)
        }
        
        // 如果启用了用户位置跟踪，保持地图中心为用户位置
        if startTrackingTheUser {
            myMap.setCenter(location, animated: true)
        }

        // **实时更新距离并刷新 UI**
        updateUI()
    }

    
    // 启用用户位置跟踪
    @objc func startUserTracking() {
        startTrackingTheUser = true
    }
    
    // 处理定位失败的情况
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    // MARK: - 获取和解析 JSON 数据
    func fetchVenueData() {
        guard let url = URL(string: "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/eating_venues/data.json") else {
            print("Invalid URL")
            return
        }
        
        // 使用 URLSession 发起网络请求
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            // 使用 JSONDecoder 解析数据
            do {
                let decoder = JSONDecoder()
                let foodData = try decoder.decode(FoodData.self, from: data)
                self.venues = foodData.food_venues // 存储解析后的餐饮场所数据
                
                // 加载用户保存的喜爱状态
                self.loadStatuses()
                
                // 更新 UI 必须在主线程
                DispatchQueue.main.async {
                    self.updateUI()
                }
            } catch let decodingError {
                print("Error decoding JSON: \(decodingError)")
            }
        }
        task.resume()
    }
    
    // 更新 UI：刷新表格和添加地图标注
    func updateUI() {
        // 获取用户当前位置
        guard let userLocation = locationManager.location else {
            print("User location is unavailable")
            return
        }

        // 计算每个餐厅与用户的距离
        for i in 0..<venues.count {
            if let latitude = Double(venues[i].lat), let longitude = Double(venues[i].lon) {
                let venueLocation = CLLocation(latitude: latitude, longitude: longitude)
                venues[i].distance = userLocation.distance(from: venueLocation) // 距离以米为单位
            } else {
                venues[i].distance = nil // 如果经纬度无效，则距离为 nil
            }
        }

        // 按距离从近到远排序
        venues.sort { (venue1, venue2) -> Bool in
            guard let distance1 = venue1.distance, let distance2 = venue2.distance else {
                return false // 如果距离为空，保持原顺序
            }
            return distance1 < distance2
        }

        // 刷新表格视图
        theTable.reloadData()
        
        // 重新更新地图标注
        addAnnotationsToMap()
    }


    
    // MARK: - 在地图上添加标注
    func addAnnotationsToMap() {
        myMap.removeAnnotations(myMap.annotations) // 清除旧标注
        
        for venue in venues {
            guard let latitude = Double(venue.lat), let longitude = Double(venue.lon) else {
                continue
            }
            let annotation = MKPointAnnotation()
            annotation.title = venue.name // 标注标题
            annotation.subtitle = venue.building // 标注副标题
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude) // 标注位置
            myMap.addAnnotation(annotation)
        }
    }

    
    // MARK: - 表格视图数据源方法
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return venues.count // 返回场所数量
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        let venue = venues[indexPath.row]

        // 设置餐厅名称
        content.text = venue.name
        
        // 设置距离和建筑信息
        if let distance = venue.distance {
            // 格式化距离为 "m" 或 "km"
            let formattedDistance = distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance)
            content.secondaryText = "\(venue.building) - \(formattedDistance)"
        } else {
            // 如果没有距离信息，仅显示建筑名称
            content.secondaryText = venue.building
        }
        
        // 创建“喜爱”按钮
            let favoriteButton = UIButton(type: .system)
            favoriteButton.tag = indexPath.row // 标记行索引
            favoriteButton.addTarget(self, action: #selector(toggleFavoriteStatus(_:)), for: .touchUpInside)

            // 根据状态设置按钮图标
            switch venue.status {
            case .favorite:
                favoriteButton.setTitle("❤️", for: .normal)
            case .disliked:
                favoriteButton.setTitle("🖤", for: .normal)
            case .normal:
                favoriteButton.setTitle("🤍", for: .normal)
            }

            // 设置按钮布局
            favoriteButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            cell.accessoryView = favoriteButton // 将按钮作为单元格的 accessoryView

        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - 表格点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedVenue = venues[indexPath.row] // 设置选中的场所
        performSegue(withIdentifier: "toDetail", sender: self) // 触发 Segue
    }
    
    // MARK: - 地图标注点击事件
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        guard let venue = venues.first(where: { $0.name == annotation.title }) else { return }
        selectedVenue = venue // 设置选中的场所
        performSegue(withIdentifier: "toDetail", sender: self) // 触发 Segue
    }
    
    // MARK: - 准备跳转到详情页面
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDetail",
           let detailVC = segue.destination as? DetailViewController {
            detailVC.venue = selectedVenue // 传递数据到详情页面
        }
    }
    
    @objc func toggleFavoriteStatus(_ sender: UIButton) {
        let rowIndex = sender.tag // 获取按钮对应的行索引
        var venue = venues[rowIndex]

        // 切换喜爱状态
        switch venue.status {
        case .normal:
            venue.status = .favorite
        case .favorite:
            venue.status = .disliked
        case .disliked:
            venue.status = .normal
        }

        venues[rowIndex] = venue // 更新数据源中的餐厅

        saveStatuses() // 保存喜爱状态
        theTable.reloadRows(at: [IndexPath(row: rowIndex, section: 0)], with: .automatic) // 刷新表格
    }
    
    func saveStatuses() {
        // 创建一个字典，存储餐厅名称与喜爱状态的对应关系
        let statuses = venues.reduce(into: [String: String]()) { result, venue in
            result[venue.name] = venue.status.rawValue
        }
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(statuses, forKey: "VenueStatuses")
        UserDefaults.standard.synchronize() // 确保立即保存
    }

    
    func loadStatuses() {
        // 从 UserDefaults 获取保存的状态
        if let savedStatuses = UserDefaults.standard.dictionary(forKey: "VenueStatuses") as? [String: String] {
            for i in 0..<venues.count {
                // 查找每个餐厅的保存状态并更新
                if let statusRawValue = savedStatuses[venues[i].name],
                   let status = VenueStatus(rawValue: statusRawValue) {
                    venues[i].status = status
                }
            }
        }
    }




}

