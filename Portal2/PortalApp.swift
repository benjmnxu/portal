import SwiftUI
@preconcurrency import KeyboardShortcuts

@main
@MainActor
struct PortalApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra() {
            MenuBarContent()
        } label: {
            Label("Portal", systemImage: "bubble.left.and.bubble.right")
                .background(HotkeyBridge())
        }

        WindowGroup(id: "portal") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 200, minHeight: 140)
        }
        .defaultSize(width: 400, height: 260)
        .windowStyle(.titleBar)

        .commands {
            PortalCommands()
        }
    }

    init() {
        KeyboardShortcuts.onKeyUp(for: .togglePortal) {
            NotificationCenter.default.post(name: .togglePortal, object: nil)
        }
    }
}

private struct HotkeyBridge: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isOpen = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .togglePortal)) { _ in
                togglePortal()
            }
    }

    private func togglePortal() {
        if isOpen {
            if #available(macOS 14.0, *) { dismissWindow(id: "portal") }
            isOpen = false
        } else {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "portal")
            isOpen = true
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow // macOS 14+
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(isOpen ? "Hide Portal" : "Show Portal") {
                togglePortal()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePortal)) { _ in
            togglePortal()
        }
    }

    private func togglePortal() {
        if isOpen {
            if #available(macOS 14.0, *) {
                dismissWindow(id: "portal")
            } else {
                // macOS 13 fallback: you can keep the window open (no-op) or use AppKit to close.
            }
            isOpen = false
        } else {
            NSApp.activate(ignoringOtherApps: true) // bring app to front
            openWindow(id: "portal")                 // open (or focus) the window by ID
            isOpen = true
        }
    }
}

private struct PortalCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow // macOS 14+

    var body: some Commands {
        CommandMenu("Portal") {
            Button("Show/Hide Portal") {
                if #available(macOS 14.0, *) {
                    // Try to dismiss; if it wasn’t open, just open it
                    dismissWindow(id: "portal")
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "portal")
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "portal")
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

@MainActor
extension KeyboardShortcuts.Name {
    static let togglePortal = Self("togglePortal",
                                   default: .init(.p, modifiers: [.command, .option]))
}

// MARK: - Notification for the global toggle
private extension Notification.Name {
    static let togglePortal = Notification.Name("TogglePortal")
}
