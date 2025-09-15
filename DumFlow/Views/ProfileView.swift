//
//  ProfileView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/14/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var userService = UserService()
    @Environment(\.dismiss) var dismiss
    @State private var showSignOutConfirmation = false
    @State private var showEditUsername = false
    @State private var showEditDisplayName = false
    @State private var showEditBio = false
    @State private var editedUsername = ""
    @State private var editedDisplayName = ""
    @State private var editedBio = ""
    @State private var isRecEnabled = false
    // Forward Browsing Preferences
    @State private var technologyEnabled = true
    @State private var businessEnabled = false
    @State private var scienceEnabled = true
    @State private var generalNewsEnabled = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Edit profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible spacer to balance the back button
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Profile Avatar Section
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // Current avatar (left)
                        Circle()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    Button("Edit picture") {
                        // Handle avatar editing
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 40)
                
                // Profile Fields
                VStack(spacing: 0) {
                    // Name Row
                    profileRow(
                        label: "Name",
                        value: authViewModel.signedInUser?.displayName ?? "Display Name",
                        action: {
                            editedDisplayName = authViewModel.signedInUser?.displayName ?? ""
                            showEditDisplayName = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Username Row
                    profileRow(
                        label: "Username",
                        value: authViewModel.signedInUser?.username ?? "username",
                        action: {
                            editedUsername = authViewModel.signedInUser?.username ?? ""
                            showEditUsername = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 20)

                    
                    
                    // Forward Browsing Settings Section
//                    VStack(alignment: .leading, spacing: 12) {
//                        HStack {
//                            Text("Forward Browsing")
//                                .font(.body)
//                                .foregroundColor(.primary)
//                            
//                            Spacer()
//                            
//                            Text("Categories")
//                                .font(.body)
//                                .foregroundColor(.secondary)
//                        }
//                        .padding(.horizontal, 20)
//                        .padding(.top, 16)
//                        
//                        HStack{
//                            Text("Track Usage for Recomendations")
//                                .lineLimit(1)
//                            Image(systemName: "info.circle")
//                            Spacer()
//                            Toggle("", isOn: $isRecEnabled)
//                                .toggleStyle(SwitchToggleStyle())
//                                .frame(width: 60)
//                        }
//                        .padding(.horizontal, 20)
//
//
//                
//                                                
//                        VStack(spacing: 8) {
//                            Toggle("Technology", isOn: $technologyEnabled)
//                                .toggleStyle(SwitchToggleStyle())
//                                .padding(.horizontal, 20)
//                                .onChange(of: technologyEnabled) { saveForwardBrowsingPreferences() }
//                            
//                            Toggle("Business", isOn: $businessEnabled)
//                                .toggleStyle(SwitchToggleStyle())
//                                .padding(.horizontal, 20)
//                                .onChange(of: businessEnabled) { saveForwardBrowsingPreferences() }
//                            
//                            Toggle("Science", isOn: $scienceEnabled)
//                                .toggleStyle(SwitchToggleStyle())
//                                .padding(.horizontal, 20)
//                                .onChange(of: scienceEnabled) { saveForwardBrowsingPreferences() }
//                            
//                            Toggle("General News", isOn: $generalNewsEnabled)
//                                .toggleStyle(SwitchToggleStyle())
//                                .padding(.horizontal, 20)
//                                .onChange(of: generalNewsEnabled) { saveForwardBrowsingPreferences() }
//                        }
//                        .padding(.bottom, 8)
//                    }
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Bio Row
                    profileRow(
                        label: "Bio",
                        value: authViewModel.signedInUser?.bio ?? "Add a bio",
                        action: {
                            editedBio = authViewModel.signedInUser?.bio ?? ""
                            showEditBio = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Member Since Row (read-only)
                    HStack {
                        Text("Member Since")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(authViewModel.signedInUser?.dateCreated
                            .formatted(.dateTime.year().month().day()) ?? "N/A")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Spacer()
                
                // Sign Out Button
                    
                Button("Sign Out") {
                    showSignOutConfirmation = true
                }
                .font(.body)
                .foregroundColor(.red)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .onAppear {
            loadForwardBrowsingPreferences()
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showEditUsername) {
            EditNameSheet(
                title: "Edit Username",
                currentValue: editedUsername,
                placeholder: "Enter username",
                isUpdating: $userService.isLoading,
                onSave: { newUsername in
                    updateUsername(newUsername)
                },
                onCancel: {
                    showEditUsername = false
                }
            )
        }
        .sheet(isPresented: $showEditDisplayName) {
            EditNameSheet(
                title: "Edit Display Name",
                currentValue: editedDisplayName,
                placeholder: "Enter display name",
                isUpdating: $userService.isLoading,
                onSave: { newDisplayName in
                    updateDisplayName(newDisplayName)
                },
                onCancel: {
                    showEditDisplayName = false
                }
            )
        }
        .sheet(isPresented: $showEditBio) {
            EditBioSheet(
                currentValue: editedBio,
                isUpdating: $userService.isLoading,
                onSave: { newBio in
                    updateBio(newBio)
                },
                onCancel: {
                    showEditBio = false
                }
            )
        }
    }
    
    @ViewBuilder
    private func profileRow(label: String, value: String, showChevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
    
    private func updateUsername(_ newUsername: String) {
        guard let user = authViewModel.signedInUser else { return }
        
        Task {
            do {
                try await userService.updateUsername(newUsername, for: user)
                
                await authViewModel.refreshUserData()
                showEditUsername = false
                authViewModel.errorMessage = nil
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateDisplayName(_ newDisplayName: String) {
        guard let user = authViewModel.signedInUser else { return }
        
        Task {
            do {
                try await userService.updateDisplayName(newDisplayName, for: user)
                
                await authViewModel.refreshUserData()
                showEditDisplayName = false
                authViewModel.errorMessage = nil
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateBio(_ newBio: String) {
        guard let user = authViewModel.signedInUser else { return }
        
        Task {
            do {
                try await userService.updateBio(newBio, for: user)
                
                await authViewModel.refreshUserData()
                showEditBio = false
                authViewModel.errorMessage = nil
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func saveForwardBrowsingPreferences() {
        guard let user = authViewModel.signedInUser else { return }
        
        var preferences: [String] = []
        if technologyEnabled { preferences.append("technology") }
        if businessEnabled { preferences.append("business") }
        if scienceEnabled { preferences.append("science") }
        if generalNewsEnabled { preferences.append("general") }
        
        // Save to UserDefaults for now (you can later save to CloudKit)
        UserDefaults.standard.set(preferences, forKey: "forwardBrowsingPreferences_\(user.userID)")
        
        print("✅ Saved forward browsing preferences: \(preferences)")
    }
    
    private func loadForwardBrowsingPreferences() {
        guard let user = authViewModel.signedInUser else { return }
        
        let preferences = UserDefaults.standard.stringArray(forKey: "forwardBrowsingPreferences_\(user.userID)") ?? ["technology", "science"]
        
        technologyEnabled = preferences.contains("technology")
        businessEnabled = preferences.contains("business")
        scienceEnabled = preferences.contains("science")
        generalNewsEnabled = preferences.contains("general")
        
        print("✅ Loaded forward browsing preferences: \(preferences)")
    }
    
}

struct EditNameSheet: View {
    let title: String
    @State var currentValue: String
    let placeholder: String
    @Binding var isUpdating: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                TextField(placeholder, text: $currentValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                Spacer()
                
                if isUpdating {
                    ProgressView("Updating...")
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
                }
            }
        }
    }
}

struct EditBioSheet: View {
    @State var currentValue: String
    @Binding var isUpdating: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Edit Bio")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $currentValue)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    HStack {
                        Spacer()
                        Text("\(currentValue.count)/150")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                if isUpdating {
                    ProgressView("Updating...")
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedBio = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedBio.isEmpty ? "" : trimmedBio)
                    }
                    .disabled(currentValue.count > 150 || isUpdating)
                }
            }
        }
        .onChange(of: currentValue) { oldValue, newValue in
            if newValue.count > 150 {
                currentValue = String(newValue.prefix(150))
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
