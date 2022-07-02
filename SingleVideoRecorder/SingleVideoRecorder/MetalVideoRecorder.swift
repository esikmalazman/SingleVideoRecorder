import AVFoundation

//https://stackoverflow.com/questions/5810984/avassetwriterinputpixelbufferadaptor-returns-null-pixel-buffer-pool
public class MetalVideoRecorder {
    public var isRecording = false
    public var recordingStartTime = TimeInterval(0)
    
    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor
    
    public init?(outputURL url: URL, size: CGSize) {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            return nil
        }
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : size.width,
            AVVideoHeightKey : size.height
        ]
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height ]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput,
                                                                           sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        assetWriter.add(assetWriterVideoInput)
    }
    
    public func startRecording() {
        isRecording = true
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        recordingStartTime = CACurrentMediaTime()
    }
    
    public func endRecording(_ completionHandler: @escaping (URL) -> ()) {
        isRecording = false
        assetWriterVideoInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: { [assetWriter] in
            completionHandler(assetWriter.outputURL)
        })
        recordingStartTime = .zero
    }
    
    func cancelRecording() {
        assetWriter.cancelWriting()
    }
    
    public func writeFrame(buffer: CMSampleBuffer, forSecond second: Float) {
        if !isRecording {
            return
        }
        
        let frameTime = CACurrentMediaTime()
        
        while !assetWriterVideoInput.isReadyForMoreMediaData {}
        
        guard let pixelBuffer = buffer.imageBuffer else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        let presentationTime = CMTimeMakeWithSeconds(Float64(frameTime), preferredTimescale: 240)
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        print("Saved texture for seconds", frameTime)
    }
}
