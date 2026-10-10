import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let resetLayout: () -> Void

    @State private var isRecording = false
    @State private var recordingMonitor: Any?
    @State private var hotKeyError = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Show Launchpad") {
                    Button(isRecording ? String(localized: "Press a shortcut…") : preferences.hotKey.display, action: toggleRecording)
                        .frame(minWidth: 120)
                }
                if hotKeyError {
                    Text("Use ⌘, ⌥ or ⌃ with a key, or a function key on its own.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Restore Default (⌘L)") {
                    preferences.hotKey = .default
                    GlobalHotKey.shared.register(.default)
                }
                .disabled(preferences.hotKey == .default)
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("F4 works on its own, like the original Launchpad key. Press Esc to cancel recording.")
            }

            Section("General") {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                Toggle("Show in Dock", isOn: $preferences.showsDockIcon)
                    .onChange(of: preferences.showsDockIcon) {
                        NSApp.setActivationPolicy(preferences.showsDockIcon ? .regular : .accessory)
                        NSApp.activate()
                    }
            }

            Section("Layout") {
                Stepper("Columns: \(preferences.columns)", value: $preferences.columns, in: Preferences.columnRange)
                Stepper("Rows: \(preferences.rows)", value: $preferences.rows, in: Preferences.rowRange)
                Button("Reset Layout…", role: .destructive) { confirmingReset = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Reset the layout?", isPresented: $confirmingReset) {
            Button("Reset Layout", role: .destructive, action: resetLayout)
        } message: {
            Text("All folders are removed and apps are sorted by name.")
        }
        .onDisappear(perform: stopRecording)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Shortcut recording

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard recordingMonitor == nil else { return }
        isRecording = true
        hotKeyError = false
        // Release the current shortcut so pressing it again can be recorded.
        GlobalHotKey.shared.unregister()
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
            } else if let hotKey = HotKey(event: event) {
                preferences.hotKey = hotKey
                stopRecording()
            } else {
                hotKeyError = true
            }
            return nil
        }
    }

    private func stopRecording() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        guard isRecording else { return }
        isRecording = false
        GlobalHotKey.shared.register(preferences.hotKey)
    }
}
