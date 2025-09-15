import SwiftUI

struct WebKitLoadingView: View {
    @State private var progress: Double = 0.0
    @State private var currentPhase = "Initializing browser..."
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App branding
                VStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Shtell")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Progress section
                VStack(spacing: 16) {
                    // Current phase text
                    Text(currentPhase)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Progress bar
                    VStack(spacing: 8) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                        
                        // Progress percentage
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Beta notice
                VStack(spacing: 8) {
                    Button(action: { showDetails.toggle() }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("iOS 26 Beta")
                            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                    
                    if showDetails {
                        Text("WebKit initialization is slower on iOS 26 beta. This will be resolved in the stable release.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            startProgressSimulation()
        }
    }
    
    private func startProgressSimulation() {
        // Phase 1: Network process (0-3 seconds, 0-30%)
        updateProgress(to: 0.1, phase: "Starting network services...", delay: 0.5)
        updateProgress(to: 0.3, phase: "Network services ready", delay: 3.0)
        
        // Phase 2: GPU process (3-6 seconds, 30-60%)
        updateProgress(to: 0.4, phase: "Initializing graphics engine...", delay: 3.5)
        updateProgress(to: 0.6, phase: "Graphics engine ready", delay: 6.0)
        
        // Phase 3: WebContent process (6-10 seconds, 60-100%)
        updateProgress(to: 0.7, phase: "Loading web content engine...", delay: 6.5)
        updateProgress(to: 0.9, phase: "Web content engine ready", delay: 9.0)
        updateProgress(to: 1.0, phase: "Browser ready!", delay: 10.0)
    }
    
    private func updateProgress(to value: Double, phase: String, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.5)) {
                progress = value
                currentPhase = phase
            }
        }
    }
}

#Preview {
    WebKitLoadingView()
}