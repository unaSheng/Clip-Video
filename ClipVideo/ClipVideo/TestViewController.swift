//
//  TestViewController.swift
//  ClipVideo
//
//  Created by li.wenxiu on 2023/1/5.
//

import UIKit

class TestViewController: UIViewController {

    @IBOutlet weak var progressView: RecordingProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        progressView.showProgress {
            
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if progressView.isPaused {
            progressView.resumeAnimation()
        } else {
            progressView.pauseAnimation()
        }
    }
}
