import SwiftUI
import Combine

class FaviconFetcher: ObservableObject {
    static func fetchFavicon(for urlString: String) -> AnyPublisher<Data?, Never> {
        guard let url = URL(string: urlString) else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { data, _ in
                return String(data: data, encoding: .utf8)
            }
            .compactMap { (html: String?) in
                html.flatMap { parseHTMLForFavicon(html: $0, baseURL: url) }
            }
            .flatMap { $0 }
            .catch { _ in fallbackFavicon(for: url) }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    private static func parseHTMLForFavicon(html: String, baseURL: URL) -> AnyPublisher<Data?, Never>? {

         do {
             let regex = try NSRegularExpression(pattern: "<link[^>]*rel=\"(?:shortcut )?icon\"[^>]*>|<link[^>]*rel=\"(?:icon|apple-touch-icon)\"[^>]*>", options: .caseInsensitive)
             let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))

             for match in matches {
                 if let range = Range(match.range, in: html) {
                     let linkTag = String(html[range])
                     if let url = extractFaviconURL(from: linkTag, baseURL: baseURL) {
                         return downloadFavicon(from: url)
                     }
                 }
             }
         } catch {
         }
         return nil
     }

//    private static func extractFaviconURL(from linkTag: String, baseURL: URL) -> URL? {
//         do {
//             let regex = try NSRegularExpression(pattern: "href=\"([^\"]+)\"", options: .caseInsensitive)
//             let matches = regex.matches(in: linkTag, options: [], range: NSRange(location: 0, length: linkTag.utf16.count))
//
//             for match in matches {
//                 if let range = Range(match.range(at: 1), in: linkTag) {
//                     let href = String(linkTag[range])
//                     if let url = URL(string: href, relativeTo: baseURL) {
//                         return url
//                     } else {
//                     }
//                 }
//             }
//         } catch {
//         }
//
//         return nil
//     }
    
    private static func extractFaviconURL(from linkTag: String, baseURL: URL) -> URL? {
        // Look for href="…" or href='…'
        let pattern = #"href\s*=\s*['"]([^'"]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let ns = linkTag as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = regex.firstMatch(in: linkTag, options: [], range: range),
           match.numberOfRanges >= 2,
           let hrefRange = Range(match.range(at: 1), in: linkTag)
        {
            var href = String(linkTag[hrefRange])
            // Handle protocol-relative URLs like //example.com/favicon.ico
            if href.hasPrefix("//") {
                href = "\(baseURL.scheme ?? "https"):\(href)"
            }
            // Build absolute URL against base
            if let url = URL(string: href, relativeTo: baseURL)?.absoluteURL {
                return url
            } else {
            }
        } else {
        }
        return nil
    }



    private static func downloadFavicon(from url: URL) -> AnyPublisher<Data?, Never> {
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    private static func fallbackFavicon(for url: URL) -> AnyPublisher<Data?, Never> {
        
        let fallbackURLs = [
             url.appendingPathComponent("favicon.ico"),
             url.appendingPathComponent("/apple-touch-icon.png"),
             url.appendingPathComponent("/apple-touch-icon-precomposed.png")
         ]
         
         let publishers = fallbackURLs.map { downloadFavicon(from: $0) }
         
         return Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
}
