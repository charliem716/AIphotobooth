import SwiftUI

struct SlideShowView: View {
    @ObservedObject var slideShowViewModel: SlideShowViewModel
    
    var body: some View {
        ZStack {
            // Black background for fullscreen display
            Color.black
                .ignoresSafeArea()
            
            if slideShowViewModel.isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.white)
                    
                    Text("Loading photos...")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            } else if let errorMessage = slideShowViewModel.errorMessage {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Slideshow Error")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if slideShowViewModel.photoPairs.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Photos Available")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Take some photos with the booth to see them here!")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else if let currentImage = slideShowViewModel.currentImage {
                // Photo display with instant transitions (no cross-fade)
                GeometryReader { geometry in
                    Image(nsImage: currentImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Photo counter overlay
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Text(slideShowViewModel.progressInfo)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.7))
                            )
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            
            // Control instructions overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Press ESC to exit slideshow")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("Double-click window to enter fullscreen")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("Close window to exit")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                Spacer()
            }
            .opacity(slideShowViewModel.isActive ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.5).delay(1.0), value: slideShowViewModel.isActive)
        }
        .onAppear {
            print("🎬 SlideShowView appeared, slideshow active: \(slideShowViewModel.isActive)")
        }
        .onKeyPress { keyPress in
            // Only handle ESC key when no modifiers are pressed
            if keyPress.key == .escape && keyPress.modifiers.isEmpty {
                print("🎬 ESC key pressed in slideshow (no modifiers)")
                slideShowViewModel.stopSlideshow()
                return .handled
            }
            return .ignored
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = SlideShowViewModel()
    return SlideShowView(slideShowViewModel: viewModel)
        .frame(width: 1920, height: 1080)
} 