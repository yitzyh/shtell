//
//  CloudKitError.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/14/25.
//


import CloudKit
import Foundation

import CloudKit
import Foundation

enum CloudKitError: LocalizedError {
    case iCloudAccountNotAvailable
    case networkUnavailable
    case invalidRecord
    case recordNotFound
    case permissionFailure
    case quotaExceeded
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudAccountNotAvailable:
            return "iCloud account not available"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidRecord:
            return "Invalid record data"
        case .recordNotFound:
            return "Record not found"
        case .permissionFailure:
            return "Permission denied"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .iCloudAccountNotAvailable:
            return "Please sign in to iCloud in Settings"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .invalidRecord:
            return "The data format is invalid"
        case .recordNotFound:
            return "The requested item was not found"
        case .permissionFailure:
            return "Check your iCloud permissions"
        case .quotaExceeded:
            return "Free up iCloud storage space"
        case .unknown:
            return "Please try again later"
        }
    }
    
    static func from(_ error: Error) -> CloudKitError {
        guard let ckError = error as? CKError else {
            return .unknown(error)
        }
        
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .notAuthenticated:
            return .iCloudAccountNotAvailable
        case .unknownItem:
            return .recordNotFound
        case .permissionFailure:
            return .permissionFailure
        case .quotaExceeded:
            return .quotaExceeded
        default:
            return .unknown(error)
        }
    }
}
