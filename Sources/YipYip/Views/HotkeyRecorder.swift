import AppKit
import SwiftUI
import YipYipCore

/// Click, then press a combination — the way every shortcut field on macOS works.
struct HotkeyRecorder: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    /// Called once a valid combination is captured.
    var onChange: () -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(isRecording ? "Press a shortcut…" : HotkeyDescription.display(
                    keyCode: keyCode,
                    modifiers: modifiers
                ))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(minWidth: 96)
                .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)

            if isRecording {
                Button("Cancel") { stopRecording() }
                    .buttonStyle(.plain)
                    .font(.caption)
            } else if !isDefault {
                Button("Reset") { apply(
                    keyCode: AppSettings.defaultHotkeyKeyCode,
                    modifiers: AppSettings.defaultHotkeyModifiers
                ) }
                .buttonStyle(.plain)
                .font(.caption)
            }

            if rejected {
                Text("Needs ⌘, ⌥ or ⌃")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var isDefault: Bool {
        keyCode == AppSettings.defaultHotkeyKeyCode && modifiers == AppSettings.defaultHotkeyModifiers
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        rejected = false
        isRecording = true

        // A local monitor swallows the keystroke, so recording ⌘Q does not quit
        // the app on the way past.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard event.type == .keyDown else { return nil }

            if event.keyCode == 53 {  // esc cancels
                stopRecording()
                return nil
            }

            let carbon = HotkeyDescription.carbonModifiers(fromCocoa: event.modifierFlags.rawValue)
            let code = UInt32(event.keyCode)
            guard HotkeyDescription.isUsable(keyCode: code, modifiers: carbon) else {
                rejected = true
                return nil
            }

            apply(keyCode: code, modifiers: carbon)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func apply(keyCode newKey: UInt32, modifiers newModifiers: UInt32) {
        rejected = false
        keyCode = newKey
        modifiers = newModifiers
        onChange()
    }
}
