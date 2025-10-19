//
//  ShtellError.swift
//  Shtell
//
//  Created by Isaac Herskowitz on 6/12/25.
//

import Foundation

enum ShtellError: LocalizedError {
    case networkUnavailable
    case invalidURL
    case loadingFailed
    case commentPostFailed
    case authenticationRequired
    case cloudKitUnavailable
    case invalidOperation
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .invalidURL:
            return "Invalid website URL"
        case .loadingFailed:
            return "Failed to load content"
        case .commentPostFailed:
            return "Failed to post comment"
        case .authenticationRequired:
            return "Please sign in to continue"
        case .cloudKitUnavailable:
            return "iCloud sync unavailable"
        case .invalidOperation:
            return "Invalid operation"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .invalidURL:
            return "Please enter a valid website URL"
        case .loadingFailed:
            return "Pull down to refresh or try again later"
        case .commentPostFailed:
            return "Tap to retry posting your comment"
        case .authenticationRequired:
            return "Sign in with Apple ID to post comments"
        case .cloudKitUnavailable:
            return "Check your iCloud settings"
        case .invalidOperation:
            return "This operation is not allowed"
        }
    }
    
    var symbolName: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .invalidURL:
            return "link.badge.plus"
        case .loadingFailed:
            return "exclamationmark.triangle"
        case .commentPostFailed:
            return "bubble.left.and.exclamationmark.bubble.right"
        case .authenticationRequired:
            return "person.crop.circle.badge.exclamationmark"
        case .cloudKitUnavailable:
            return "icloud.slash"
        case .invalidOperation:
            return "exclamationmark.octagon"
        }
    }
}
