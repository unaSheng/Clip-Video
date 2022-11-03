//
//  MaskViewController.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2022/11/3.
//

import UIKit
import PhotosUI

class MaskViewController: UIViewController, PHPickerViewControllerDelegate {
    
    @IBOutlet weak var originImageView: UIImageView!
    @IBOutlet weak var maskView: MaskView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLayerContent(image: UIImage(named: "AppIcon")!)
    }
    
    private func updateLayerContent(image: UIImage) {
        originImageView.image = image
        maskView.updateLayerContent(image: image)
    }
    
    @IBAction func updateImage(_ sender: Any) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        self.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, error in
            DispatchQueue.main.async {
                if let image = reading as? UIImage {
                    self?.updateLayerContent(image: image)
                }
            }
        }
    }
}

class MaskView: UIView {
    func updateLayerContent(image: UIImage) {
        guard let maskImage = maskImage(image)?.cgImage else { return }
        self.layer.contents = maskImage
        self.layer.minificationFilter = .nearest
        self.layer.magnificationFilter = .nearest
    }
    
    private func maskImage(_ image: UIImage) -> UIImage? {
        let width: CGFloat = 9
        let height: CGFloat = width / image.size.width * image.size.height
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 1)
        image.draw(in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            return newImage
        } else {
            return nil
        }
    }
}
