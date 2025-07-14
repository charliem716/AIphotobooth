import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        guard let session = session else { return containerView }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = containerView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        containerView.layer = previewLayer
        containerView.wantsLayer = true
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        
        if layer.session != session {
            layer.session = session
        }
        
        // Update frame on size changes
        DispatchQueue.main.async {
            layer.frame = nsView.bounds
        }
    }
} 