import SwiftUI
import Combine
import UserNotifications

private final class ObserverBox {
    var token: NSObjectProtocol?
}

struct MenuBarView: View {
    var onPreferredHeightChanged: ((CGFloat) -> Void)? = nil

    @EnvironmentObject var store: TokenStore
    @EnvironmentObject var oauth: OAuthManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var isRefreshing = false
    @State private var showError: String?
    @State private var showSuccess: String?
    @State private var now = Date()
    @State private var refreshingAccounts: Set<String> = []

    // 每 10 秒刷新倒计时显示
    private let countdownTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    // 菜单打开时 10 秒快速刷新活跃账号；菜单关闭时 5 分钟后台刷新全部
    private let quickTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let slowTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var menuVisible = false
    @State private var languageToggle = false  // 用于触发语言切换后的重绘
    @State private var lastReportedHeight: CGFloat = 0
    @State private var measuredThreeAccountListHeight: CGFloat = 0
    @State private var measuredAllAccountsListHeight: CGFloat = 0

    private let fallbackScrollableListHeight: CGFloat = 300
    private let fallbackAllAccountsListHeight: CGFloat = 220

    /// email -> accounts (active pinned to top, exhausted pinned to bottom)
    private var groupedAccounts: [(email: String, accounts: [TokenAccount])] {
        var dict: [String: [TokenAccount]] = [:]
        var order: [String] = []
        for acc in store.accounts {
            if dict[acc.email] == nil {
                dict[acc.email] = []
                order.append(acc.email)
            }
            dict[acc.email]!.append(acc)
        }
        // sort accounts within each group
        let sortedOrder = order.sorted { e1, e2 in
            let best1 = bestStatus(dict[e1]!)
            let best2 = bestStatus(dict[e2]!)
            return best1 < best2
        }
        return sortedOrder.map { email in
            let sorted = dict[email]!.sorted { a, b in
                if a.displaySortRank != b.displaySortRank { return a.displaySortRank < b.displaySortRank }
                if a.primaryRemainingPercent != b.primaryRemainingPercent { return a.primaryRemainingPercent > b.primaryRemainingPercent }
                if a.secondaryRemainingPercent != b.secondaryRemainingPercent { return a.secondaryRemainingPercent > b.secondaryRemainingPercent }
                return a.accountId < b.accountId
            }
            return (email: email, accounts: sorted)
        }
    }

    private func bestStatus(_ accounts: [TokenAccount]) -> Int {
        accounts.map(\.displaySortRank).min() ?? 3
    }

    private func statusRank(_ a: TokenAccount) -> Int {
        switch a.usageStatus {
        case .ok: return 0
        case .warning: return 1
        case .exceeded: return 2
        case .banned: return 3
        }
    }

    private var availableCount: Int {
        store.accounts.filter { $0.usageStatus == .ok }.count
    }

    private var shouldScrollAccounts: Bool {
        store.accounts.count >= 4
    }

    private var firstThreeGroupedAccounts: [(email: String, accounts: [TokenAccount])] {
        var remaining = 3
        var result: [(email: String, accounts: [TokenAccount])] = []

        for group in groupedAccounts {
            guard remaining > 0 else { break }
            let prefix = Array(group.accounts.prefix(remaining))
            guard !prefix.isEmpty else { continue }
            result.append((email: group.email, accounts: prefix))
            remaining -= prefix.count
        }

        return result
    }

    private var effectiveScrollableListHeight: CGFloat {
        measuredThreeAccountListHeight > 0 ? measuredThreeAccountListHeight : fallbackScrollableListHeight
    }

    private var effectiveAllAccountsListHeight: CGFloat {
        measuredAllAccountsListHeight > 0 ? measuredAllAccountsListHeight : fallbackAllAccountsListHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("CodexBar")
                    .font(.system(size: 13, weight: .semibold))

                if !store.accounts.isEmpty {
                    Text(L.available(availableCount, store.accounts.count))
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(availableCount > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(availableCount > 0 ? .green : .red)
                        .cornerRadius(4)
                }

                Spacer()

                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.borderless)
                .help(L.refreshUsage)
                .disabled(isRefreshing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.accounts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(L.noAccounts)
                        .foregroundColor(.secondary)
                    Text(L.addAccountHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.vertical, showsIndicators: shouldScrollAccounts) {
                    accountGroupsView(groupedAccounts)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(height: shouldScrollAccounts ? effectiveScrollableListHeight : effectiveAllAccountsListHeight)
                .scrollIndicators(shouldScrollAccounts ? .visible : .hidden)
                .background(alignment: .topLeading) {
                    if shouldScrollAccounts {
                        accountGroupsView(firstThreeGroupedAccounts)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .allowsHitTesting(false)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: MenuBarThreeAccountsHeightKey.self,
                                        value: proxy.size.height
                                    )
                                }
                            )
                    } else {
                        accountGroupsView(groupedAccounts)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .allowsHitTesting(false)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: MenuBarAllAccountsHeightKey.self,
                                        value: proxy.size.height
                                    )
                                }
                            )
                    }
                }
            }

            if let success = showSuccess {
                Divider()
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            if let error = showError {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        showError = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // 底部操作栏
            HStack(spacing: 8) {
                if let lastUpdate = store.accounts.compactMap({ $0.lastChecked }).max() {
                    Text(relativeTime(lastUpdate))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    oauth.startOAuth { result in
                        switch result {
                        case .success(let tokens):
                            let account = AccountBuilder.build(from: tokens)
                            store.addOrUpdate(account)
                            Task { await WhamService.shared.refreshOne(account: account, store: store) }
                        case .failure(let error):
                            showError = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(L.addAccount)

                Button {
                    openWindow(id: "main")
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(L.openWindow)

                Button {
                    settings.toggleDockIcon()
                    showSuccess = L.settingsSaved
                    showError = nil
                } label: {
                    Image(systemName: settings.showDockIcon ? "dock.rectangle" : "menubar.rectangle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(settings.showDockIcon ? L.dockAndMenuBar : L.menuBarOnly)

                Button {
                    switch L.languageOverride {
                    case nil:   L.languageOverride = true
                    case true:  L.languageOverride = false
                    case false: L.languageOverride = nil
                    }
                    languageToggle.toggle()
                } label: {
                    // languageToggle 作为 @State 依赖，保证切换后重绘
                    let label = languageToggle ? L.languageOverride : L.languageOverride
                    Text(label == nil ? "AUTO" : (label == true ? "中" : "EN"))
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("切换语言 / Switch Language")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(L.quit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: MenuBarPreferredHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(MenuBarPreferredHeightKey.self) { value in
            let normalized = ceil(value)
            guard abs(lastReportedHeight - normalized) > 0.5 else { return }
            lastReportedHeight = normalized
            onPreferredHeightChanged?(normalized)
        }
        .onPreferenceChange(MenuBarThreeAccountsHeightKey.self) { value in
            guard value > 0 else { return }
            let normalized = ceil(value)
            guard abs(measuredThreeAccountListHeight - normalized) > 0.5 else { return }
            measuredThreeAccountListHeight = normalized
        }
        .onPreferenceChange(MenuBarAllAccountsHeightKey.self) { value in
            guard value > 0 else { return }
            let normalized = ceil(value)
            guard abs(measuredAllAccountsListHeight - normalized) > 0.5 else { return }
            measuredAllAccountsListHeight = normalized
        }
        .onReceive(countdownTimer) { _ in now = Date() }
        .onReceive(quickTimer) { _ in
            guard menuVisible,
                  let active = store.accounts.first(where: { $0.isActive }),
                  !active.secondaryExhausted else { return }
            Task {
                await refreshAccount(active)
                store.markActiveAccount()
                autoSwitchIfNeeded()
            }
        }
        .onReceive(slowTimer) { _ in
            Task {
                if !menuVisible { await refresh() }
                store.markActiveAccount()
                autoSwitchIfNeeded()
            }
        }
        .onAppear {
            menuVisible = true
            store.markActiveAccount()
        }
        .onDisappear { menuVisible = false }
    }

    @ViewBuilder
    private func accountGroupsView(_ groups: [(email: String, accounts: [TokenAccount])]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groups, id: \.email) { group in
                VStack(alignment: .leading, spacing: 2) {
                    // Email group header
                    Text(group.email)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 4)

                    // Account rows
                    ForEach(group.accounts) { account in
                        AccountRowView(
                            account: account,
                            isActive: account.isActive,
                            now: now,
                            isRefreshing: refreshingAccounts.contains(account.id)
                        ) {
                            activateAccount(account)
                        } onRefresh: {
                            Task { await refreshAccount(account) }
                        } onReauth: {
                            reauthAccount(account)
                        } onDelete: {
                            store.remove(account)
                        }
                    }
                }
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return L.justUpdated }
        if seconds < 3600 { return L.minutesAgo(seconds / 60) }
        return L.hoursAgo(seconds / 3600)
    }

    private func activateAccount(_ account: TokenAccount) {
        do {
            try store.activate(account)
        } catch {
            showError = error.localizedDescription
        }
    }

    /// 检查当前账号额度，必要时自动切换到最优账号
    private func autoSwitchIfNeeded() {
        guard let active = store.accounts.first(where: { $0.isActive }) else { return }

        let primary5hRemaining  = 100.0 - active.primaryUsedPercent
        let secondary7dRemaining = 100.0 - active.secondaryUsedPercent

        let shouldSwitch = primary5hRemaining <= 10.0 || secondary7dRemaining <= 3.0
        guard shouldSwitch else { return }

        // 找最优账号：未被封禁、token 未过期、非当前账号、usageStatus 最优
        let candidates = store.accounts.filter {
            !$0.isSuspended && !$0.tokenExpired && $0.accountId != active.accountId
        }.sorted {
            if $0.displaySortRank != $1.displaySortRank { return $0.displaySortRank < $1.displaySortRank }
            let rem0 = min(100 - $0.primaryUsedPercent, 100 - $0.secondaryUsedPercent)
            let rem1 = min(100 - $1.primaryUsedPercent, 100 - $1.secondaryUsedPercent)
            return rem0 > rem1
        }

        guard let best = candidates.first else {
            // 无可用账号，发通知提醒用户
            sendNotification(title: L.autoSwitchTitle, body: L.autoSwitchNoCandidates)
            return
        }

        do {
            try store.activate(best)
            sendAutoSwitchNotification(from: active, to: best)
        } catch {
            // 静默失败，等下次扫描再试
        }
    }

    private func sendAutoSwitchNotification(from old: TokenAccount, to new: TokenAccount) {
        sendNotification(
            title: L.autoSwitchTitle,
            body: L.autoSwitchBody(old.organizationName ?? old.email, new.organizationName ?? new.email)
        )
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "codexbar-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private func forceQuitCodex(_ running: [NSRunningApplication], reopen: Bool) {
        let ws = NSWorkspace.shared

        if reopen {
            guard let url = ws.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
                running.forEach { $0.forceTerminate() }
                return
            }
            let observerBox = ObserverBox()
            observerBox.token = ws.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == "com.openai.codex" else { return }
                if let token = observerBox.token {
                    ws.notificationCenter.removeObserver(token)
                    observerBox.token = nil
                }
                ws.open(url)
            }
        }

        running.forEach { $0.forceTerminate() }
    }

    private func refresh() async {
        isRefreshing = true
        await WhamService.shared.refreshAll(store: store)
        isRefreshing = false
    }

    private func refreshAccount(_ account: TokenAccount) async {
        refreshingAccounts.insert(account.id)
        await WhamService.shared.refreshOne(account: account, store: store)
        refreshingAccounts.remove(account.id)
    }

    private func reauthAccount(_ account: TokenAccount) {
        oauth.startOAuth { result in
            switch result {
            case .success(let tokens):
                var updated = AccountBuilder.build(from: tokens)
                // 若 account_id 匹配，覆盖原账号；否则按新账号添加
                if updated.accountId == account.accountId {
                    updated.isActive = account.isActive
                    updated.tokenExpired = false
                    updated.isSuspended = false
                }
                store.addOrUpdate(updated)
                Task { await WhamService.shared.refreshOne(account: updated, store: store) }
            case .failure(let error):
                showError = error.localizedDescription
            }
        }
    }
}

private struct MenuBarPreferredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MenuBarThreeAccountsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MenuBarAllAccountsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
