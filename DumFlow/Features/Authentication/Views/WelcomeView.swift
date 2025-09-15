//
//  WelcomeView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/12/25.
//

import Foundation
import SwiftUI

struct WelcomeView: View {
   @Environment(\.colorScheme) var colorScheme
   @State private var isAnimating = false
   
   var body: some View {
       VStack(spacing: 20) {
           // Animated search icon
           ZStack {
               
               Circle()
                   .fill(Color.orange.opacity(0.2))
                   .frame(width: 90, height: 90)
                   .scaleEffect(1.1)
               
               // Main icon
               Image(systemName: "bubble.left.and.bubble.right")
                   .font(.system(size: 40))
                   .foregroundColor(.orange)
           }
           .padding(.bottom, 10)
           
           VStack(spacing: 12) {
               Text("Comments are for discussing content, not searches")
                   .font(.body)
                   .foregroundColor(.primary)
                   .multilineTextAlignment(.center)
           }
           .padding(.horizontal, 40)
           
           VStack(spacing: 12) {
               Text("Here are some trending pages:")
                   .font(.callout)
                   .foregroundColor(.primary)
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

#Preview("Light Mode") {
   WelcomeView()
       .background(Color(.systemBackground))
       .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    WelcomeView()
       .background(Color(.systemBackground))
       .preferredColorScheme(.dark)
}
