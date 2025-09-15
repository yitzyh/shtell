import SwiftUI

struct ReaderModeSettingsView: View {
    @ObservedObject var settings: ReaderModeSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    backgroundColorSection
                    textColorSection
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    fontSizeSection
                    fontFamilySection
                    lineHeightSection
                    contentWidthSection
                } header: {
                    Text("Typography")
                }
                
                Section {
                    resetButton
                } footer: {
                    Text("Reset all reader mode settings to their default values.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Reader Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var backgroundColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach(ReaderBackgroundColor.allCases, id: \.self) { color in
                    backgroundColorOption(color)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func backgroundColorOption(_ color: ReaderBackgroundColor) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.backgroundColor = color
                settings.saveSettings()
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                            .opacity(settings.backgroundColor == color ? 1 : 0)
                    )
                
                Text(color.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var textColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Color")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach(ReaderTextColor.allCases, id: \.self) { color in
                    textColorOption(color)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func textColorOption(_ color: ReaderTextColor) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.textColor = color
                settings.saveSettings()
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                            .opacity(settings.textColor == color ? 1 : 0)
                    )
                
                Text(color.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font Size")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Font Size", selection: $settings.fontSize) {
                ForEach(ReaderFontSize.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.fontSize) { _, _ in
                settings.saveSettings()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var fontFamilySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font Family")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Font Family", selection: $settings.fontFamily) {
                ForEach(ReaderFontFamily.allCases, id: \.self) { family in
                    Text(family.displayName).tag(family)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.fontFamily) { _, _ in
                settings.saveSettings()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var lineHeightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line Height")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Line Height", selection: $settings.lineHeight) {
                ForEach(ReaderLineHeight.allCases, id: \.self) { height in
                    Text(height.displayName).tag(height)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.lineHeight) { _, _ in
                settings.saveSettings()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var contentWidthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Width")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Content Width", selection: $settings.contentWidth) {
                ForEach(ReaderContentWidth.allCases, id: \.self) { width in
                    Text(width.displayName).tag(width)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.contentWidth) { _, _ in
                settings.saveSettings()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var resetButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                settings.resetToDefaults()
            }
        } label: {
            Text("Reset to Defaults")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Reader Mode Toggle Button
struct ReaderModeToggleButton: View {
    let isReaderMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isReaderMode ? "doc.text" : "doc.text.image")
                    .font(.system(size: 16, weight: .medium))
                
                Text(isReaderMode ? "Exit Reader" : "Reader Mode")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reader Mode Controls Overlay
struct ReaderModeControlsOverlay: View {
    @ObservedObject var settings: ReaderModeSettings
    let isReaderMode: Bool
    let onToggleReaderMode: () -> Void
    let onShowSettings: () -> Void
    
    @State private var showControls = true
    @State private var hideTimer: Timer?
    
    var body: some View {
        if isReaderMode {
            VStack {
                HStack {
                    Spacer()
                    
                    if showControls {
                        HStack(spacing: 12) {
                            // Settings button
                            Button {
                                onShowSettings()
                            } label: {
                                Image(systemName: "textformat")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                            
                            // Exit reader mode button
                            Button {
                                onToggleReaderMode()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: showControls)
            .onTapGesture {
                toggleControls()
            }
            .onAppear {
                startHideTimer()
            }
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            startHideTimer()
        } else {
            hideTimer?.invalidate()
        }
    }
    
    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

#Preview {
    ReaderModeSettingsView(settings: ReaderModeSettings())
}