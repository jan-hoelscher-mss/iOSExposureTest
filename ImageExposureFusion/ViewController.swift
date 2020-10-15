//
//  ViewController.swift
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, UIActionSheetDelegate {

    var shotsConfig: [(time: CMTime, iso: Float)] = [
    ]

    var captureSesssion: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var imageCollector: [UIImage] = []
    var imageProcessor = ImageProcessorBridge()
    var saver = PhotoAlbumSaver()

    var maxIso: Float = 0.0
    var minIso: Float = 0.0

    var maxExposure = CMTime.zero
    var minExposure = CMTime.zero

    @IBOutlet weak var capturedImage: UIImageView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    @IBOutlet weak var waitLabel: UILabel!

    @IBOutlet weak var exposureSlider: UISlider!
    @IBOutlet weak var isoSlider: UISlider!

    @IBOutlet weak var exposureLabel: UILabel!
    @IBOutlet weak var isoLabel: UILabel!


    let device = AVCaptureDevice.default(for: AVMediaType.video)!

    override open var shouldAutorotate: Bool {
        false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSesssion = AVCaptureSession()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()
        waitLabel.transform = CGAffineTransform(rotationAngle: 3.14 / 2);
        waitLabel.center = activity.center;
        var frame = waitLabel.frame;

        frame.origin.x -= 30;
        waitLabel.frame = frame;
        waitLabel.isHidden = true;
        activity.isHidden = true;

        if let input = try? AVCaptureDeviceInput(device: device) {
            if (captureSesssion.canAddInput(input)) {
                minExposure = device.activeFormat.minExposureDuration
                maxExposure = device.activeFormat.maxExposureDuration

                minIso = device.activeFormat.minISO
                maxIso = device.activeFormat.maxISO

                captureSesssion.addInput(input)
                if (captureSesssion.canAddOutput(cameraOutput)) {
                    captureSesssion.addOutput(cameraOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    previewLayer.frame = previewView.bounds
                    previewView.layer.insertSublayer(previewLayer, at: 0)
                    captureSesssion.startRunning()
                    configureCamera()
                    updateShotsConfig()
                }
            } else {
                print("issue here : captureSesssion.canAddInput")
            }
        } else {
            print("some problem here")
        }

    }

    @IBAction func onExposureChange(sender: UISlider) {
        configureCamera()
        updateShotsConfig()
        print("exposure slider changed \(sender.value) \(getExposureForValue(value: Double(sender.value)))")
    }

    @IBAction func onIsoChange(sender: UISlider){
        configureCamera()
        updateShotsConfig()
        print("iso slider changed \(sender.value) \(getIsoForValue(value: sender.value))")
    }

    func getIsoForValue(value: Float) -> Float {
        ((maxIso - minIso) * value) + minIso
    }

    func getExposureForValue(value: Double) -> CMTime{
        CMTimeAdd(CMTimeMultiplyByFloat64(CMTimeSubtract(maxExposure, minExposure), multiplier: value), minExposure)
    }

    func configureCamera(){
        isoLabel.text = "ISO: \(getIsoForValue(value: isoSlider.value))"
        let time = getExposureForValue(value: Double(exposureSlider.value))
        exposureLabel.text = "Exposure: \(time.value)/\(time.timescale)"
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: getExposureForValue(value: Double(exposureSlider.value)), iso: getIsoForValue(value: isoSlider.value))
            device.unlockForConfiguration()
        } catch {
            print("error setting config")
        }
    }

    func updateShotsConfig(){
        let time = getExposureForValue(value: Double(exposureSlider.value))
        let iso = getIsoForValue(value: isoSlider.value)
        shotsConfig = [
            (time: time, iso: max(iso - 800, minIso)),
            (time: time, iso: max(iso - 400, minIso)),
            (time: time, iso: iso),
            (time: time, iso: min(iso + 600, maxIso)),
        ]
    }

    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int)
    {
        print("\(buttonIndex)")
        switch (buttonIndex){

        case 0:
            print("Cancel")
        case 1:
            print("Save")
        case 2:
            print("Delete")
        default:
            print("Default")
                //Some code here..

        }
    }

    @IBAction func didPressTakePhoto(_ sender: UIButton) {
        if (cameraOutput.maxBracketedCapturePhotoCount < 3) {
            return;
        }
        let chunks = shotsConfig.chunked(into: 4)
        let shotFunction = takeShots(shots:)
        waitLabel.isHidden = false;
        activity.startAnimating();
        chunks.map(shotFunction)
    }

    func takeShots(shots: [(time: CMTime, iso: Float)]) {

        let exposureSettings = shots.map { (shot) -> AVCaptureBracketedStillImageSettings in
            AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: shot.time, iso: shot.iso);
        }

        let photoSettings = AVCapturePhotoBracketSettings(
                rawPixelFormatType: 0,
                processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc],
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
            waitLabel.isHidden = true;
            activity.stopAnimating();
        }

        if let error = error {
            print("error occure : \(error.localizedDescription)")
        }
    }

    func askPermission() {
        print("here")
        let cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)

        switch cameraPermissionStatus {
        case .authorized:
            print("Already Authorized")
        case .denied:
            print("denied")

            let alert = UIAlertController(title: "Sorry :(", message: "But  could you please grant permission for camera within device settings", preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)

        case .restricted:
            print("restricted")
        default:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
                [weak self]
                (granted: Bool) -> Void in

                if granted == true {
                    // User granted
                    print("User granted")
                    DispatchQueue.main.async() {
                        //Do smth that you need in main thread
                    }
                } else {
                    // User Rejected
                    print("User Rejected")

                    DispatchQueue.main.async() {
                        let alert = UIAlertController(title: "WHY?", message: "Camera it is the main feature of our application", preferredStyle: .alert)
                        let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                        alert.addAction(action)
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            });
        }
    }
}
