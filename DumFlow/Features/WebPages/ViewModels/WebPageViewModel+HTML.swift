//
//  WebPageViewModel+HTML.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 1/7/25.
//  Rewritten for CloudKit on 6/14/25.
//

import Foundation
import Combine
import UIKit
// ❌ REMOVED: import CoreData

extension WebPageViewModel {

    // 🎯 KEEP: All HTML scraping functionality - perfect for social media content!
    // This extension remains largely unchanged because the HTML scraping logic
    // is independent of the data storage layer and works great for social apps

    // MARK: — 1. HTML Fetch & Title Extraction

    /// Downloads raw HTML from a URL and emits it as a String.
    /// 🚀 SOCIAL MEDIA FEATURE: Reddit URL conversion for better scraping
    func fetchHTML(from url: URL) -> AnyPublisher<String, Error> {
        // ✅ KEEP: Reddit URL conversion - great for social media content scraping
        let scrapingURL: URL
        if let host = url.host?.lowercased(), host.contains("reddit.com") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.host = "old.reddit.com"
            scrapingURL = components?.url ?? url
        } else {
            scrapingURL = url
        }
        
        // ✅ KEEP: Proper headers for social media content scraping
        var request = URLRequest(url: scrapingURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("upgrade-insecure-requests", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { data, response in
                // 🔍 DEBUG: Log response for social media URLs
                if scrapingURL.host?.contains("reddit") == true {
                }
                return String(data: data, encoding: .utf8) ?? ""
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    /// 🚀 SOCIAL MEDIA FEATURE: Extract social media optimized titles
    func extractTitle(from html: String) -> String? {
        // Priority order optimized for social media content:
        // 1. Open Graph title (Facebook, Twitter, etc.)
        // 2. Twitter specific title
        // 3. Standard HTML title
        if let og = extractMetaTag(from: html, with: "og:title") {
            return og
        }
        if let tw = extractMetaTag(from: html, with: "twitter:title") {
            return tw
        }
        return extractStandardTitle(from: html)
    }

    /// Fallback regex to find <title>…</title> if no social meta tags found
    func extractStandardTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<title>(.*?)</title>",
            options: .caseInsensitive
        ) else {
            return nil
        }
        let ns = html as NSString
        let results = regex.matches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
        return results.first.map { ns.substring(with: $0.range(at: 1)) }
    }

    /// Decodes HTML entities for clean social media display
    func decodeHTMLEntities(in string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let decoded = (try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ))?.string
        return decoded ?? string
    }

    /// Finds social media meta tags (og:, twitter:, etc.)
    func extractMetaTag(from html: String, with property: String) -> String? {
        let pattern = "<meta[^>]+property=\"\(property)\"[^>]+content=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return nil
        }
        let ns = html as NSString
        let matches = regex.matches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        )
        return matches.first.map { ns.substring(with: $0.range(at: 1)) }
    }
    
    // MARK: - Media Fetching
    // All favicon and thumbnail fetching now handled by MediaFetcher.swift
    // This extension now only contains HTML parsing utilities
}
