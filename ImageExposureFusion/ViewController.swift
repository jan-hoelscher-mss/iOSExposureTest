//
//  ViewController.swift
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate  {

    let shotsConfig : [(time: CMTime, iso: Float)] = [
        (time : CMTimeMake(value: 1, timescale: 5), iso: 400),
        (time : CMTimeMake(value: 1, timescale: 5), iso: 800),
        (time : CMTimeMake(value: 1, timescale: 5), iso: 1600),
        (time : CMTimeMake(value: 1, timescale: 5), iso: 2300),
    ]

    var captureSesssion : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var imageCollector : [UIImage] = []
    var imageProcessor = ImageProcessorBridge()
    var saver = PhotoAlbumSaver()

    @IBOutlet weak var capturedImage: UIImageView!
    @IBOutlet weak var previewView: UIView!
    
    override open var shouldAutorotate: Bool {
            false
        }

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSesssion = AVCaptureSession()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()

        let device = AVCaptureDevice.default(for: AVMediaType.video)!
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
        let chunks = shotsConfig.chunked(into: 4)
        let shotFunction = takeShots(shots:)
        chunks.map(shotFunction)
    }

    func takeShots(shots: [(time: CMTime, iso: Float)]){

        let exposureSettings = shots.map { (shot) -> AVCaptureBracketedStillImageSettings in
            AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: shot.time, iso: shot.iso);
        }

        let photoSettings = AVCapturePhotoBracketSettings(
                rawPixelFormatType: 0,
                processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc],
                bracketedSettings: exposureSettings
        )
        photoSettings.isLensStabilizationEnabled = cameraOutput.isLensStabilizationDuringBracketedCaptureSupported

        cameraOutput.maxPhotoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization.quality;
        cameraOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        let imageData = photo.fileDataRepresentation()

        if let data = imageData, let image: UIImage = UIImage(data: data) {
            saver.savePhoto(photo: photo)
            imageCollector.append(image)
        }

        if (imageCollector.count == shotsConfig.count) {
            let result = imageProcessor.processImages(imageCollector)!
            self.capturedImage.image = result
            imageCollector = []
            saver.saveImage(image: result)
        }

        if let error = error {
            print("error occure : \(error.localizedDescription)")
        }
    }

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
