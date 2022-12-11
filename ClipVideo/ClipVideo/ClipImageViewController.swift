//
//  ClipImageViewController.swift
//  ClipVideo
//
//  Created by 李文秀 on 2022/12/11.
//

import UIKit

class ClipImageViewController: UIViewController {
    
    enum ClipRatio {
        case ratio_1_1
        case ratio_3_4
        case ratio_4_3
    }
    
    var confirmHandler: ((UIImage?) -> Void)?
    
    private var imageView:UIImageView!
    private var scrollView: UIScrollView!
    private var maskLayer: CAShapeLayer!
    private var visibleLayer: CAShapeLayer!
    
    private let clip_ratio_1_1 = UIButton()
    private let clip_ratio_3_4 = UIButton()
    private let clip_ratio_4_3 = UIButton()
    
    private let screenWidth = UIScreen.main.bounds.size.width
    private let screenHeight = UIScreen.main.bounds.size.height
    private let clipRectWidth = UIScreen.main.bounds.size.width - 20
    private let timesThanMin: CGFloat = 5.0
    
    private let image: UIImage
    
    private var currentRatioType: ClipRatio = .ratio_1_1
    
    private var currentRatio: CGFloat {
        let ratio: CGFloat
        switch currentRatioType {
        case .ratio_1_1:
            ratio = 1
        case .ratio_3_4:
            ratio = 3/4.0
        case .ratio_4_3:
            ratio = 4/3.0
        }
        return ratio
    }
    
    private var clipRectHeight: CGFloat {
        return clipRectWidth / currentRatio
    }
    
    private var clipRectX: CGFloat {
        (screenWidth - clipRectWidth) / 2.0
    }
    private var clipRectY: CGFloat {
        (screenHeight - clipRectHeight) / 2.0
    }
    
    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        settingScrollViewZoomScale()
        updateClipRatioActionUI(ratio: currentRatioType)
    }
    
    @objc private func confirmButtonTapped() {
        let image = clipImage()
        confirmHandler?(image)
    }
    
    @objc private func clipRatio1_1(_ btn: UIButton) {
        updateClipRatioActionUI(ratio: .ratio_1_1)
    }
    
    @objc private func clipRatio3_4(_ btn: UIButton) {
        updateClipRatioActionUI(ratio: .ratio_3_4)
        
    }
    
    @objc private func clipRatio4_3(_ btn: UIButton) {
        updateClipRatioActionUI(ratio: .ratio_4_3)
    }
    
    private func updateClipRatioActionUI(ratio: ClipRatio) {
        currentRatioType = ratio
        switch ratio {
        case .ratio_1_1:
            clip_ratio_1_1.alpha = 1
            clip_ratio_3_4.alpha = 0.5
            clip_ratio_4_3.alpha = 0.5
        case .ratio_3_4:
            clip_ratio_1_1.alpha = 0.5
            clip_ratio_3_4.alpha = 1
            clip_ratio_4_3.alpha = 0.5
        case .ratio_4_3:
            clip_ratio_1_1.alpha = 0.5
            clip_ratio_3_4.alpha = 0.5
            clip_ratio_4_3.alpha = 1
        }
        scrollView.contentInset = UIEdgeInsets(top: clipRectY, left: clipRectX, bottom: clipRectY, right: clipRectX)
        let path = UIBezierPath.init(rect: view.bounds)
        let rectPath = UIBezierPath(rect: CGRect(x: clipRectX, y: clipRectY, width: clipRectWidth, height: clipRectHeight))
        path.append(rectPath)
        maskLayer.path = path.cgPath
        visibleLayer.path = rectPath.cgPath
    }
    
    private func clipImage() -> UIImage? {
        let offset = scrollView.contentOffset
        let imageSize = imageView.image?.size
        let scale = (imageView.frame.size.width) / (imageSize?.width)! / image.scale
        
        let rectX = (offset.x + clipRectX) / scale
        let rectY = (offset.y + clipRectY) / scale
        let rectWidth = clipRectWidth / scale
        let rectHeight = rectWidth / currentRatio
        let rect = CGRect.init(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
        let fixedImage = fixedImageOrientation(image)
        let resultImage = fixedImage?.cgImage?.cropping(to: rect)
        let clipImage = UIImage.init(cgImage: resultImage!)
        return clipImage
    }
    
    private func fixedImageOrientation(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up {
            return image
        }
        
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let π = Double.pi
        var transform = CGAffineTransform.identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: imageWidth, y: imageHeight)
            transform = transform.rotated(by: CGFloat(π))
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: imageWidth, y: 0)
            transform = transform.rotated(by: CGFloat(π / 2))
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: imageHeight)
            transform = transform.rotated(by: CGFloat(-π / 2))
        default:
            break
        }
        
        switch image.imageOrientation {
        case .up, .upMirrored:
            transform = transform.translatedBy(x: imageWidth, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: imageHeight, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        let context = CGContext.init(data: nil,
                                     width: Int(imageWidth),
                                     height: Int(imageHeight),
                                     bitsPerComponent: Int(image.cgImage!.bitsPerComponent),
                                     bytesPerRow: Int((image.cgImage?.bytesPerRow)!),
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: (image.cgImage?.bitmapInfo.rawValue)!)
        context!.concatenate(transform)
        
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(image.cgImage!, in: CGRect.init(x: 0, y: 0, width: imageHeight, height: imageWidth))
        default:
            context?.draw(image.cgImage!, in: CGRect.init(x: 0, y: 0, width: imageWidth, height: imageHeight))
        }
        
        let fixedImage = UIImage.init(cgImage: context!.makeImage()!)
        return fixedImage
    }
    
    private func setupSubviews() {
        scrollView = UIScrollView.init(frame: view.bounds)
        scrollView.delegate = self
        scrollView.backgroundColor = UIColor.clear
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        
        let imageViewH = image.size.height / image.size.width * screenWidth
        let offsetY = (scrollView.bounds.height - imageViewH) / 2.0
        imageView = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: screenWidth, height: imageViewH))
        imageView.image = image
        scrollView.addSubview(imageView)
        scrollView.setContentOffset(CGPoint.init(x: 0, y: -offsetY), animated: false)
        
        maskLayer = CAShapeLayer.init()
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        
        visibleLayer = CAShapeLayer.init()
        visibleLayer.lineWidth = 2
        visibleLayer.fillColor = UIColor.clear.cgColor
        visibleLayer.strokeColor = UIColor.white.cgColor
        maskLayer.addSublayer(visibleLayer)
        
        let maskView = UIView.init(frame: view.bounds)
        maskView.backgroundColor = UIColor.clear
        maskView.isUserInteractionEnabled = false
        maskView.layer.addSublayer(maskLayer)
        view.addSubview(maskView)
        
        let confirmButton = UIButton()
        confirmButton.setTitle("确定", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)
        
        clip_ratio_1_1.setImage(UIImage(named: "clip_ratio_1:1"), for: .normal)
        clip_ratio_1_1.addTarget(self, action: #selector(clipRatio1_1(_:)), for: .touchUpInside)
        clip_ratio_3_4.setImage(UIImage(named: "clip_ratio_3:4"), for: .normal)
        clip_ratio_3_4.addTarget(self, action: #selector(clipRatio3_4(_:)), for: .touchUpInside)
        clip_ratio_4_3.setImage(UIImage(named: "clip_ratio_4:3"), for: .normal)
        clip_ratio_4_3.addTarget(self, action: #selector(clipRatio4_3(_:)), for: .touchUpInside)
        let stackView = UIStackView(arrangedSubviews: [clip_ratio_1_1, clip_ratio_3_4, clip_ratio_4_3])
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 100),
            
            confirmButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
            confirmButton.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 20),
            confirmButton.widthAnchor.constraint(equalToConstant: 50),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func settingScrollViewZoomScale() {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        if imageWidth > imageHeight {
            scrollView.minimumZoomScale = clipRectWidth / (imageHeight / imageWidth * screenWidth)
        } else {
            scrollView.minimumZoomScale = clipRectWidth / screenWidth
        }
        scrollView.maximumZoomScale = (scrollView.minimumZoomScale) * timesThanMin
        scrollView.zoomScale = scrollView.minimumZoomScale > 1 ? scrollView.minimumZoomScale : 1
    }
}

extension ClipImageViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
}

