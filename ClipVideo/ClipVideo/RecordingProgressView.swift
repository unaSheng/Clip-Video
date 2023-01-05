//
//  RecordingProgressView.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2023/1/5.
//

import UIKit

class RecordingProgressView: UIView {
    
    typealias Action = (() -> Void)
    
    var defaultLineWidth: CGFloat = 4
    var defaultLineColors: [UIColor] = [UIColor.black, UIColor.white]
    
    var backgroundLineWidth: CGFloat = 4
    var backgroundLineColors: [UIColor] = [UIColor.red.withAlphaComponent(0.2), UIColor.blue.withAlphaComponent(0.2)]
    
    var foregroundLineWidth: CGFloat = 4
    var foregroundLineColors: [UIColor] = [UIColor.red, UIColor.blue]
    
    private let defaultMaskShapeLayer = CAShapeLayer()
    private let defaultGradientLayer = CAGradientLayer()
    private let backgroundMaskShapeLayer = CAShapeLayer()
    private let backgroundGradientLayer = CAGradientLayer()
    private let foregroundMaskShapeLayer = CAShapeLayer()
    private let foregroundGradientLayer = CAGradientLayer()
    private let foregroundMaskAnimation = CABasicAnimation(keyPath: "strokeEnd")
    
    private(set) var isRecord = false
    private(set) var isPaused = false
    
    private var endAnimationHandler: Action?
    private var layoutDone = false
    private let duration: CFTimeInterval = 5
    
    func showProgress(endAction: @escaping Action) {
        if isRecord {
            return
        }
        isRecord = true
        endAnimationHandler = endAction
        resetLayerState(showDefault: false)
        startAnimation()
    }
    
    func hideProgress() {
        isRecord = false
        endAnimationHandler = nil
        resetLayerState(showDefault: true)
        foregroundMaskShapeLayer.removeAllAnimations()
    }
    
    func pauseAnimation() {
        let pausedTime : CFTimeInterval = foregroundMaskShapeLayer.convertTime(CACurrentMediaTime(), from: nil)
        foregroundMaskShapeLayer.speed = 0.0
        foregroundMaskShapeLayer.timeOffset = pausedTime
        isPaused = true
    }
    
    func resumeAnimation() {
        let pausedTime = foregroundMaskShapeLayer.timeOffset
        foregroundMaskShapeLayer.speed = 1.0
        foregroundMaskShapeLayer.timeOffset = 0.0
        foregroundMaskShapeLayer.beginTime = 0.0
        let timeSincePause = foregroundMaskShapeLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        foregroundMaskShapeLayer.beginTime = timeSincePause
        isPaused = false
    }
    
    override func layoutSublayers(of layer: CALayer) {
        if !layoutDone {
            setupView()
            layoutDone = true
        }
    }
    
    private func startAnimation() {
        foregroundMaskAnimation.fromValue = 0
        foregroundMaskAnimation.toValue = 1
        foregroundMaskAnimation.duration = duration
        foregroundMaskAnimation.delegate = self
        foregroundMaskShapeLayer.add(foregroundMaskAnimation, forKey: nil)
    }
    
    private func resetLayerState(showDefault: Bool = true) {
        defaultGradientLayer.isHidden = !showDefault
        defaultMaskShapeLayer.isHidden = !showDefault
        foregroundGradientLayer.isHidden = showDefault
        foregroundMaskShapeLayer.isHidden = showDefault
        backgroundGradientLayer.isHidden = showDefault
        foregroundMaskShapeLayer.isHidden = showDefault
    }
    
    private func setupView() {
        self.layer.sublayers = nil
        self.layer.cornerRadius = bounds.width / 2.0
        self.clipsToBounds = true
        drawDefaultShapeLayer()
        drawBackgroundShapeLayer()
        drawForegroundShapeLayer()
        resetLayerState(showDefault: true)
    }
    
    private func drawDefaultShapeLayer() {
        let cornerRadius = frame.height / 2
        let pathRect = bounds.insetBy(dx: defaultLineWidth / 2.0, dy: defaultLineWidth / 2.0)
        let path = UIBezierPath(roundedRect: pathRect, cornerRadius: cornerRadius)
        defaultMaskShapeLayer.path = path.cgPath
        defaultMaskShapeLayer.strokeColor = UIColor.black.cgColor
        defaultMaskShapeLayer.fillColor = UIColor.clear.cgColor
        defaultMaskShapeLayer.lineWidth = defaultLineWidth
        
        let rect = bounds
        defaultGradientLayer.frame = rect
        defaultGradientLayer.colors = defaultLineColors.map({ $0.cgColor })
        defaultGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        defaultGradientLayer.endPoint = CGPoint(x: 0, y: 1)
        defaultGradientLayer.mask = defaultMaskShapeLayer
        layer.addSublayer(defaultGradientLayer)
    }
    
    private func drawBackgroundShapeLayer() {
        let cornerRadius = frame.height / 2
        let pathRect = bounds.insetBy(dx: backgroundLineWidth / 2.0, dy: backgroundLineWidth / 2.0)
        let path = UIBezierPath(roundedRect: pathRect, cornerRadius: cornerRadius)
        backgroundMaskShapeLayer.path = path.cgPath
        backgroundMaskShapeLayer.strokeColor = UIColor.black.cgColor
        backgroundMaskShapeLayer.fillColor = UIColor.clear.cgColor
        backgroundMaskShapeLayer.lineWidth = backgroundLineWidth
        let rect = bounds
        backgroundGradientLayer.frame = rect
        backgroundGradientLayer.colors = backgroundLineColors.map({ $0.cgColor })
        backgroundGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradientLayer.endPoint = CGPoint(x: 0, y: 1)
        backgroundGradientLayer.mask = backgroundMaskShapeLayer
        layer.addSublayer(backgroundGradientLayer)
    }
    
    private func drawForegroundShapeLayer() {
        let cornerRadius = frame.height / 2
        let pathRect = bounds.insetBy(dx: foregroundLineWidth / 2.0, dy: foregroundLineWidth / 2.0)
        let path = UIBezierPath(roundedRect: pathRect, cornerRadius: cornerRadius)
        foregroundMaskShapeLayer.path = path.cgPath
        foregroundMaskShapeLayer.strokeColor = UIColor.black.cgColor
        foregroundMaskShapeLayer.fillColor = UIColor.clear.cgColor
        foregroundMaskShapeLayer.lineWidth = foregroundLineWidth
        foregroundMaskShapeLayer.strokeEnd = 0
        let rect = bounds
        foregroundGradientLayer.frame = rect
        foregroundGradientLayer.colors = foregroundLineColors.map({ $0.cgColor })
        foregroundGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        foregroundGradientLayer.endPoint = CGPoint(x: 0, y: 1)
        foregroundGradientLayer.mask = foregroundMaskShapeLayer
        layer.addSublayer(foregroundGradientLayer)
    }
}

extension RecordingProgressView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let action = endAnimationHandler {
            action()
        }
    }
}
