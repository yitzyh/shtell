//
//  webPageThumbnail.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/10/25.
//

import SwiftUI

struct WebPageThumbnail: View {
    var webPage: WebPage
    
    private let thumbnailWidth: CGFloat = 100
    private let thumbnailHeight: CGFloat = 75
    
    var body: some View {
        ZStack(alignment: .topTrailing){
            // ✅ UPDATED: Use CloudKit WebPage properties
            if let thumbnailData = webPage.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                // First priority: Thumbnail image
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .clipped()
                    .cornerRadius(5)
            } else if let faviconData = webPage.faviconData, let faviconUIImage = UIImage(data: faviconData) {
                // Second priority: Favicon image
                VStack {
                    Image(uiImage: faviconUIImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 0.2)
                }
            } else {
                // Third priority: First letter of URL
                VStack {
                    // ✅ UPDATED: Direct urlString access (no optional)
                    Text(webPage.urlString.shortURL().prefix(1).uppercased())
                }
                .font(.largeTitle)
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 0.2)
                }
            }
        }
    }
}

// ✅ UPDATED: CloudKit-based preview
//#Preview {
//    let mockWebPage = WebPage(
//        id: CKRecord.ID(recordName: "preview"),
//        urlString: "https://apple.com",
//        title: "Apple - Official Website",
//        dateCreated: Date(),
//        commentCount: 15,
//        likeCount: 23,
//        saveCount: 8,
//        faviconData: nil,
//        thumbnailData: nil
//    )
//    
//    return WebPageThumbnail(webPage: mockWebPage)
//        .padding()
//}
