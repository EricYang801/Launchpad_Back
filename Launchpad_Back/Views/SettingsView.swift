//
//  SettingsView.swift
//  Launchpad_Back
//
//  設定視窗（App 選單 > 設定…，或按 ⌘,）
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var store = HotKeySettingsStore.shared

    @State private var isRecording = false
    @State private var recordingMonitor: Any?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("快捷鍵")
                .font(.headline)

            HStack {
                Text("顯示 / 隱藏 Launchpad")

                Spacer()

                Button(action: toggleRecording) {
                    Text(isRecording ? "按下新的快捷鍵…" : store.binding.display)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(minWidth: 110)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("一般按鍵需搭配 ⌘、⌥ 或 ⌃ 修飾鍵；F1–F20 功能鍵可單獨使用。錄製中按 Esc 取消。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Spacer()
                Button("還原預設（⌘L）") {
                    store.resetToDefault()
                    errorMessage = nil
                }
                .disabled(store.binding == .default)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - 快捷鍵錄製

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard recordingMonitor == nil else { return }

        isRecording = true
        errorMessage = nil

        // 錄製期間暫時取消全域快捷鍵，避免按到現有組合時觸發視窗切換
        NotificationCenter.default.post(name: .hotKeyRecordingBegan, object: nil)

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleRecordingEvent(event)
            return nil  // 錄製期間吞掉所有按鍵
        }
    }

    private func handleRecordingEvent(_ event: NSEvent) {
        // Esc 取消錄製
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        guard let binding = HotKeySettingsStore.makeBinding(from: event) else {
            errorMessage = "無效的組合：請加上 ⌘/⌥/⌃ 修飾鍵，或使用 F1–F20 功能鍵"
            return
        }

        store.binding = binding
        stopRecording()
    }

    private func stopRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }

        guard isRecording else { return }

        isRecording = false
        NotificationCenter.default.post(name: .hotKeyRecordingEnded, object: nil)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
