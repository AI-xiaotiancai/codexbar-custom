import AppKit
import Combine
import SwiftUI

final class MenuBarStatusController: NSObject {
    static let shared = MenuBarStatusController()

    private let store = TokenStore.shared
    private let oauth = OAuthManager.shared
    private let settings = AppSettings.shared

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var eventMonitor: Any?
    private var healthCheckTimer: Timer?
    private var installed = false
    private var lastActiveAccountId: String?

    private let popoverWidth: CGFloat = 300
    private let popoverMinHeight: CGFloat = 180
    private let popoverMaxHeight: CGFloat = 560
    private let popoverDefaultHeight: CGFloat = 420

    private override init() {
        super.init()
    }

    func install() {
        restoreStatusItem(forceRebuild: true)
        guard !installed else { return }
        installed = true

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: popoverWidth, height: popoverDefaultHeight)
        popover.contentViewController = NSHostingController(rootView: makePopoverRootView())
        schedulePeriodicHealthChecks()

        store.$accounts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAccountsChanged()
            }
            .store(in: &cancellables)

        settings.$showDockIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.restoreStatusItem(forceRebuild: true)
                self?.scheduleRecoveryChecks()
            }
            .store(in: &cancellables)

        handleAccountsChanged()
    }

    func ensureStatusItem() {
        if shouldRebuildStatusItem {
            removeStatusItem()
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item

            if let button = item.button {
                button.target = self
                button.action = #selector(togglePopover(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.imagePosition = .imageLeading
                button.font = .systemFont(ofSize: 11, weight: .medium)
            }
        }

        refreshAppearance()
    }

    func restoreStatusItem(forceRebuild: Bool = false) {
        if forceRebuild {
            removeStatusItem()
        }
        ensureStatusItem()
    }

    func scheduleRecoveryChecks() {
        let delays: [TimeInterval] = [0.5, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.ensureStatusItem()
            }
        }
    }

    func schedulePeriodicHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.shouldRebuildStatusItem {
                    self.restoreStatusItem(forceRebuild: true)
                }
            }
        }
        if let healthCheckTimer {
            RunLoop.main.add(healthCheckTimer, forMode: .common)
        }
    }

    func restoreIfNeededFromMainWindow() {
        guard shouldRebuildStatusItem else { return }
        guard NSApp.mainWindow != nil || NSApp.keyWindow != nil else { return }
        restoreStatusItem()
    }

    private func handleAccountsChanged() {
        let activeAccountId = store.accounts.first(where: { $0.isActive })?.accountId
        let activeAccountChanged = lastActiveAccountId != activeAccountId
        lastActiveAccountId = activeAccountId

        if activeAccountChanged {
            restoreStatusItem()
            scheduleRecoveryChecks()
        } else {
            refreshAppearance()
        }
    }

    private var shouldRebuildStatusItem: Bool {
        statusItem == nil || statusItem?.button == nil || statusItem?.button?.window == nil
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            stopEventMonitor()
        } else {
            refreshPopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            startEventMonitor()
        }
    }

    private func refreshPopoverContent() {
        if let hosting = popover.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = makePopoverRootView()
        } else {
            popover.contentViewController = NSHostingController(rootView: makePopoverRootView())
        }
    }

    private func makePopoverRootView() -> AnyView {
        AnyView(
            MenuBarView { [weak self] preferredHeight in
                self?.updatePopoverHeight(preferredHeight)
            }
                .environmentObject(store)
                .environmentObject(oauth)
                .environmentObject(settings)
        )
    }

    private func updatePopoverHeight(_ preferredHeight: CGFloat) {
        let update = { [weak self] in
            guard let self else { return }
            let clampedHeight = min(self.popoverMaxHeight, max(self.popoverMinHeight, preferredHeight))
            guard abs(self.popover.contentSize.height - clampedHeight) > 0.5 else { return }
            self.popover.contentSize = NSSize(width: self.popoverWidth, height: clampedHeight)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func refreshAppearance() {
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "CodexBar")
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(config)
        button.title = statusText
        button.toolTip = "CodexBar"
    }

    private var statusText: String {
        guard let active = store.accounts.first(where: { $0.isActive }) else { return "" }
        if active.secondaryExhausted { return L.weeklyLimit }
        if active.showsPrimaryQuota && active.primaryExhausted { return L.hourLimit }
        if active.showsPrimaryQuota {
            return "\(Int(active.primaryRemainingPercent))%·\(Int(active.effectiveWeeklyRemainingPercent))%"
        }
        return "\(Int(active.effectiveWeeklyRemainingPercent))%"
    }

    private var iconName: String {
        let ref: [TokenAccount]
        if let active = store.accounts.first(where: { $0.isActive }) {
            ref = [active]
        } else {
            ref = store.accounts
        }
        if ref.contains(where: { $0.isBanned }) {
            return "xmark.circle.fill"
        }
        if ref.contains(where: { $0.secondaryExhausted }) {
            return "exclamationmark.triangle.fill"
        }
        if ref.contains(where: { $0.quotaExhausted || $0.hasUsageWarning }) {
            return "bolt.circle.fill"
        }
        return "terminal.fill"
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.popover.isShown else { return }
                self.popover.performClose(nil)
                self.stopEventMonitor()
            }
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
