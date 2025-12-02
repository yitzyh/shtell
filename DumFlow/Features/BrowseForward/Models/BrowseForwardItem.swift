//
//  BrowseForwardItem.swift
//  Shtell
//
//  Lightweight model for BrowseForward queue items from Vercel API
//

import Foundation

struct BrowseForwardItem: Codable, Identifiable, Hashable {
    let url: String
    let title: String
    let thumbnailUrl: String?  // Optional - some items don't have thumbnails
    let domain: String
    let category: String?  // Optional - some items don't have category
    let bfCategory: String?
    let bfSubcategory: String?  // Subcategory tag (e.g., "racing", "puzzle", "action")
    let isActive: Bool
    let wordCount: Int?

    // Additional fields that Vercel API returns
    let upvotes: Int?
    let interactions: Int?
    let source: String?
    let contentType: String?
    let qualityScore: Int?
    let aiSummary: String?
    let tags: [String]?
    let isMobileOptimized: Bool?
    let fetchedAt: String?
    let status: String?

    // Computed property for Identifiable - based on URL
    var id: String { url }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: BrowseForwardItem, rhs: BrowseForwardItem) -> Bool {
        return lhs.url == rhs.url
    }
}
