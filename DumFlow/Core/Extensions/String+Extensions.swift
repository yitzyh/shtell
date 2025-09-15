//
//  String+Extensions.swift.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 11/2/24.
//

import Foundation


extension String {
    func stripTrailingSlash() -> String {
        if self.hasSuffix("/") {
            return String(self.dropLast())
        }
        return self
    }
}

extension String {
    func shortURL() -> String{
        
        let pattern = "^(?:https?://)?(?:www\\.)?([^/]+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: self.utf16.count)
            if let match = regex.firstMatch(in: self, options: [], range: range) {
                if let domainRange = Range(match.range(at: 1), in: self) {
                    var domain = String(self[domainRange])
                    
                    // Strip mobile language prefixes like "en.m.", "fr.m.", etc.
                    let mobilePrefix = #"^[a-z]{2}\.m\."#
                    domain = domain.replacingOccurrences(of: mobilePrefix, with: "", options: .regularExpression)
                    
                    return domain
                }
            }
        }
        return self
    }
}

extension String {
   /// Returns a normalized version of the URL string, preserving essential parameters
   var normalizedURL_OLD: String? {
       guard var components = URLComponents(string: self) else { return nil }
       
       // Always remove fragment
       components.fragment = nil
       components.user = nil
       components.password = nil
       
       // Handle query parameters intelligently
       if let host = components.host?.lowercased() {
           
           // Reddit-specific handling
           if host.contains("reddit.com") {
               return normalizeRedditURL(components)
           }
           
           // Instagram-specific handling
           else if host.contains("instagram.com") {
               return normalizeInstagramURL(components)
           }
           
           // For YouTube - KEEP essential parameters
           else if host.contains("youtube.com") {
               components.queryItems = components.queryItems?.filter { item in
                   ["v", "t", "list", "search_query"].contains(item.name) // Keep video ID, timestamp, playlist, and search queries
               }
           }
           
           // For Google - keep search functionality
           else if host.contains("google.com") {
               // Keep search parameters for Google search results
               components.queryItems = components.queryItems?.filter { item in
                   ["q", "tbm", "start", "safe"].contains(item.name) // Keep search query and essential search params
               }
           }
           
           // For other search engines - allow and keep essential parameters
           else if ["bing.com", "duckduckgo.com", "yahoo.com"].contains(where: { host.contains($0) }) {
               // Keep search parameters for these search engines
               components.queryItems = components.queryItems?.filter { item in
                   ["q", "p", "s", "start", "first"].contains(item.name) // Keep search queries and pagination
               }
           }
           
           // For most other sites - remove tracking parameters but keep others
           else {
               let trackingParams = ["utm_source", "utm_medium", "utm_campaign", "utm_content",
                                   "utm_term", "fbclid", "gclid", "ref", "source"]
               components.queryItems = components.queryItems?.filter { item in
                   !trackingParams.contains(item.name.lowercased())
               }
               
               // Remove query entirely if no items remain
               if components.queryItems?.isEmpty == true {
                   components.query = nil
               }
           }
       } else {
           // No host - remove all query params as before
           components.query = nil
       }
       
       guard var urlString = components.string else { return nil }
       
       // Remove trailing slash (but not for root paths)
       if urlString.hasSuffix("/") && !urlString.hasSuffix("://") {
           let url = URL(string: urlString)
           if url?.path != "/" {
               urlString.removeLast()
           }
       }
       
       return urlString
   }
   
   // Instagram-specific URL normalization function
   private func normalizeInstagramURL(_ components: URLComponents) -> String? {
       var instagramComponents = components
       
       // Remove Instagram tracking and sharing parameters
       let instagramTrackingParams = [
           "igsh",           // Instagram share parameter
           "igshid",         // Another Instagram share ID variant
           "utm_source",
           "utm_medium",
           "utm_campaign",
           "utm_content",
           "utm_term",
           "fbclid",         // Facebook click ID (Instagram is owned by Meta)
           "ref",
           "source"
       ]
       
       // Filter out the tracking parameters but keep any essential ones
       instagramComponents.queryItems = instagramComponents.queryItems?.filter { item in
           !instagramTrackingParams.contains(item.name.lowercased())
       }
       
       // Remove query entirely if no items remain after filtering
       if instagramComponents.queryItems?.isEmpty == true {
           instagramComponents.query = nil
       }
       
       let result = instagramComponents.string
       return result
   }
   
   // Reddit-specific URL normalization - preserves original subdomain
   private func normalizeRedditURL(_ components: URLComponents) -> String? {
       var redditComponents = components
       
       // Keep the original host (m.reddit.com, www.reddit.com, etc.) instead of forcing old.reddit.com
       // This preserves the user's preferred Reddit interface
       
       // Remove Reddit tracking parameters but keep essential ones
       let redditTrackingParams = ["utm_source", "utm_medium", "utm_campaign", "context", "ref", "source"]
       redditComponents.queryItems = redditComponents.queryItems?.filter { item in
           !redditTrackingParams.contains(item.name.lowercased())
       }
       
       // Remove query entirely if no items remain
       if redditComponents.queryItems?.isEmpty == true {
           redditComponents.query = nil
       }
       
       let result = redditComponents.string
       return result
   }
}

// MARK: - New URL Normalization to prevent CloudKit crashes
extension String {
    /// Returns a normalized version of the URL string that strips tracking parameters and prevents CloudKit record name crashes
    var normalizedURL: String? {
        guard var components = URLComponents(string: self) else { return nil }
        
        // Always remove fragments, user info, and passwords
        components.fragment = nil
        components.user = nil
        components.password = nil
        
        // Aggressive tracking parameter removal to keep URLs short
        let commonTrackingParams = [
            // Google Analytics & Ads
            "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term",
            "gclid", "gclsrc", "fbclid", "dclid", "msclkid",
            
            // Amazon tracking
            "tag", "ref", "ref_", "linkCode", "camp", "creative", "creativeASIN",
            
            // Social media tracking  
            "igshid", "igsh", "fbclid",
            
            // E-commerce tracking
            "AFID", "sid", "DFA", "CPNG", "adgroup", "LID", "network", "device", 
            "location", "gad_source", "gad_campaignid", "gbraid", "fndsrc",
            
            // Generic tracking
            "source", "medium", "campaign", "content", "term", "ref", "referrer"
        ]
        
        // Remove all tracking parameters
        components.queryItems = components.queryItems?.filter { item in
            !commonTrackingParams.contains(item.name.lowercased())
        }
        
        // Remove query entirely if no items remain
        if components.queryItems?.isEmpty == true {
            components.query = nil
        }
        
        guard var urlString = components.string else { return nil }
        
        // Remove trailing slash (but not for root paths)
        if urlString.hasSuffix("/") && !urlString.hasSuffix("://") {
            let url = URL(string: urlString)
            if url?.path != "/" {
                urlString.removeLast()
            }
        }
        
        // Ensure the URL is not too long for CloudKit record names (255 character limit)
        if urlString.count > 200 {
            // Create a hash-based record name for very long URLs
            let hash = urlString.hash
            if let host = components.host {
                return "\(host)-\(abs(hash))"
            } else {
                return "url-\(abs(hash))"
            }
        }
        
        return urlString
    }
}
