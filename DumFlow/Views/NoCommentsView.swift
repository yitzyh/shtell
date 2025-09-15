//
//  NoCommentsView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/11/25.
//

import SwiftUI

struct NoCommentsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated bubble icon
            ZStack {
                
                // Main icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.orange)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
//                    .animation(
//                        Animation.easeInOut(duration: 1)
//                            .repeatForever(autoreverses: true)
//                            .delay(0.5),
//                        value: isAnimating
//                    )
            }
            
            VStack(spacing: 12) {
                Text("No comments yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Be the first to start the conversation")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            colorScheme == .dark ?
            Color(white: 0.07) :
            Color(.systemBackground)
        )
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    NoCommentsView()
}
