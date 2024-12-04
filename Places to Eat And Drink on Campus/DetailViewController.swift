import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var buildingLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var openingTimesLabel: UILabel!
    @IBOutlet weak var urlButton: UIButton!

    var venue: Venue? // receive the transmitted data

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display restaurant data
        if let venue = venue {
            nameLabel.text = venue.name
            buildingLabel.text = venue.building
            descriptionLabel.text = "Description: \(venue.description)"// 设置餐厅描述到 UILabel
            openingTimesLabel.text = "Opening Times:\n" + venue.opening_times.joined(separator: "\n")
            
            // Configure button (if the restaurant has an official website link)
            if let url = venue.URL {
                urlButton.setTitle("Visit Website", for: .normal)
                urlButton.isHidden = false
                urlButton.addTarget(self, action: #selector(openURL), for: .touchUpInside)
            } else {
                urlButton.isHidden = true
            }
        }
    }

    // Open restaurant website
    @objc func openURL() {
        if let url = venue?.URL {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

