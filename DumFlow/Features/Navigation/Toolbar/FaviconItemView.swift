//
//  FaviconItemView.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Individual favicon item with selection state
//

import SwiftUI
import WebKit

struct FaviconItemView: View {
  let tabID: String
  let url: URL?
  let isSelected: Bool
  let onTap: () -> Void

  @State private var favicon: Image?
  @State private var animationScale: CGFloat = 1.0
  @State private var glowOpacity: Double = 0

  private var faviconSize: CGFloat {
    isSelected ? 40 : 32
  }

  var body: some View {
    Button(action: {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        onTap()
      }
    }) {
      ZStack {
        // Blue glow for selected state
        if isSelected {
          Circle()
            .fill(
              RadialGradient(
                gradient: Gradient(colors: [
                  Color.blue.opacity(0.6),
                  Color.blue.opacity(0.3),
                  Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 30
              )
            )
            .frame(width: 60, height: 60)
            .blur(radius: 8)
            .opacity(glowOpacity)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: glowOpacity)
        }

        // Favicon container
        ZStack {
          // Background circle
          Circle()
            .fill(Color.white.opacity(isSelected ? 0.95 : 0.8))
            .frame(width: faviconSize, height: faviconSize)

          // Favicon or placeholder
          if let favicon = favicon {
            favicon
              .resizable()
              .scaledToFit()
              .frame(width: faviconSize - 8, height: faviconSize - 8)
              .clipShape(Circle())
          } else {
            // Default globe icon
            Image(systemName: "globe")
              .foregroundColor(Color.gray.opacity(0.6))
              .font(.system(size: faviconSize * 0.5))
          }
        }
        .scaleEffect(animationScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .shadow(
          color: isSelected ? Color.blue.opacity(0.4) : Color.black.opacity(0.2),
          radius: isSelected ? 8 : 4,
          x: 0,
          y: 2
        )
      }
    }
    .buttonStyle(PlainButtonStyle())
    .onAppear {
      loadFavicon()
      if isSelected {
        glowOpacity = 1
      }
    }
    .onChange(of: isSelected) { oldValue, newValue in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        animationScale = newValue ? 1.15 : 1.0
        glowOpacity = newValue ? 1 : 0
      }

      // Bounce animation
      if newValue {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
          animationScale = 1.0
        }
      }
    }
  }

  private func loadFavicon() {
    guard let url = url else { return }

    // Try Google's favicon service first
    let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "")&sz=128")

    if let faviconURL = faviconURL {
      URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
        if let data = data, let uiImage = UIImage(data: data) {
          DispatchQueue.main.async {
            self.favicon = Image(uiImage: uiImage)
          }
        }
      }.resume()
    }
  }
}

// MARK: - Preview Provider
struct FaviconItemView_Previews: PreviewProvider {
  static var previews: some View {
    HStack(spacing: 20) {
      FaviconItemView(
        tabID: "1",
        url: URL(string: "https://apple.com"),
        isSelected: false,
        onTap: {}
      )

      FaviconItemView(
        tabID: "2",
        url: URL(string: "https://google.com"),
        isSelected: true,
        onTap: {}
      )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
  }
}