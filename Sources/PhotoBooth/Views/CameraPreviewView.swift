import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        guard let session = session else { return view }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        view.layer = previewLayer
        view.wantsLayer = true
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        
        if let session = session {
            layer.session = session
        }
        
        // Update frame on size changes
        DispatchQueue.main.async {
            layer.frame = nsView.bounds
        }
    }
} 