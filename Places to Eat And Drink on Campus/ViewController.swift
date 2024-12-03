import UIKit
import MapKit
import CoreLocation

// JSON 数据模型
struct FoodData: Codable {
    var food_venues: [Venue] // 餐饮场所列表
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
        
        // 首次定位时，设置地图区域
        if firstRun {
            firstRun = false
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 地图缩放级别
            let region = MKCoordinateRegion(center: location, span: span)
            myMap.setRegion(region, animated: true)
            
            // 启用用户位置跟踪（延迟5秒）
            Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(startUserTracking), userInfo: nil, repeats: false)
        }
        
        // 如果启用了用户位置跟踪，持续更新地图中心
        if startTrackingTheUser {
            myMap.setCenter(location, animated: true)
        }
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
        theTable.reloadData() // 刷新表格
        addAnnotationsToMap() // 添加地图标注
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
        content.text = venue.name // 餐厅名称
        content.secondaryText = venue.building // 餐厅建筑
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
}

