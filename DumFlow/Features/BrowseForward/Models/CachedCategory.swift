//
//  CachedCategory.swift
//  Shtell
//
//  Cached category with timestamp for TTL management
//

import Foundation

struct CachedCategory: Codable {
    let category: String
    let items: [BrowseForwardItem]
    let cachedAt: Date
    let itemCount: Int

    init(category: String, items: [BrowseForwardItem]) {
        self.category = category
        self.items = items
        self.cachedAt = Date()
        self.itemCount = items.count
    }

    /// Check if cache is still valid (4 hour TTL)
    var isValid: Bool {
        let ttl: TimeInterval = 4 * 60 * 60 // 4 hours
        return Date().timeIntervalSince(cachedAt) < ttl
    }

    /// Time remaining until cache expires
    var timeUntilExpiration: TimeInterval {
        let ttl: TimeInterval = 4 * 60 * 60
        let elapsed = Date().timeIntervalSince(cachedAt)
        return max(0, ttl - elapsed)
    }

    /// Human-readable cache age
    var cacheAge: String {
        let elapsed = Date().timeIntervalSince(cachedAt)
        let hours = Int(elapsed / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else {
            return "\(minutes)m ago"
        }
    }
}
