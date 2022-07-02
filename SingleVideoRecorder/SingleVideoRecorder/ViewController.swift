//
//  ViewController.swift
//  SingleVideoRecorder
//
//  Created by Ikmal Azman on 02/07/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    
    var session : AVCaptureSession!
    var videoDeviceInput : AVCaptureInput!
    var videoOutput : AVCaptureVideoDataOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
    
    var isVideoCapture = false
    var metalVideoRecorder : MetalVideoRecorder {
        guard let filemanager = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could get urls")
        }
        let videoOutputURL = filemanager.appendingPathComponent("MyVideo.mov")
        
        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            try? FileManager.default.removeItem(atPath: videoOutputURL.path)
        }
        
        return MetalVideoRecorder(outputURL: videoOutputURL, size: CGSize(width: 1280, height: 720))!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestCameraPermission()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    @IBAction func recordVideoTapped(_ sender: UIButton) {
            
        if metalVideoRecorder.isRecording {
                   metalVideoRecorder.endRecording { videoURL in
                       print("Video URL : \(videoURL)")
                       
                       let shareController = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
                       DispatchQueue.main.async {

                           self.present(shareController, animated: true)
                       }
                   }
               } else {
                   metalVideoRecorder.startRecording()
                   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                       self.isVideoCapture.toggle()
                       
                   }

               }
        
        print("isVideoCapture : \(isVideoCapture)")
        print("metalVideoIsRecording : \(metalVideoRecorder.isRecording)")
    }
}

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            
            guard self.metalVideoRecorder.isRecording && self.isVideoCapture else {
                return
            }
            self.metalVideoRecorder.writeFrame(buffer: sampleBuffer, forSecond: Float(sampleBuffer.duration.seconds))
            print("video frame received")
            
        }
    }
}



private extension ViewController {
    func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session = AVCaptureSession()
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720
            self.session.automaticallyConfiguresCaptureDeviceForWideColor = true
            self.setupInputs()
            DispatchQueue.main.async {
                self.setupPreviewView()
            }
            self.setupOutputs()
            self.session.commitConfiguration()
            self.session.startRunning()
            
        }
    }
    
    func setupInputs() {
        guard
            let backCamera = AVCaptureDevice
                .default(.builtInWideAngleCamera,
                         for: .video,
                         position: .back) else {
            fatalError("NO DUAL CAMERA")
        }
        
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(
                device: backCamera) else {
            fatalError("There's some error when create input for back camera")
        }
        
        self.videoDeviceInput = videoDeviceInput
        
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            print("Input Connected")
        }
        
        
    }
    
    func setupOutputs() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("Output Connected")
        }
        
        //        videoOutput.connections.first?.videoOrientation = .portrait
        
    }
    
    func setupPreviewView() {
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.session = session
        previewView.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = self.view.frame
    }
    
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { isAllowed in
                if isAllowed {
                    self.setupCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            self.setupCamera()
        @unknown default:
            break
        }
    }
}
