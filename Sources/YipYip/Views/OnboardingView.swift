import SwiftUI
import YipYipCore

/// Shown once, on first launch. Its job is to set expectations before macOS
/// starts asking for permissions out of context.
struct OnboardingView: View {
    let shortcut: String
    var onOpenAccessibility: () -> Void
    var onFinish: () -> Void

    @State private var accessibilityGranted = PasteHelper.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to YipYip")
                    .font(.system(size: 22, weight: .semibold))
                Text("Everything you copy stays on this Mac, encrypted, and one keystroke away.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            step(
                symbol: "keyboard",
                title: "Press \(shortcut) to search",
                detail: "Arrow keys move, Enter pastes into whatever you were using, Esc closes. You can change the shortcut in Settings."
            )

            step(
                symbol: "key.fill",
                title: "Keychain keeps your key",
                detail: "History is encrypted with a key stored in your Keychain. macOS asks for access on launch — choose Always Allow."
            )

            step(
                symbol: accessibilityGranted ? "checkmark.circle.fill" : "hand.raised.fill",
                title: accessibilityGranted ? "Accessibility is enabled" : "Accessibility lets YipYip paste for you",
                detail: accessibilityGranted
                    ? "Selected clips will land straight at your cursor."
                    : "Without it, clips are still copied — you just press ⌘V yourself. You can enable it any time.",
                tint: accessibilityGranted ? .green : .orange
            )

            HStack(spacing: 10) {
                if !accessibilityGranted {
                    Button("Open Accessibility Settings") {
                        onOpenAccessibility()
                        // The list updates while this window is open.
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            accessibilityGranted = PasteHelper.isTrusted
                        }
                    }
                }
                Spacer()
                Button("Start Using YipYip", action: onFinish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private func step(symbol: String, title: String, detail: String, tint: Color = .accentColor) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
