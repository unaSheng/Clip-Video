//
//  ClipControlView.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2022/11/1.
//

import UIKit
import AVFoundation

class ClipControlView: UIView {
    
    enum ClipPosition {
        case head
        case tail
    }
    // 播放按钮
    private let playButton = UIButton(type: .system)
    // 预览背景
    private let backgroundView = UIView()
    // 头部被裁剪区域
    private let headMaskView = UIView()
    // 尾部被裁剪区域
    private let tailMaskView = UIView()
    // 中间预览区域
    private let lightPreviewView = UIView()
    // 中间预览区域的Mask
    private let lightPreviewMaskLayer = CAShapeLayer()
    // 头部裁剪位置
    private let headClipPositionView = PositionView()
    // 尾部裁剪位置
    private let tailClipPositionView = PositionView()
    // 预览帧
    private var previewFrames: [UIImageView] = []
    // 播放进度指示器
    private let playingIndicatorView = UIView()
    
    private var isPlaying = false
    
    private var headOffset: CGFloat = 0
    private var tailOffset: CGFloat = 0
    private let clipPositionWidth: CGFloat = 20
    private let previewVerticalMargin: CGFloat = 5
    private let playingIndicatorViewWidth: CGFloat = 3
    
    private weak var avPlayer: AVPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateSubviewsPosition()
        updatePlayingIndicatorViewPosition()
    }
    
    func updateUI(player: AVPlayer?) {
        self.avPlayer = player
    }
    
    @objc private func panOnHeadClipPositionView(_ pan: UIPanGestureRecognizer) {
        let backgroundViewWidth = backgroundView.bounds.width
        let location = pan.location(in: backgroundView)
        headOffset = min(max(0, location.x), backgroundViewWidth - clipPositionWidth * 2)
        updateSubviewsPosition()
        let alpha: CGFloat
        switch pan.state {
        case .changed:
            alpha = 0
        default:
            alpha = 1
            updatePlayingIndicatorViewPosition(.head)
        }
        playingIndicatorView.alpha = alpha
    }
    
    @objc private func panOnTailClipPositionView(_ pan: UIPanGestureRecognizer) {
        let backgroundViewWidth = backgroundView.bounds.width
        let location = pan.location(in: backgroundView)
        tailOffset = min(max(0, backgroundViewWidth - location.x), backgroundViewWidth - clipPositionWidth * 2)
        updateSubviewsPosition()
        let alpha: CGFloat
        switch pan.state {
        case .changed:
            alpha = 0
        default:
            alpha = 1
            updatePlayingIndicatorViewPosition(.tail)
        }
        playingIndicatorView.alpha = alpha
    }
    
    @objc private func panOnLightPreviewView(_ pan: UIPanGestureRecognizer) {
        let lightPreviewViewHeight = lightPreviewView.bounds.height
        let location = pan.location(in: backgroundView)
        let originX = min(max(lightPreviewView.frame.minX + clipPositionWidth, location.x), lightPreviewView.frame.maxX - clipPositionWidth)
        playingIndicatorView.frame = CGRect(x: originX, y: previewVerticalMargin,
                                            width: playingIndicatorViewWidth, height: lightPreviewViewHeight - previewVerticalMargin * 2)
        playingIndicatorView.alpha = 1
    }
    
    @objc private func playButtonTapped() {
        if isPlaying {
            avPlayer?.pause()
        } else {
            avPlayer?.play()
        }
        isPlaying.toggle()
        playButton.isSelected = isPlaying
    }
    
    private func updateSubviewsPosition() {
        let backgroundViewHeight = backgroundView.bounds.height
        let backgroundViewWidth = backgroundView.bounds.width
        headMaskView.frame = CGRect(x: 0, y: 0, width: headOffset, height: backgroundViewHeight)
        tailMaskView.frame = CGRect(x: backgroundViewWidth, y: 0, width: tailOffset, height: backgroundViewHeight)
        lightPreviewView.frame = CGRect(x: headOffset, y: 0,
                                        width: backgroundViewWidth - headOffset - tailOffset,
                                        height: backgroundViewHeight)
        let lightPreviewViewWidth = lightPreviewView.bounds.width
        let lightPreviewViewHeight = lightPreviewView.bounds.height
        let path = UIBezierPath(rect: lightPreviewView.bounds)
        path.append(UIBezierPath(rect: CGRect(x: clipPositionWidth, y: previewVerticalMargin,
                                              width: lightPreviewViewWidth - clipPositionWidth * 2,
                                              height: lightPreviewViewHeight - previewVerticalMargin * 2)))
        lightPreviewMaskLayer.path = path.cgPath
        
        headClipPositionView.frame = CGRect(x: 0, y: 0, width: clipPositionWidth, height: lightPreviewViewHeight)
        tailClipPositionView.frame = CGRect(x: lightPreviewViewWidth - clipPositionWidth, y: 0,
                                            width: clipPositionWidth,
                                            height: lightPreviewViewHeight)
        if headOffset > 0 || tailOffset > 0 {
            lightPreviewView.backgroundColor = UIColor.systemYellow
            headClipPositionView.imageView.tintColor = UIColor.black
            tailClipPositionView.imageView.tintColor = UIColor.black
        } else {
            lightPreviewView.backgroundColor = UIColor.secondarySystemBackground
            headClipPositionView.imageView.tintColor = UIColor.white
            tailClipPositionView.imageView.tintColor = UIColor.white
        }
    }
    
    private func updatePlayingIndicatorViewPosition(_ position: ClipPosition = .head) {
        let lightPreviewViewHeight = lightPreviewView.bounds.height
        let size = CGSize(width: playingIndicatorViewWidth, height: lightPreviewViewHeight - previewVerticalMargin * 2)
        let origin: CGPoint
        switch position {
        case .head:
            origin = CGPoint(x: lightPreviewView.frame.minX + clipPositionWidth, y: previewVerticalMargin)
        case .tail:
            origin = CGPoint(x: lightPreviewView.frame.maxX - clipPositionWidth, y: previewVerticalMargin)
        }
        playingIndicatorView.frame = CGRect(origin: origin, size: size)
    }
    
    private func setupSubviews() {
        self.layer.cornerRadius = 10
        self.clipsToBounds = true
        // 播放按钮
        playButton.tintColor = UIColor.white
        playButton.backgroundColor = UIColor.secondarySystemBackground
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playButton)
        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            playButton.topAnchor.constraint(equalTo: self.topAnchor),
            playButton.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        // 预览背景
        backgroundView.backgroundColor = UIColor.secondarySystemBackground
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 2),
            backgroundView.topAnchor.constraint(equalTo: self.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
        
        // 预览帧
        for _ in 0...14 {
            let imageView = UIImageView()
            imageView.clipsToBounds = true
            imageView.contentMode = .scaleAspectFill
            previewFrames.append(imageView)
        }
        let previewFrameStackView = UIStackView(arrangedSubviews: previewFrames)
        previewFrameStackView.axis = .horizontal
        previewFrameStackView.spacing = 0
        previewFrameStackView.alignment = .fill
        previewFrameStackView.distribution = .fillEqually
        previewFrameStackView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(previewFrameStackView)
        NSLayoutConstraint.activate([
            previewFrameStackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: clipPositionWidth),
            previewFrameStackView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: previewVerticalMargin),
            previewFrameStackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -previewVerticalMargin),
            previewFrameStackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -clipPositionWidth)
        ])
        
        // 头部被裁剪区域
        headMaskView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        backgroundView.addSubview(headMaskView)
        
        // 尾部被裁剪区域
        tailMaskView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        backgroundView.addSubview(tailMaskView)
        
        // 中间预览区域
        lightPreviewView.backgroundColor = UIColor.systemYellow
        lightPreviewView.layer.cornerRadius = 10
        lightPreviewView.clipsToBounds = true
        lightPreviewView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panOnLightPreviewView(_:))))
        lightPreviewMaskLayer.backgroundColor = UIColor.clear.cgColor
        lightPreviewMaskLayer.fillRule = .evenOdd
        lightPreviewView.layer.mask = lightPreviewMaskLayer
        backgroundView.addSubview(lightPreviewView)
        
        // 头部裁剪位置
        headClipPositionView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panOnHeadClipPositionView(_:))))
        headClipPositionView.imageView.tintColor = UIColor.white
        headClipPositionView.imageView.image = UIImage(systemName: "chevron.compact.left")
        lightPreviewView.addSubview(headClipPositionView)
        
        // 尾部裁剪位置
        tailClipPositionView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panOnTailClipPositionView(_:))))
        tailClipPositionView.imageView.tintColor = UIColor.white
        tailClipPositionView.imageView.image = UIImage(systemName: "chevron.compact.right")
        lightPreviewView.addSubview(tailClipPositionView)
        
        // 播放进度指示器
        playingIndicatorView.backgroundColor = UIColor.white
        playingIndicatorView.layer.cornerRadius = playingIndicatorViewWidth / 2.0
        playingIndicatorView.clipsToBounds = true
        backgroundView.addSubview(playingIndicatorView)
    }
}


class PositionView: UIView {
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }
    
    private func setupSubviews() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.6),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 2),
        ])
    }
}
