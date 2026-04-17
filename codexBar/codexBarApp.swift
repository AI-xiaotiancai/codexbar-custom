import SwiftUI

final class CodexBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            MenuBarStatusController.shared.install()
            MenuBarStatusController.shared.scheduleRecoveryChecks()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.async {
            MenuBarStatusController.shared.restoreStatusItem()
        }
    }
}

@main
struct codexBarApp: App {
    @NSApplicationDelegateAdaptor(CodexBarAppDelegate.self) private var appDelegate
    @StateObject private var store = TokenStore.shared
    @StateObject private var oauth = OAuthManager.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup("CodexAppBar", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(oauth)
                .environmentObject(settings)
                .frame(minWidth: 360, minHeight: 200)
        }
    }
}
