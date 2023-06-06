//
//  ViewController.swift
//  SingleVideoRecorder
//
//  Created by Ikmal Azman on 02/07/2022.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    
    var session : AVCaptureSession!
    var videoOutput : AVCaptureVideoDataOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
    
    var isRecording = false
    var startWritingVideo = false
    
    var assetWriter : AVAssetWriter!
    var assetWriterInput : AVAssetWriterInput!
    
    
    func setupAssetWriter() {
        guard let filemanager = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could get urls")
        }
        
        let videoOutputURL = filemanager.appendingPathComponent("MyVideo.mov")
        
        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            try? FileManager.default.removeItem(atPath: videoOutputURL.path)
        }
        
        assetWriter = try! AVAssetWriter(outputURL: videoOutputURL, fileType: .mp4)
    }
    
    func setupAssetWriterInput() {
        let outputSettings : [String:Any]  = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey : 1280,
            AVVideoHeightKey : 720
        ]
        
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        assetWriterInput.expectsMediaDataInRealTime = true
        
        guard assetWriter.canAdd(assetWriterInput) else {
            fatalError("Could not add input into assetWriter")
        }
        
        assetWriter.add(assetWriterInput)
    }
    
    func beginRecording(_ sampleBuffer : CMSampleBuffer) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        assetWriter.startSession(atSourceTime: time)
        
        assetWriterInput.append(sampleBuffer)
    }
    
    func finishRecording() {
        assetWriterInput.markAsFinished()
        assetWriter.finishWriting {
            let videoURL = self.assetWriter.outputURL
            self.presentVideoPreviewSaver(videoURL)
        }
    }
    
    func presentVideoPreviewSaver(_ url : URL) {
        DispatchQueue.main.async {
            let shareController = UIActivityViewController(activityItems: [url], applicationActivities: [])
            self.present(shareController, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestCameraPermission()
        setupAssetWriter()
        setupAssetWriterInput()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    @IBAction func recordVideoTapped(_ sender: UIButton) {
        if isRecording == false {
            
            assetWriter.startWriting()
            
            self.isRecording = true
            self.startWritingVideo = true
            
        } else {
            isRecording = false
            startWritingVideo = false
            finishRecording()
        }
    }
}

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isRecording && startWritingVideo {
            beginRecording(sampleBuffer)
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
            self.setupOutputs()
          

            DispatchQueue.main.async {
                self.setupPreviewView()
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        
        }
    }
    
    func setupInputs() {
        guard
            let backCamera = AVCaptureDevice
                .default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back) else {
            fatalError("No back camera available")
        }
        
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(
                device: backCamera) else {
            fatalError("There's some error when create input for back camera")
        }
        
        
        guard session.canAddInput(videoDeviceInput) else {return}
        
        session.addInput(videoDeviceInput)
        print("Input Connected")
    }
    
    func setupOutputs() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        guard session.canAddOutput(videoOutput) else {return}
        
        session.addOutput(videoOutput)
        print("Output Connected")
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
