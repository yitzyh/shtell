import Foundation

struct TemporaryWebPageData {
    let title: String
    let faviconData: Data?
    let urlString: String
    
    static let empty = TemporaryWebPageData(title: "", faviconData: nil, urlString: "")
    
    var isEmpty: Bool {
        title.isEmpty && faviconData == nil
    }
}