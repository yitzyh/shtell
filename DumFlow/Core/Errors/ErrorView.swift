//
//  ErrorView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/12/25.
//

import Foundation
import SwiftUI

struct ErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            
            Image(systemName: (error as? DumFlowError)?.symbolName ?? "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let suggestion = (error as? LocalizedError)?.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let onRetry = onRetry {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview("Network Error with Retry") {
    ErrorView(
        error: DumFlowError.networkUnavailable,
        onRetry: {
            // Retry action
        }
    )
}

#Preview("Authentication Error") {
    ErrorView(
        error: DumFlowError.authenticationRequired,
        onRetry: nil
    )
}

#Preview("Loading Failed with Retry") {
    ErrorView(
        error: DumFlowError.loadingFailed,
        onRetry: {
            // Retry load action
        }
    )
}

#Preview("Generic Error") {
    struct SampleError: LocalizedError {
        var errorDescription: String? {
            return "Something went wrong"
        }
        
        var recoverySuggestion: String? {
            return "Please check your settings and try again"
        }
    }
    
    return ErrorView(
        error: SampleError(),
        onRetry: {
            // Generic retry action
        }
    )
}

#Preview("Dark Mode") {
    ErrorView(
        error: DumFlowError.cloudKitUnavailable,
        onRetry: {
            // CloudKit retry action
        }
    )
    .preferredColorScheme(.dark)
}
