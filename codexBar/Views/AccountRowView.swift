import SwiftUI

/// One org/account row under an email group
struct AccountRowView: View {
    let account: TokenAccount
    let isActive: Bool
    let now: Date
    let isRefreshing: Bool
    let onActivate: () -> Void
    let onRefresh: () -> Void
    let onReauth: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: org name + plan badge + active mark + switch button
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)

                if let displayName {
                    Text(displayName)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .accentColor : .primary)
                        .lineLimit(1)
                }

                Text(account.planType.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(planBadgeColor.opacity(0.15))
                    .foregroundColor(planBadgeColor)
                    .cornerRadius(3)

                if let subscriptionExpiryText = account.subscriptionExpiryText {
                    Text("\(L.subscriptionExpiryLabel) \(subscriptionExpiryText)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(subscriptionExpiryColor)
                        .lineLimit(1)
                }

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                }

                Spacer()

                // 删除按钮（NSAlert 二次确认）
                Button {
                    let alert = NSAlert()
                    alert.messageText = L.confirmDelete(deleteTargetName)
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L.delete)
                    alert.addButton(withTitle: L.cancel)
                    if alert.runModal() == .alertFirstButtonReturn {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                if account.tokenExpired {
                    Button(L.reauth, action: onReauth)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .font(.system(size: 10, weight: .medium))
                        .tint(.orange)
                } else if !account.isBanned {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .disabled(isRefreshing)

                    if !isActive {
                        Button(L.switchBtn, action: onActivate)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }

            // Line 2: usage info
            if account.tokenExpired {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(L.tokenExpiredHint)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Spacer()
                }
            } else if account.isBanned {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(L.accountSuspended)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Spacer()
                }
            } else if account.showsPrimaryQuota {
                if account.quotaExhausted {
                    if account.primaryExhausted && !account.secondaryExhausted {
                        HStack(spacing: 8) {
                            primaryQuotaCard(remainingPercent: 0, resetStatusText: account.primaryResetStatusText)
                            weeklyQuotaCard
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            let label = account.secondaryExhausted ? L.weeklyExhausted : L.primaryExhausted
                            let resetDesc = account.secondaryExhausted ? account.secondaryResetDescription : account.primaryResetDescription
                            Text(resetDesc.isEmpty ? label : "\(label) · \(resetDesc)")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        primaryQuotaCard(remainingPercent: account.primaryRemainingPercent, resetStatusText: account.primaryResetStatusText)
                        weeklyQuotaCard
                    }
                }
            } else {
                weeklyQuotaCard
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 16)   // indent under email header
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isActive {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
    }

    private var displayName: String? {
        guard let org = account.organizationName, !org.isEmpty else { return nil }
        return org
    }

    private var deleteTargetName: String {
        displayName ?? account.email
    }

    private var subscriptionExpiryColor: Color {
        let daysRemaining = account.subscriptionExpiryDaysRemaining ?? .max
        if daysRemaining <= 3 { return .red }
        if daysRemaining <= 7 { return .orange }
        return .secondary
    }

    private func primaryQuotaCard(remainingPercent: Double, resetStatusText: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Text("5h 剩余")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(remainingPercent))%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(usageColor(remainingPercent))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: remainingPercent)
            }
            ProgressView(value: min(remainingPercent / 100, 1.0))
                .tint(usageColor(remainingPercent))
                .scaleEffect(x: 1, y: 0.7)
                .animation(.easeInOut(duration: 0.4), value: remainingPercent)

            Text(resetStatusText)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyQuotaCard: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Text("7d 剩余")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(account.effectiveWeeklyRemainingPercent))%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(usageColor(account.effectiveWeeklyRemainingPercent))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: account.effectiveWeeklyRemainingPercent)
            }
            ProgressView(value: min(account.effectiveWeeklyRemainingPercent / 100, 1.0))
                .tint(usageColor(account.effectiveWeeklyRemainingPercent))
                .scaleEffect(x: 1, y: 0.7)
                .animation(.easeInOut(duration: 0.4), value: account.effectiveWeeklyRemainingPercent)

            Text(account.effectiveWeeklyResetStatusText)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        if account.isBanned { return .red }
        if account.quotaExhausted { return .orange }
        if account.hasUsageWarning { return .yellow }
        return .green
    }

    private var planBadgeColor: Color {
        switch account.planType.lowercased() {
        case "team": return .blue
        case "plus": return .purple
        default: return .gray
        }
    }

    private func usageColor(_ remainingPercent: Double) -> Color {
        if remainingPercent <= 10 { return .red }
        if remainingPercent <= 30 { return .orange }
        return .green
    }
}
