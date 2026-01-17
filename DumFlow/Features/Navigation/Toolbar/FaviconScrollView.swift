//
//  FaviconScrollView.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Horizontal scrolling favicon container
//

import SwiftUI

struct FaviconScrollView: View {
  @Binding var tabs: [TabInfo]
  @Binding var selectedTabID: String

  @State private var scrollViewProxy: ScrollViewProxy?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          // Add button (left side)
          Button(action: addNewTab) {
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 32, height: 32)

              Image(systemName: "plus")
                .foregroundColor(Color.primary.opacity(0.8))
                .font(.system(size: 16, weight: .semibold))
            }
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
          }
          .buttonStyle(PlainButtonStyle())

          // Tab favicons
          ForEach(tabs) { tab in
            FaviconItemView(
              tabID: tab.id,
              url: tab.url,
              isSelected: tab.id == selectedTabID,
              onTap: {
                selectTab(tab.id)
              }
            )
            .id(tab.id)
          }

          // Spacer for right padding
          Color.clear
            .frame(width: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      }
      .onAppear {
        scrollViewProxy = proxy
      }
      .onChange(of: selectedTabID) { oldTabID, newTabID in
        withAnimation(.easeInOut(duration: 0.3)) {
          proxy.scrollTo(newTabID, anchor: .center)
        }
      }
    }
  }

  private func addNewTab() {
    let newTab = TabInfo(
      id: UUID().uuidString,
      url: nil,
      title: "New Tab"
    )
    tabs.append(newTab)
    selectedTabID = newTab.id

    // Haptic feedback
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.prepare()
    impact.impactOccurred()
  }

  private func selectTab(_ tabID: String) {
    guard tabID != selectedTabID else { return }

    selectedTabID = tabID

    // Haptic feedback
    let selection = UISelectionFeedbackGenerator()
    selection.prepare()
    selection.selectionChanged()
  }
}

// MARK: - Tab Info Model
struct TabInfo: Identifiable {
  let id: String
  var url: URL?
  var title: String
  var favicon: UIImage?

  init(id: String = UUID().uuidString, url: URL? = nil, title: String = "") {
    self.id = id
    self.url = url
    self.title = title
  }
}

// MARK: - Preview Provider
struct FaviconScrollView_Previews: PreviewProvider {
  static var previews: some View {
    FaviconScrollView(
      tabs: .constant([
        TabInfo(url: URL(string: "https://apple.com"), title: "Apple"),
        TabInfo(url: URL(string: "https://google.com"), title: "Google"),
        TabInfo(url: URL(string: "https://github.com"), title: "GitHub")
      ]),
      selectedTabID: .constant("1")
    )
    .frame(height: 60)
    .background(Color.gray.opacity(0.2))
  }
}