//
//  ToolbarAnimations.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Enhanced animations and transitions for toolbar
//

import SwiftUI

// MARK: - Transition Extensions
extension AnyTransition {
  static var toolbarSlide: AnyTransition {
    AnyTransition.asymmetric(
      insertion: .move(edge: .bottom).combined(with: .opacity),
      removal: .move(edge: .bottom).combined(with: .opacity)
    )
  }

  static var faviconScale: AnyTransition {
    AnyTransition.scale(scale: 0.8)
      .combined(with: .opacity)
  }

  static var glowPulse: AnyTransition {
    AnyTransition.modifier(
      active: GlowEffect(amount: 0),
      identity: GlowEffect(amount: 1)
    )
  }
}

// MARK: - Glow Effect Modifier
struct GlowEffect: ViewModifier {
  let amount: Double

  func body(content: Content) -> some View {
    content
      .shadow(
        color: Color.blue.opacity(0.3 * amount),
        radius: 8 * amount,
        x: 0,
        y: 0
      )
      .shadow(
        color: Color.blue.opacity(0.2 * amount),
        radius: 16 * amount,
        x: 0,
        y: 0
      )
  }
}

// MARK: - Liquid Motion Modifier
struct LiquidMotion: ViewModifier {
  @State private var phase: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(
        GeometryReader { geometry in
          Canvas { context, size in
            // Create liquid wave effect
            let path = Path { path in
              path.move(to: CGPoint(x: 0, y: 0))

              for x in stride(from: 0, to: size.width, by: 1) {
                let relativeX = x / size.width
                let y = sin((relativeX + phase) * .pi * 2) * 2
                path.addLine(to: CGPoint(x: x, y: y))
              }

              path.addLine(to: CGPoint(x: size.width, y: 0))
              path.closeSubpath()
            }

            context.fill(
              path,
              with: .linearGradient(
                Gradient(colors: [
                  Color.white.opacity(0.1),
                  Color.white.opacity(0.05),
                  Color.clear
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: 10)
              )
            )
          }
        }
        .allowsHitTesting(false)
      )
      .onAppear {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
          phase = 1
        }
      }
  }
}

// MARK: - Ripple Effect
struct RippleEffect: ViewModifier {
  @State private var ripples: [Ripple] = []

  struct Ripple: Identifiable {
    let id = UUID()
    let position: CGPoint
    let startTime = Date()
  }

  func body(content: Content) -> some View {
    content
      .overlay(
        GeometryReader { geometry in
          ZStack {
            ForEach(ripples) { ripple in
              RippleView(ripple: ripple)
            }
          }
        }
        .allowsHitTesting(false)
      )
      .onTapGesture { location in
        ripples.append(Ripple(position: location))

        // Remove ripple after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          ripples.removeAll { $0.id == ripples.first?.id }
        }
      }
  }
}

struct RippleView: View {
  let ripple: RippleEffect.Ripple
  @State private var scale: CGFloat = 0.1
  @State private var opacity: Double = 0.6

  var body: some View {
    Circle()
      .fill(Color.white.opacity(opacity))
      .frame(width: 100, height: 100)
      .scaleEffect(scale)
      .position(ripple.position)
      .onAppear {
        withAnimation(.easeOut(duration: 0.8)) {
          scale = 2
          opacity = 0
        }
      }
  }
}

// MARK: - Elastic Bounce
struct ElasticBounce: AnimatableModifier {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    content
      .scaleEffect(1 + (sin(progress * Double.pi * 2) * 0.1))
      .rotationEffect(.degrees(sin(progress * Double.pi * 4) * 2))
  }
}

// MARK: - View Extensions
extension View {
  func liquidMotion() -> some View {
    modifier(LiquidMotion())
  }

  func rippleEffect() -> some View {
    modifier(RippleEffect())
  }

  func elasticBounce(progress: CGFloat) -> some View {
    modifier(ElasticBounce(progress: progress))
  }

  func glowEffect(amount: Double) -> some View {
    modifier(GlowEffect(amount: amount))
  }
}

// MARK: - Animation Presets
struct ToolbarAnimationPresets {
  static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
  static let smooth = Animation.easeInOut(duration: 0.3)
  static let quick = Animation.easeOut(duration: 0.2)
  static let elastic = Animation.interpolatingSpring(stiffness: 180, damping: 15)
  static let liquid = Animation.timingCurve(0.68, -0.55, 0.265, 1.55, duration: 0.5)
}