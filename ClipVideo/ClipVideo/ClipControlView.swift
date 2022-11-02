//
//  ClipControlView.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2022/11/1.
//

import UIKit
import AVFoundation

struct InstructionError: LocalizedError {
    private let instruction: String
    var errorDescription: String? { instruction }
    init(_ instruction: String) { self.instruction = instruction }
}

class ClipControlView: UIView {
    
    static let timescale: Int32 = 600
    
    enum ClipPosition {
        case head
        case tail
    }
    
    var loadAssetCompletion: (() -> Void)?
    
    var isMute: Bool = false
    
    // 播放按钮
    private let playButton = UIButton(type: .custom)
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
    
    private var isPlaying = false {
        didSet {
            playButton.isSelected = isPlaying
        }
    }
    
    private var headOffset: CGFloat = 0
    private var tailOffset: CGFloat = 0
    private(set) var headClipedDuration: CMTime = .zero
    private(set) var tailClipedDuration: CMTime = .zero
    
    private var minPreviewWidth: CGFloat = 0
    private var minTargetDuration: CMTime = CMTime(seconds: 1, preferredTimescale: ClipControlView.timescale)
    
    private let clipPositionWidth: CGFloat = 20
    private let previewVerticalMargin: CGFloat = 5
    private let playingIndicatorViewWidth: CGFloat = 3
    private var validMaxDurationWidth: CGFloat {
        return backgroundView.bounds.width - clipPositionWidth * 2 - playingIndicatorViewWidth
    }
    
    private weak var avPlayer: AVPlayer?
    private var durationObserver: NSKeyValueObservation?
    private var timeObserver: Any?
    private var assetExportSession: AVAssetExportSession?
    
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
        updatePlayingIndicatorViewPosition(.head)
    }
    
    func updateUI(player: AVPlayer?, minTargetDuration: CMTime = CMTime(seconds: 1, preferredTimescale: ClipControlView.timescale)) {
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        durationObserver?.invalidate()
        durationObserver = nil
        reset()
        self.avPlayer = player
        self.minTargetDuration = minTargetDuration
        observerPlayerItemDuration()
        observerPlayerPeriodicTime()
    }
    
    func reset() {
        headOffset = 0
        tailOffset = 0
        headClipedDuration = .zero
        tailClipedDuration = .zero
        updateSubviewsPosition()
        updatePlayingIndicatorViewPosition(.head)
        updateClipedDuration(.head)
    }
    
    func exportVideo() async throws -> URL {
        let composition = try setupComposition()
        guard let assetExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw InstructionError("初始化 AVAssetExportSession 失败")
        }
        let outputURL = try setupOutputURL()
        assetExportSession.outputURL = outputURL
        assetExportSession.outputFileType = .mp4
        await assetExportSession.export()
        return outputURL
    }
    
    private func setupOutputURL() throws -> URL {
        var url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        url.appendPathComponent("exportedVideo.mp4", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(atPath: url.path)
        }
        return url
    }
    
    private func setupComposition() throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        guard let asset = avPlayer?.currentItem?.asset,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: composition.unusedTrackID()),
              let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
            throw InstructionError("获取 video track 失败")
        }
        let end = CMTime(seconds: (asset.duration.seconds - tailClipedDuration.seconds), preferredTimescale: Self.timescale)
        let timeRange = CMTimeRange(start: headClipedDuration, end: end)
        try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
        videoTrack.preferredTransform = assetVideoTrack.preferredTransform
        if !isMute,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: composition.unusedTrackID()),
           let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
            try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            audioTrack.preferredTransform = assetAudioTrack.preferredTransform
        }
        return composition
    }
    
    private func observerPlayerItemDuration() {
        if let player = avPlayer, let item = player.currentItem {
            durationObserver = item.observe(\.duration, changeHandler: { [weak self] item, change in
                guard let strongSelf = self else { return }
                if item.duration != .invalid {
                    strongSelf.loadAssetCompletion?()
                    let imageGenerator = AVAssetImageGenerator(asset: item.asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    let frameSecond = item.duration.seconds / Double(strongSelf.previewFrames.count)
                    var times: [NSValue] = []
                    for index in 0..<strongSelf.previewFrames.count {
                        let time = CMTime(seconds: Double(index) * frameSecond, preferredTimescale: Self.timescale)
                        times.append(NSValue(time: time))
                    }
                    imageGenerator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
                        DispatchQueue.main.async {
                            if let index = times.firstIndex(where: { $0.timeValue == requestedTime }) {
                                if let cgImage = cgImage {
                                    strongSelf.previewFrames[index].image = UIImage(cgImage: cgImage)
                                    strongSelf.previewFrames[index].isHidden = false
                                } else {
                                    strongSelf.previewFrames[index].isHidden = true
                                }
                            } else {
                                fatalError()
                            }
                        }
                    }
                }
            })
        }
    }
    
    private func observerPlayerPeriodicTime() {
        timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: CMTime(value: 12, timescale: Self.timescale), queue: .main) { [weak self] time in
            guard let strongSelf = self, let currentItem = strongSelf.avPlayer?.currentItem else { return }
            let totalSeconds = currentItem.duration.seconds
            let currentSeconds = currentItem.currentTime().seconds

            if totalSeconds - currentSeconds <= strongSelf.tailClipedDuration.seconds {
                strongSelf.pauseVideo()
            }
            var progress = min(max(strongSelf.headClipedDuration.seconds, currentSeconds), totalSeconds - strongSelf.tailClipedDuration.seconds) / totalSeconds
            progress = min(1, max(0, progress))
            let origin = strongSelf.playingIndicatorView.frame.origin
            let originX = strongSelf.validMaxDurationWidth * progress + strongSelf.clipPositionWidth
            strongSelf.playingIndicatorView.frame.origin = CGPoint(x: originX, y: origin.y)
        }
    }
    
    private func pauseVideo() {
        avPlayer?.pause()
        isPlaying = false
    }
    
    @objc private func playButtonTapped() {
        guard let player = avPlayer, let item = avPlayer?.currentItem else { return }
        if isPlaying {
            player.pause()
        } else {
            if abs(playingIndicatorView.frame.maxX - (lightPreviewView.frame.maxX - clipPositionWidth)) < 0.1 {
                item.seek(to: headClipedDuration, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { _ in
                    player.play()
                })
            } else {
                player.play()
            }
        }
        isPlaying.toggle()
    }
    
    @objc private func panOnHeadClipPositionView(_ pan: UIPanGestureRecognizer) {
        pauseVideo()
        let location = pan.location(in: backgroundView)
        headOffset = min(max(0, location.x), validMaxDurationWidth - tailOffset)
        updateSubviewsPosition()
        let alpha: CGFloat
        switch pan.state {
        case .changed:
            alpha = 0
        default:
            alpha = 1
            updatePlayingIndicatorViewPosition(.head)
            updateClipedDuration(.head)
        }
        playingIndicatorView.alpha = alpha
    }
    
    @objc private func panOnTailClipPositionView(_ pan: UIPanGestureRecognizer) {
        pauseVideo()
        let backgroundViewWidth = backgroundView.bounds.width
        let location = pan.location(in: backgroundView)
        tailOffset = min(max(0, backgroundViewWidth - location.x), validMaxDurationWidth - headOffset)
        updateSubviewsPosition()
        let alpha: CGFloat
        switch pan.state {
        case .changed:
            alpha = 0
        default:
            alpha = 1
            updatePlayingIndicatorViewPosition(.tail)
            updateClipedDuration(.tail)
        }
        playingIndicatorView.alpha = alpha
    }
    
    @objc private func panOnLightPreviewView(_ pan: UIPanGestureRecognizer) {
        pauseVideo()
        let location = pan.location(in: backgroundView)
        let originX = min(max(lightPreviewView.frame.minX + clipPositionWidth, location.x), lightPreviewView.frame.maxX - clipPositionWidth - playingIndicatorViewWidth)
        playingIndicatorView.frame = CGRect(x: originX, y: previewVerticalMargin,
                                            width: playingIndicatorViewWidth, height: lightPreviewView.bounds.height - previewVerticalMargin * 2)
        playingIndicatorView.alpha = 1
        switch pan.state {
        case .ended, .cancelled, .failed:
            if let playerItem = avPlayer?.currentItem {
                let seconds = (originX - clipPositionWidth) / validMaxDurationWidth * playerItem.duration.seconds
                let time = CMTime(seconds: seconds, preferredTimescale: Self.timescale)
                playerItem.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
            }
        default:
            break
        }
    }
    
    private func updateSubviewsPosition() {
        let backgroundViewHeight = backgroundView.bounds.height
        let backgroundViewWidth = backgroundView.bounds.width
        headMaskView.frame = CGRect(x: 0, y: 0, width: headOffset, height: backgroundViewHeight)
        tailMaskView.frame = CGRect(x: backgroundViewWidth - tailOffset, y: 0, width: tailOffset, height: backgroundViewHeight)
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
    
    private func updatePlayingIndicatorViewPosition(_ position: ClipPosition) {
        let lightPreviewViewHeight = lightPreviewView.bounds.height
        let size = CGSize(width: playingIndicatorViewWidth, height: lightPreviewViewHeight - previewVerticalMargin * 2)
        let origin: CGPoint
        switch position {
        case .head:
            origin = CGPoint(x: lightPreviewView.frame.minX + clipPositionWidth, y: previewVerticalMargin)
        case .tail:
            origin = CGPoint(x: lightPreviewView.frame.maxX - clipPositionWidth - playingIndicatorViewWidth, y: previewVerticalMargin)
        }
        playingIndicatorView.frame = CGRect(origin: origin, size: size)
    }
    
    private func updateClipedDuration(_ position: ClipPosition) {
        guard let playerItem = self.avPlayer?.currentItem else { return }
        if playerItem.duration == .invalid {
            fatalError()
        }
        switch position {
        case .head:
            let seconds = headOffset / validMaxDurationWidth * playerItem.duration.seconds
            headClipedDuration = CMTime(seconds: seconds, preferredTimescale: Self.timescale)
            playerItem.seek(to: headClipedDuration, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
        case .tail:
            let seconds = tailOffset / validMaxDurationWidth * playerItem.duration.seconds
            tailClipedDuration = CMTime(seconds: seconds, preferredTimescale: Self.timescale)
            let time = CMTime(seconds: playerItem.duration.seconds - seconds, preferredTimescale: Self.timescale)
            playerItem.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
        }
    }
    
    private func setupSubviews() {
        self.layer.cornerRadius = 5
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
        headMaskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backgroundView.addSubview(headMaskView)
        
        // 尾部被裁剪区域
        tailMaskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backgroundView.addSubview(tailMaskView)
        
        // 中间预览区域
        lightPreviewView.backgroundColor = UIColor.systemYellow
        lightPreviewView.layer.cornerRadius = 5
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
