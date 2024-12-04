import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel! // 显示餐厅名称
    @IBOutlet weak var buildingLabel: UILabel! // 显示餐厅建筑
    @IBOutlet weak var descriptionLabel: UILabel! // 显示餐厅描述
    @IBOutlet weak var openingTimesLabel: UILabel! // 显示开放时间
    @IBOutlet weak var urlButton: UIButton! // 打开餐厅网址按钮

    var venue: Venue? // 用于接收传递的数据

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 显示餐厅数据
        if let venue = venue {
            nameLabel.text = venue.name
            buildingLabel.text = venue.building
            descriptionLabel.text = "Description: \(venue.description)"// 设置餐厅描述到 UILabel
            openingTimesLabel.text = "Opening Times:\n" + venue.opening_times.joined(separator: "\n")
            
            // 配置按钮（如果餐厅有官网链接）
            if let url = venue.URL {
                urlButton.setTitle("Visit Website", for: .normal)
                urlButton.isHidden = false
                urlButton.addTarget(self, action: #selector(openURL), for: .touchUpInside)
            } else {
                urlButton.isHidden = true
            }
        }
    }

    // 打开餐厅网址
    @objc func openURL() {
        if let url = venue?.URL {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

