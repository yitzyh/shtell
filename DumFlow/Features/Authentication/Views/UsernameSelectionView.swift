//
//  UsernameSelectionView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/10/25.
//

import SwiftUI

struct UsernameSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedUsername = ""
    @State private var selectedDisplayName = ""
    @State private var isCheckingAvailability = false
    @State private var isAvailable = true
    @State private var hasCheckedAvailability = false
    @State private var validationMessage = ""
    
    let displayName: String
    let onUsernameSelected: (String, String) -> Void // Now passes both username and display name
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Set Up Your Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose how other users will see and find you")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Display Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Your full name", text: $selectedDisplayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                Text("This is how your name will appear to other users")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Username Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("@")
                        .foregroundColor(.secondary)
                        .font(.body)
                    
                    TextField("username", text: $selectedUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: selectedUsername) { _, newValue in
                            // Clean the input as user types
                            let cleaned = cleanUsername(newValue)
                            if cleaned != newValue {
                                selectedUsername = cleaned
                            }
                            
                            // Reset validation state when user changes input
                            hasCheckedAvailability = false
                            validationMessage = ""
                            
                            // Validate format
                            validateUsernameFormat()
                        }
                }
                
                Text("Used for mentions and finding your profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Validation Messages
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .foregroundColor(isAvailable ? .green : .red)
                        .font(.caption)
                        .animation(.easeInOut(duration: 0.2), value: validationMessage)
                }
                
                if isCheckingAvailability {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking availability...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            // Requirements
            VStack(alignment: .leading, spacing: 4) {
                Text("Username requirements:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                RequirementRow(text: "3-20 characters", isValid: selectedUsername.count >= 3 && selectedUsername.count <= 20)
                RequirementRow(text: "Letters, numbers, and underscores only", isValid: isValidFormat(selectedUsername))
                RequirementRow(text: "Must start with a letter", isValid: selectedUsername.first?.isLetter ?? false)
                RequirementRow(text: "Display name required", isValid: !selectedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                checkAvailabilityAndContinue()
            }) {
                HStack {
                    if isCheckingAvailability {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isCheckingAvailability ? "Checking..." : "Continue")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!canContinue || isCheckingAvailability)
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            // Pre-fill with suggested values
            selectedDisplayName = displayName.isEmpty ? "Your Name" : displayName
            selectedUsername = generateSuggestedUsername(from: displayName)
            validateUsernameFormat()
        }
    }
    
    // MARK: - Computed Properties
    
    private var canContinue: Bool {
        return selectedUsername.count >= 3 &&
               selectedUsername.count <= 20 &&
               isValidFormat(selectedUsername) &&
               selectedUsername.first?.isLetter == true &&
               (hasCheckedAvailability ? isAvailable : true)
    }
    
    // MARK: - Helper Methods
    
    private func generateSuggestedUsername(from displayName: String) -> String {
        let cleaned = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }
        
        if cleaned.isEmpty {
            return "user" + String(Int.random(in: 1000...9999))
        }
        
        // Ensure it starts with a letter
        let suggested = cleaned.first?.isLetter == true ? cleaned : "user" + cleaned
        
        // Limit length
        return String(suggested.prefix(15))
    }
    
    private func cleanUsername(_ input: String) -> String {
        return input
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    private func isValidFormat(_ username: String) -> Bool {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return username.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }
    
    private func validateUsernameFormat() {
        guard !selectedUsername.isEmpty else {
            validationMessage = ""
            return
        }
        
        if selectedUsername.count < 3 {
            validationMessage = "Too short (minimum 3 characters)"
            isAvailable = false
        } else if selectedUsername.count > 20 {
            validationMessage = "Too long (maximum 20 characters)"
            isAvailable = false
        } else if !isValidFormat(selectedUsername) {
            validationMessage = "Only letters, numbers, and underscores allowed"
            isAvailable = false
        } else if selectedUsername.first?.isLetter != true {
            validationMessage = "Must start with a letter"
            isAvailable = false
        } else {
            validationMessage = ""
            isAvailable = true
        }
    }
    
    private func checkAvailabilityAndContinue() {
        guard canContinue else { return }
        
        // If we haven't checked availability yet, check it first
        if !hasCheckedAvailability {
            checkUsernameAvailability()
        } else if isAvailable {
            // We've already checked and it's available, proceed
            let trimmedDisplayName = selectedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            onUsernameSelected("@\(selectedUsername)", trimmedDisplayName)
        }
    }
    
    private func checkUsernameAvailability() {
        isCheckingAvailability = true
        
        // Use the AuthViewModel's actual CloudKit checking method
        Task {
            let isAvailable = await authViewModel.checkUsernameAvailability("@\(selectedUsername)")
            self.isCheckingAvailability = false
            self.hasCheckedAvailability = true
            self.isAvailable = isAvailable
            
            if isAvailable {
                self.validationMessage = "Username is available!"
            } else {
                self.validationMessage = "Username is already taken"
            }
        }
    }
}

// MARK: - Supporting Views

struct RequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let authViewModel = AuthViewModel()
    
    UsernameSelectionView(
        displayName: "John Doe",
        onUsernameSelected: { username, displayName in
        }
    )
    .environmentObject(authViewModel)
}
