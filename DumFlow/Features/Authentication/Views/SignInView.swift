//
//  SignInView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 5/12/25.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                if authViewModel.needsUsernameSelection {
                    // Show username selection view
                    if let pendingData = authViewModel.pendingUserData {
                        UsernameSelectionView(
                            displayName: pendingData.displayName,
                            onUsernameSelected: { username, displayName in
                                Task {
                                    await authViewModel.completeSignup(with: username, displayName: displayName)
                                }
                            }
                        )
                        .environmentObject(authViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    authViewModel.cancelUsernameSelection()
                                }
                            }
                        }
                    }
                } else if authViewModel.signedInUser != nil {
                    // Show signed-in user info
                    ProfileView()
                        .environmentObject(authViewModel)
                } else {
                    // Show sign-in screen
                    signInView
                }
            }
        }
        .onReceive(authViewModel.$needsUsernameSelection) { needsSelection in
            print("SignInView: needsUsernameSelection changed to: \(needsSelection)")
        }
        .onReceive(authViewModel.$signedInUser) { user in
            print("SignInView: signedInUser changed to: \(user?.username ?? "nil")")
        }
    }
    
    private var signInView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Header
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Shtell")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect and share with your community")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Sign In Button
            VStack(spacing: 16) {
                authViewModel.signInButton()
                    .frame(height: 50)
                    .cornerRadius(10)
                
                Text("Sign in to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error Message
            if let msg = authViewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
}

#Preview {
    let authViewModel = AuthViewModel()
    
    SignInView()
        .environmentObject(authViewModel)
}
