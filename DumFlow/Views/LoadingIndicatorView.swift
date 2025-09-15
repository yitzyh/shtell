//
//  LoadingIndicatorView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/11/25.
//

import SwiftUI

struct LoadingIndicatorView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    @State private var dotOffset: [CGFloat] = [0, 0, 0]
    
    var body: some View {
        VStack(spacing: 20) {
            // SF Symbol bubble background with content
            ZStack {
                // SF Symbol bubble outline
                Image(systemName: "bubble")
                    .font(.system(size: 100))
                    .foregroundStyle(.orange)
                    .offset(y: -3)
                
                //Dots animation
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(y: dotOffset[index])
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: dotOffset[index]
                            )
                    }
                }
                .offset(y: -12)
            }
//            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color(white: 0.07) : .white)
        .onAppear {
            isAnimating = true
            // Start the bouncing animation with a slight delay to avoid initial transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for index in 0..<3 {
                    dotOffset[index] = -15
                }
            }
        }
        .onDisappear {
            isAnimating = false
            dotOffset = [0, 0, 0]
        }
    }
}

#Preview("Light Mode") {
    LoadingIndicatorView()
        .background(Color(.systemBackground))
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    LoadingIndicatorView()
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
}
