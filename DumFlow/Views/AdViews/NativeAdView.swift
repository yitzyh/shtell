//
//  NativeAdView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/1/25.
//

import SwiftUI

struct NativeAdView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    let adTitle: String
    let adDescription: String
    let sponsorName: String
    let adImageName: String
    let logoImageName: String
    let ctaText: String
    
    @State private var isPressed = false
    
    init(
        adTitle: String = "Discover Amazing Products",
        adDescription: String = "Find the best deals on premium items. Shop now and save up to 50% on select products.",
        sponsorName: String = "BestDeals",
        adImageName: String = "sponsor-image.fill",
        logoImageName: String = "smiley.fill",
        ctaText: String = "Shop Now"
    ) {
        self.adTitle = adTitle
        self.adDescription = adDescription
        self.sponsorName = sponsorName
        self.adImageName = adImageName
        self.logoImageName = logoImageName
        self.ctaText = ctaText
    }
    
    var body: some View {
        VStack(spacing: 0) {
                        
            VStack {
                // Header with sponsor info (mirroring favicon + URL)
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(uiColor: .systemGray4) : .white)
                            .frame(width: 25, height: 25)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(lineWidth: 1)
                            .frame(width: 25, height: 25)
                        
                        // Use asset image if it starts with asset:, otherwise use system image
                        if logoImageName.hasPrefix("asset:") {
                            Image(String(logoImageName.dropFirst(6))) // Remove "asset:" prefix
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                        } else {
                            Image(systemName: logoImageName)
                                .frame(width: 15, height: 15)
                                .foregroundColor(.orange)
                        }
                    }
                    .onTapGesture {
                        handleAdTap()
                    }
                    
                    VStack {
                        Text("ad.\(sponsorName.lowercased()).com")
                            .font(.headline.bold())
                            .foregroundStyle(Color.blue)
                            .onTapGesture {
                                handleAdTap()
                            }
                    }
                    
                    Text("Promoted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                    
                    Spacer()
                }
                
                // Content area (mirroring title + thumbnail)
                HStack(alignment: .top) {
                    Text(adDescription)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            handleAdTap()
                        }
                    
                    Spacer()
                    
                    ZStack(alignment: .topTrailing) {
                        // Ad image/thumbnail
                        ZStack {
//                            RoundedRectangle(cornerRadius: 5)
//                                .fill(LinearGradient(
//                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                ))
//                                .frame(width: 80, height: 80)
                            
                            if adImageName.hasPrefix("asset:") {
                                // dropFirst gives a Substring, so convert to String
                                let assetName = String(adImageName.dropFirst(6))  // now a String
                                Image(assetName)
                                  .resizable()
                                  .scaledToFill()
//                                  .renderingMode(.original)
//                                  .aspectRatio(contentMode: .fit)
                                  .frame(width: 100, height: 75)
                            } else {
                                Image(systemName: adImageName)
                                  .resizable()
                                  .scaledToFill()
//                                  .aspectRatio(contentMode: .fit)
                                  .frame(width: 100, height: 75)
                            }                        }
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary, lineWidth: 0.5))
                        .onTapGesture {
                            handleAdTap()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        // "Ad" badge (mirroring saved indicator)
//                        ZStack {
//                            Image(systemName: "rectangle.fill")
//                                .scaleEffect(x: 1.2, y: 0.6)
//                                .foregroundColor(colorScheme == .dark ? Color(white: 0.07) : .white)
//                            
//                            Text("AD")
//                                .font(.system(size: 8, weight: .bold))
//                                .foregroundColor(.orange)
//                        }
//                        .offset(x: -5, y: -4)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Action buttons (mirroring like/comment/save buttons)
                HStack {
                    HStack(alignment: .center) {
                        // CTA Button (primary action)
//                        HStack {
//                            Image(systemName: "cart.fill")
//                                .foregroundColor(.white)
//                            
//                            Text(ctaText)
//                                .font(.system(.footnote, weight: .medium))
//                                .foregroundColor(.white)
//                                .lineLimit(1)
//                        }
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 6)
//                        .background(
//                            RoundedRectangle(cornerRadius: 15)
//                                .fill(LinearGradient(
//                                    colors: [.blue, .purple],
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                ))
//                        )
//                        .scaleEffect(isPressed ? 0.95 : 1.0)
//                        .onTapGesture {
//                            withAnimation(.easeInOut(duration: 0.1)) {
//                                isPressed = true
//                            }
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                                withAnimation(.easeInOut(duration: 0.1)) {
//                                    isPressed = false
//                                }
//                                handleAdTap()
//                            }
//                        }
                        
                        // Learn More (secondary action)
                        HStack {
//                            Image(systemName: "info.circle")
//                                .foregroundColor(.primary)
                            
                            Text("Learn More")
                                .font(.system(.footnote, weight: .light))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.primary, lineWidth: 0.2)
                        )
                        .onTapGesture {
                            handleAdTap()
                        }
                        
                        HStack {
                            Image(systemName: "star")
                                .foregroundColor(.primary)
                                .font(.system(.body, weight: .light))
                                .scaleEffect(x: 1.3, y: 0.9)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.primary, lineWidth: 0.2)
                        )
                        
                        // Ad Options (mirroring save button)
                        HStack {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .font(.system(.body, weight: .light))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 28)
                        .frame(minWidth: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.primary, lineWidth: 0.2)
                        )
                        .onTapGesture {
                            // Handle ad options (hide ad, report, etc.)
                        }
                    }
                    
                    Spacer()
                }
                .font(.system(.title3, weight: .thin))
                .padding(.horizontal, 1)
            }
            .padding(20)
            
            // Bottom separator (matching WebPageRowView)
            Rectangle()
                .foregroundColor(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                .frame(height: 0.3)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .background(
            // Subtle gradient background to distinguish from regular content
            LinearGradient(
                colors: [
                    (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6)).opacity(0.3),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func handleAdTap() {
        // Handle ad click - would typically open ad landing page
        print("🔗 Ad tapped: \(adTitle)")
    }
}

#Preview {
    VStack(spacing: 0) {
        NativeAdView()
        
        NativeAdView(
            adTitle: "Premium Coffee Delivered",
            adDescription: "Get freshly roasted coffee beans delivered to your door. Subscribe now for 20% off your first order.",
            sponsorName: "CoffeePlus",
            adImageName: "asset:your-ad-image",
            logoImageName: "asset:sponsor-logo",
            ctaText: "Subscribe"
        )
        
        NativeAdView(
            adTitle: "Learn SwiftUI Today",
            adDescription: "Master iOS development with our comprehensive SwiftUI course. Join thousands of developers.",
            sponsorName: "DevAcademy",
            adImageName: "swift",
            logoImageName: "graduationcap.fill",
            ctaText: "Enroll Now"
        )
    }
    .preferredColorScheme(.light)
}
