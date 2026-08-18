import Carbon
import Cocoa

/// Registers a system-wide hotkey using the Carbon Event API.
@MainActor
final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    /// Carbon installs handlers per application, not per hotkey — installing it
    /// again on every re-registration would stack duplicate callbacks.
    private var isHandlerInstalled = false

    // Store the singleton callback target so Carbon can find it.
    private static var current: HotkeyManager?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        HotkeyManager.current = self

        // Re-registering replaces the previous combination.
        unregister()

        if !isHandlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ -> OSStatus in
                    MainActor.assumeIsolated {
                        HotkeyManager.current?.handler?()
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )
            isHandlerInstalled = true
        }

        let hotkeyID = EventHotKeyID(signature: OSType(0x5949_5059), id: 1) // "YIPY"
        RegisterEventHotKey(keyCode, modifiers, hotkeyID,
                            GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    deinit {
        MainActor.assumeIsolated {
            if let ref = hotkeyRef {
                UnregisterEventHotKey(ref)
            }
        }
    }
}
