//
//  CustomTableCell.swift
//  Test
//
//  Created by Sonal on 25/08/26.
//

import UIKit

class CustomTableCell: UITableViewCell {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var ourImage: UIImageView!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func startLoader() {
        activityIndicator.startAnimating()
        ourImage.isHidden = true
    }
    
    func setImage(image: UIImage) {
        ourImage.image = image
        ourImage.isHidden = false
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }
}
