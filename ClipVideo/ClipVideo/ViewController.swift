//
//  ViewController.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2022/11/1.
//

import UIKit
import AVFoundation
import PhotosUI

class ViewController: UIViewController {
    
    @IBOutlet private weak var videoPlayerView: VideoPlayerView!
    @IBOutlet private weak var clipControlView: ClipControlView!
    @IBOutlet private weak var muteButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var finishButton: UIButton!
    
    private var isMuted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showClipSubviewsIfNeeded(false)
    }
    
    @IBAction private func muteButtonTapped(_ sender: Any) {
        isMuted.toggle()
        videoPlayerView.playerLayer.player?.volume = isMuted ? 0 : 1
        muteButton.isSelected = isMuted
    }
    
    @IBAction private func selectVideoButtonTapped(_ sender: Any) {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.videos])
        config.selectionLimit = 1
        let pickerVC = PHPickerViewController(configuration: config)
        pickerVC.delegate = self
        self.present(pickerVC, animated: true)
    }
    
    
    @IBAction private func cancelButtonTapped(_ sender: Any) {
        clipControlView.reset()
    }
    
    @IBAction private func finishButtonTapped(_ sender: Any) {
        Task {
            do {
                let url = try await clipControlView.exportVideo()
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(saveVideoToAlbum), nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc private func saveVideoToAlbum(_ videoPath: String?, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        if error == nil {
            print("保存成功")
        }
    }
    
    private func updateVideo(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = 1
        videoPlayerView.playerLayer.player = player
        videoPlayerView.playerLayer.videoGravity = .resizeAspect
        clipControlView.loadAssetCompletion = { [weak self] in
            self?.showClipSubviewsIfNeeded(true)
        }
        clipControlView.updateUI(player: player)
    }
    
    private func showClipSubviewsIfNeeded(_ show: Bool) {
        clipControlView.isHidden = !show
        cancelButton.isHidden = !show
        finishButton.isHidden = !show
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        results.first?.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler: { url, error in
            if let url = url, let desctionURL = self.moveFile(from: url, to: "liwenxiu") {
                DispatchQueue.main.async {
                    self.updateVideo(desctionURL)
                }
            }
        })
    }
    
    private func moveFile(from: URL, to fileName: String) -> URL? {
        do {
            var destinationURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            destinationURL.appendPathComponent(fileName, isDirectory: true)
            destinationURL.appendPathComponent(from.lastPathComponent, isDirectory: false)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(atPath: destinationURL.path)
            }
            try FileManager.default.moveItem(at: from, to: destinationURL)
            return destinationURL
        } catch {
            print(error)
            return nil
        }
    }
}

class VideoPlayerView: UIView {
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }
    
}

