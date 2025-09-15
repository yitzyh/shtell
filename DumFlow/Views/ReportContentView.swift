//
//  ReportContentView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/10/25.
//

import SwiftUI

struct ReportContentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    
    let comment: Comment
    @State private var selectedReason = ""
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showSuccessMessage = false
    
    let reportReasons = [
        "Spam or misleading content",
        "Harassment or bullying",
        "Hate speech or discrimination",
        "Inappropriate or offensive content",
        "Copyright violation",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this comment?") {
                    ForEach(reportReasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                if !selectedReason.isEmpty {
                    Section("Additional details (optional)") {
                        TextEditor(text: $additionalDetails)
                            .frame(minHeight: 80)
                            .placeholder(when: additionalDetails.isEmpty) {
                                Text("Provide more context about this report...")
                                    .foregroundColor(.secondary)
                            }
                    }
                }
                
                if showSuccessMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Report submitted successfully")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Report Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        webPageViewModel.reportComment(
            comment,
            reason: selectedReason,
            details: additionalDetails
        ) { success, error in
            DispatchQueue.main.async {
                isSubmitting = false
                if (success != nil) {
                    showSuccessMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper extension for placeholder text
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
