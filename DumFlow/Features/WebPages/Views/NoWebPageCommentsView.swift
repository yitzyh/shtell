import SwiftUI

struct NoWebPageCommentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No Comments Yet")
                .font(.headline)
            
            Text("Be the first to share your thoughts on this page!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NoWebPageCommentsView()
}