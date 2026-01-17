//
//  GlassEffectView.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Liquid glass blur effect for bottom toolbar
//

import SwiftUI
import UIKit

struct GlassEffectView: UIViewRepresentable {
  let style: UIBlurEffect.Style
  let opacity: Double

  init(style: UIBlurEffect.Style = .systemUltraThinMaterial, opacity: Double = 0.92) {
    self.style = style
    self.opacity = opacity
  }

  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurEffect = UIBlurEffect(style: style)
    let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)

    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.alpha = opacity

    // Add subtle vibrancy for depth
    let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
    vibrancyView.translatesAutoresizingMaskIntoConstraints = false
    blurView.contentView.addSubview(vibrancyView)

    NSLayoutConstraint.activate([
      vibrancyView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
      vibrancyView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
      vibrancyView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
      vibrancyView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
    ])

    return blurView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    uiView.alpha = opacity
  }
}

// MARK: - Liquid Glass Modifier
extension View {
  func liquidGlass(opacity: Double = 0.92) -> some View {
    self
      .background(
        GlassEffectView(opacity: opacity)
          .ignoresSafeArea()
      )
      .overlay(
        // Subtle gradient for glass shine
        LinearGradient(
          gradient: Gradient(colors: [
            Color.white.opacity(0.1),
            Color.white.opacity(0.05),
            Color.clear
          ]),
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .overlay(
        // Edge highlight
        RoundedRectangle(cornerRadius: 20)
          .strokeBorder(
            LinearGradient(
              gradient: Gradient(colors: [
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
              ]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
  }
}