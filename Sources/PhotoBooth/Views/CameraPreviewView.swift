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
        
        // Add crop overlay
        addCropOverlay(to: containerView)
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer as? AVCaptureVideoPreviewLayer else { return }
        
        if let session = session {
            layer.session = session
        }
        
        // Update frame on size changes
        DispatchQueue.main.async {
            layer.frame = nsView.bounds
            updateCropOverlay(in: nsView)
        }
    }
    
    private func addCropOverlay(to view: NSView) {
        // Create overlay view
        let overlayView = NSView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.clear.cgColor
        
        view.addSubview(overlayView)
        
        // Pin overlay to fill the container
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        overlayView.identifier = NSUserInterfaceItemIdentifier("cropOverlay")
        
        // Initial overlay setup
        updateCropOverlay(in: view)
    }
    
    private func updateCropOverlay(in view: NSView) {
        guard let overlayView = view.subviews.first(where: { $0.identifier?.rawValue == "cropOverlay" }) else { return }
        
        // Clear existing layers
        overlayView.layer?.sublayers?.removeAll()
        
        let viewBounds = view.bounds
        let targetAspectRatio: CGFloat = 1536.0 / 1024.0 // 3:2 landscape
        
        // Calculate crop area (same logic as our crop function)
        let viewAspectRatio = viewBounds.width / viewBounds.height
        
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        
        if viewAspectRatio > targetAspectRatio {
            // View is wider than target - crop will use full height
            cropHeight = viewBounds.height
            cropWidth = cropHeight * targetAspectRatio
        } else {
            // View is taller than target - crop will use full width
            cropWidth = viewBounds.width
            cropHeight = cropWidth / targetAspectRatio
        }
        
        // Center the crop area
        let cropX = (viewBounds.width - cropWidth) / 2
        let cropY = (viewBounds.height - cropHeight) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Create dimming overlay (everything outside crop area)
        let dimmingLayer = CALayer()
        dimmingLayer.frame = viewBounds
        dimmingLayer.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        
        // Create clear area for crop region
        let maskLayer = CALayer()
        maskLayer.frame = viewBounds
        maskLayer.backgroundColor = NSColor.black.cgColor
        
        let clearLayer = CALayer()
        clearLayer.frame = cropRect
        clearLayer.backgroundColor = NSColor.clear.cgColor
        clearLayer.compositingFilter = "sourceOut"
        maskLayer.addSublayer(clearLayer)
        
        dimmingLayer.mask = maskLayer
        overlayView.layer?.addSublayer(dimmingLayer)
        
        // Add crop boundary lines
        let borderLayer = CAShapeLayer()
        let borderPath = CGPath(rect: cropRect, transform: nil)
        borderLayer.path = borderPath
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(0.8).cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 2.0
        borderLayer.lineDashPattern = [8, 4]
        overlayView.layer?.addSublayer(borderLayer)
        
        // Add corner indicators
        let cornerSize: CGFloat = 20
        let cornerStroke: CGFloat = 3
        
        let corners = [
            (cropRect.minX, cropRect.minY),      // top-left
            (cropRect.maxX, cropRect.minY),      // top-right
            (cropRect.minX, cropRect.maxY),      // bottom-left
            (cropRect.maxX, cropRect.maxY)       // bottom-right
        ]
        
        for (x, y) in corners {
            let cornerLayer = CAShapeLayer()
            let cornerPath = CGMutablePath()
            
            if x == cropRect.minX && y == cropRect.minY { // top-left
                cornerPath.move(to: CGPoint(x: x, y: y + cornerSize))
                cornerPath.addLine(to: CGPoint(x: x, y: y))
                cornerPath.addLine(to: CGPoint(x: x + cornerSize, y: y))
            } else if x == cropRect.maxX && y == cropRect.minY { // top-right
                cornerPath.move(to: CGPoint(x: x - cornerSize, y: y))
                cornerPath.addLine(to: CGPoint(x: x, y: y))
                cornerPath.addLine(to: CGPoint(x: x, y: y + cornerSize))
            } else if x == cropRect.minX && y == cropRect.maxY { // bottom-left
                cornerPath.move(to: CGPoint(x: x, y: y - cornerSize))
                cornerPath.addLine(to: CGPoint(x: x, y: y))
                cornerPath.addLine(to: CGPoint(x: x + cornerSize, y: y))
            } else { // bottom-right
                cornerPath.move(to: CGPoint(x: x - cornerSize, y: y))
                cornerPath.addLine(to: CGPoint(x: x, y: y))
                cornerPath.addLine(to: CGPoint(x: x, y: y - cornerSize))
            }
            
            cornerLayer.path = cornerPath
            cornerLayer.strokeColor = NSColor.white.cgColor
            cornerLayer.lineWidth = cornerStroke
            cornerLayer.fillColor = NSColor.clear.cgColor
            overlayView.layer?.addSublayer(cornerLayer)
        }
        
        // Add text label
        let textLayer = CATextLayer()
        textLayer.string = "1536×1024 Capture Area"
        textLayer.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textLayer.fontSize = 14
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        textLayer.cornerRadius = 4
        textLayer.alignmentMode = .center
        
        let textSize = CGSize(width: 180, height: 24)
        textLayer.frame = CGRect(
            x: cropRect.minX + (cropRect.width - textSize.width) / 2,
            y: cropRect.minY + 8,
            width: textSize.width,
            height: textSize.height
        )
        
        overlayView.layer?.addSublayer(textLayer)
    }
} 