import AppKit
import SwiftUI

@main
struct PieceOfPaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LibraryStore(rootURL: LibraryLocation.current)

    var body: some Scene {
        Window("Piece of Paper", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 780)
        .commands {
            PaperCommands(store: store)
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (e.g. `swift run`),
        // harmless when launched from the .app bundle.
        #if DEBUG
        if DebugSnapshot.isEnabled {
            DebugSnapshot.scheduleIfRequested()
            return
        }
        #endif
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
