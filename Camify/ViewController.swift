import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    var imagePicker = UIImagePickerController()
    var capturedImage: UIImage?
    var captureSession = AVCaptureSession()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorizationStatus {
        case .authorized:
            print("Camera access is authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("Camera access is authorized")
                } else {
                    print("Camera access is not authorized")
                }
            }
        case .denied, .restricted:
            print("Camera access is not authorized")
        }
        
        imagePicker.delegate = self
        
        // Setup the camera view
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait // Set orientation to portrait
        previewLayer.frame = cameraView.bounds
        cameraView.layer.addSublayer(previewLayer)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        captureSession.startRunning()
    }

    @IBAction func capturePhoto() {
        guard let image = capturedImage else { return }
        imageView.image = image
        let recognizedText = analyzeText(image: image)
        print("Recognized text: \(recognizedText)")
    }

    @IBAction func searchWeb() {
        guard let recognizedText = analyzeText(image: imageView.image ?? UIImage()) else { return }
                guard let encodedText = recognizedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
                let urlString = "https://www.google.com/search?q=\(encodedText)"
                guard let url = URL(string: urlString) else { return }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
    @IBAction func clearImage() {
        capturedImage = nil
        imageView.image = nil
    }
}

    extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            imagePicker.dismiss(animated: true, completion: nil)
            guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
            capturedImage = image
            imageView.image = image
        }
    }

    extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
        guard let cgImage = context.createCGImage(ciImage, from: imageRect) else { return }
        
        let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .right)
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

extension ViewController {
    func analyzeText(image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return nil }
        
        let texts = observations.compactMap({$0.topCandidates(1).first?.string})
        let searchText = texts.joined(separator: " ")
        return searchText
    }
}
