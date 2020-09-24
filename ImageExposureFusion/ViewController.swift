//
//  ViewController.swift
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//
//

import UIKit
import AVFoundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate  {
    
    var captureSesssion : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var imageCollector : [UIImage] = []
    var imageProcessor = ImageProcessorBridge()
    var saver = PhotoAlbumSaver()

    let exposureValues: [Float] = [0, 2, 4, 6]
    let isoValues: [Float] = [800, 1600, 2304]

    @IBOutlet weak var capturedImage: UIImageView!
    @IBOutlet weak var previewView: UIView!
    
    override open var shouldAutorotate: Bool {
            return false
        }

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSesssion = AVCaptureSession()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()

        let device = AVCaptureDevice.default(for: AVMediaType.video)!
        //let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)!
        print(AVCaptureDevice.devices())
        device.formats.map { format -> Void in
            print(format.maxISO)
        }
        if let input = try? AVCaptureDeviceInput(device: device) {
                if (captureSesssion.canAddInput(input)) {
                    captureSesssion.addInput(input)
                    if (captureSesssion.canAddOutput(cameraOutput)) {
                        captureSesssion.addOutput(cameraOutput)
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                        previewLayer.frame = previewView.bounds
                        previewView.layer.addSublayer(previewLayer)
                        captureSesssion.startRunning()
                    }
                } else {
                    print("issue here : captureSesssion.canAddInput")
                }
            } else {
                print("some problem here")
            }
    
    }

    @IBAction func didPressTakePhoto(_ sender: UIButton) {
        if ( cameraOutput.maxBracketedCapturePhotoCount < 3 ) { return; }
        let result = isoValues.chunked(into: 4)
        let shot = takeShots(exposures:)
        result.map(shot)
    }

    func takeShots(exposures: [Float]){
        print(exposures)
        let makeAutoExposureSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias:)
        //let exposureSettings = exposures.map(makeAutoExposureSettings)


        let exposureSettings = exposures.map { (exposure) -> AVCaptureBracketedStillImageSettings in
            AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: CMTimeMake(value: 2, timescale: 5), iso: exposure);
        }

        let photoSettings = AVCapturePhotoBracketSettings(
                rawPixelFormatType: 0,
                processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc],
                bracketedSettings: exposureSettings
        )
        photoSettings.isLensStabilizationEnabled = cameraOutput.isLensStabilizationDuringBracketedCaptureSupported
        let tmp = cameraOutput.maxPhotoQualityPrioritization
        cameraOutput.maxPhotoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization.quality;
        cameraOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        let imageData = photo.fileDataRepresentation()
        let cgimageData = photo.cgImageRepresentation()

        if let data = cgimageData, let image: UIImage = UIImage(cgImage: data.takeUnretainedValue()) {
        //if let data = imageData, let image: UIImage = UIImage(data: data) {
            //saver.saveImage(image: image)
            saver.savePhoto(photo: photo)
            imageCollector.append(image)
        }

        if (imageCollector.count == isoValues.count) {
            let result = imageProcessor.processImages(imageCollector)!
            self.capturedImage.image = result
            imageCollector = []
            saver.saveImage(image: result)
        }

        if let error = error {
            print("error occure : \(error.localizedDescription)")
        }
    }
    /*
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        if let error = error {
            print("error occure : \(error.localizedDescription)")
        }

        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            print(UIImage(data: dataImage)?.size as Any)

            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)

            self.capturedImage.image = image
        } else {
            print("some error here")
        }
    }
    */
    func askPermission() {
        print("here")
        let cameraPermissionStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)

        switch cameraPermissionStatus {
        case .authorized:
            print("Already Authorized")
        case .denied:
            print("denied")

            let alert = UIAlertController(title: "Sorry :(" , message: "But  could you please grant permission for camera within device settings",  preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .cancel,  handler: nil)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)

        case .restricted:
            print("restricted")
        default:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
                [weak self]
                (granted :Bool) -> Void in

                if granted == true {
                    // User granted
                    print("User granted")
     DispatchQueue.main.async(){
                //Do smth that you need in main thread
                }
                }
                else {
                    // User Rejected
                    print("User Rejected")

    DispatchQueue.main.async(){
                let alert = UIAlertController(title: "WHY?" , message:  "Camera it is the main feature of our application", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                    alert.addAction(action)
                    self?.present(alert, animated: true, completion: nil)
                }
                }
            });
        }
    }
}
