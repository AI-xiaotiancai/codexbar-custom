import Combine
import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TokenStore
    @EnvironmentObject private var oauth: OAuthManager
    @EnvironmentObject private var settings: AppSettings

    @State private var now = Date()
    @State private var isRefreshing = false
    @State private var refreshingAccounts: Set<String> = []
    @State private var notice: String?
    @State private var errorText: String?

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var groupedAccounts: [(email: String, accounts: [TokenAccount])] {
        var groups: [String: [TokenAccount]] = [:]
        var order: [String] = []
        for account in store.accounts {
            if groups[account.email] == nil {
                groups[account.email] = []
                order.append(account.email)
            }
            groups[account.email, default: []].append(account)
        }

        let sortedOrder = order.sorted { lhs, rhs in
            let leftRank = groups[lhs, default: []].map(\.displaySortRank).min() ?? 3
            let rightRank = groups[rhs, default: []].map(\.displaySortRank).min() ?? 3
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs < rhs
        }

        return sortedOrder.map { email in
            let sorted = groups[email, default: []].sorted { lhs, rhs in
                if lhs.displaySortRank != rhs.displaySortRank { return lhs.displaySortRank < rhs.displaySortRank }
                if lhs.primaryRemainingPercent != rhs.primaryRemainingPercent { return lhs.primaryRemainingPercent > rhs.primaryRemainingPercent }
                if lhs.secondaryRemainingPercent != rhs.secondaryRemainingPercent { return lhs.secondaryRemainingPercent > rhs.secondaryRemainingPercent }
                return lhs.accountId < rhs.accountId
            }
            return (email, sorted)
        }
    }

    private var activeAccountName: String {
        guard let active = store.activeAccount() else { return L.noActiveAccount }
        if let org = active.organizationName, !org.isEmpty { return org }
        return active.email
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                settingsSection
                accountsSection
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 520)
        .onReceive(timer) { _ in now = Date() }
        .onAppear {
            MenuBarStatusController.shared.restoreIfNeededFromMainWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            MenuBarStatusController.shared.restoreIfNeededFromMainWindow()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CodexAppBar")
                .font(.system(size: 28, weight: .bold))

            Text(L.windowHint)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                summaryCard(title: L.accountOverview, value: "\(store.accounts.count)", detail: store.accounts.isEmpty ? L.noAccounts : L.manageAccounts)
                summaryCard(title: L.activeAccountLabel, value: activeAccountName, detail: activeDetailText)
                summaryCard(title: L.dockIconSetting, value: settings.showDockIcon ? L.dockIconVisible : L.dockIconHidden, detail: "CodexAppBar")
            }

            HStack(spacing: 10) {
                Button(L.addAccount) {
                    oauth.startOAuth { result in
                        switch result {
                        case .success(let tokens):
                            let account = AccountBuilder.build(from: tokens)
                            store.addOrUpdate(account)
                            notice = nil
                            Task { await refreshAccount(account) }
                        case .failure(let error):
                            errorText = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(L.refreshAll) {
                    Task { await refreshAll() }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)

                Button(L.restoreMenuBarIcon) {
                    MenuBarStatusController.shared.restoreStatusItem(forceRebuild: true)
                    notice = L.restoreMenuBarIcon
                    errorText = nil
                }
                .buttonStyle(.bordered)

                Button {
                    switch L.languageOverride {
                    case nil: L.languageOverride = true
                    case true: L.languageOverride = false
                    case false: L.languageOverride = nil
                    }
                } label: {
                    Text("Language: \(languageLabel)")
                }
                .buttonStyle(.bordered)
            }

            if let notice {
                Text(notice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.dockIconSetting)
                .font(.system(size: 18, weight: .semibold))

            Toggle(isOn: Binding(
                get: { settings.showDockIcon },
                set: { newValue in
                    settings.showDockIcon = newValue
                    notice = L.settingsSaved
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.showDockIcon ? L.dockIconVisible : L.dockIconHidden)
                        .font(.system(size: 14, weight: .medium))
                    Text(L.dockIconHint)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Button(L.restoreMenuBarIcon) {
                MenuBarStatusController.shared.restoreStatusItem(forceRebuild: true)
                notice = L.restoreMenuBarIcon
                errorText = nil
            }
            .buttonStyle(.bordered)

            Text(L.restoreMenuBarHint)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.accountOverview)
                .font(.system(size: 18, weight: .semibold))

            if store.accounts.isEmpty {
                Text(L.addAccountHint)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 18)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groupedAccounts, id: \.email) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.email)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            ForEach(group.accounts) { account in
                                AccountRowView(
                                    account: account,
                                    isActive: account.isActive,
                                    now: now,
                                    isRefreshing: refreshingAccounts.contains(account.id)
                                ) {
                                    activate(account)
                                } onRefresh: {
                                    Task { await refreshAccount(account) }
                                } onReauth: {
                                    reauth(account)
                                } onDelete: {
                                    store.remove(account)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var activeDetailText: String {
        guard let active = store.activeAccount() else { return L.noActiveAccount }
        return "\(Int(active.primaryRemainingPercent))% · \(Int(active.secondaryRemainingPercent))%"
    }

    private var languageLabel: String {
        switch L.languageOverride {
        case nil: return "AUTO"
        case true: return "中"
        case false: return "EN"
        }
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }

    private func refreshAll() async {
        isRefreshing = true
        await WhamService.shared.refreshAll(store: store)
        isRefreshing = false
        notice = L.refreshAll
        errorText = nil
    }

    private func refreshAccount(_ account: TokenAccount) async {
        refreshingAccounts.insert(account.id)
        await WhamService.shared.refreshOne(account: account, store: store)
        refreshingAccounts.remove(account.id)
        errorText = nil
    }

    private func activate(_ account: TokenAccount) {
        do {
            try store.activate(account)
            notice = L.switchAccount
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func reauth(_ account: TokenAccount) {
        oauth.startOAuth { result in
            switch result {
            case .success(let tokens):
                var updated = AccountBuilder.build(from: tokens)
                if updated.accountId == account.accountId {
                    updated.isActive = account.isActive
                    updated.tokenExpired = false
                    updated.isSuspended = false
                }
                store.addOrUpdate(updated)
                Task { await refreshAccount(updated) }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TokenStore.shared)
        .environmentObject(OAuthManager.shared)
        .environmentObject(AppSettings.shared)
}
