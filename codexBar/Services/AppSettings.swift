import AppKit
import Combine
import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: Keys.showDockIcon)
            applyActivationPolicy()
        }
    }

    private enum Keys {
        static let showDockIcon = "showDockIcon"
    }

    private init() {
        if UserDefaults.standard.object(forKey: Keys.showDockIcon) == nil {
            UserDefaults.standard.set(true, forKey: Keys.showDockIcon)
        }
        showDockIcon = UserDefaults.standard.bool(forKey: Keys.showDockIcon)
        applyActivationPolicy()
    }

    func applyActivationPolicy() {
        DispatchQueue.main.async {
            let policy: NSApplication.ActivationPolicy = self.showDockIcon ? .regular : .accessory
            if NSApp.activationPolicy() != policy {
                NSApp.setActivationPolicy(policy)
            }
        }
    }

    func toggleDockIcon() {
        showDockIcon.toggle()
    }
}
