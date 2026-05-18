import SwiftUI
import AppKit

struct DropdownView: View {
    @EnvironmentObject var store: UsageStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            serverSection
            Divider()
            activeBlockSection
            Divider()
            todaySection
            Divider()
            actionsSection
        }
        .padding(14)
        .frame(width: 290)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            Task { await store.refresh() }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Server limits")
            limitRow(label: "5-hour", limit: store.snapshot.fiveHour, daysExpected: false)
            limitRow(label: "Weekly", limit: store.snapshot.weekly, daysExpected: true)
            HStack {
                Text("Session cost").font(.system(size: 12))
                Spacer()
                Text(store.snapshot.sessionCostUSD.map { String(format: "$%.2f", $0) } ?? "—")
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
            if let model = store.snapshot.model {
                Text(model)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let at = store.snapshot.statuslineAt {
                Text("server data as of \(at.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func limitRow(label: String, limit: UsageSnapshot.ServerLimit?, daysExpected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 12))
                Spacer()
                Text(limit.map { "\(Int($0.usedPercent.rounded()))%" } ?? "—")
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
            ProgressBar(value: limit?.usedPercent ?? 0,
                        color: UsageColor.color(forPercent: limit?.usedPercent ?? 0))
            if let l = limit {
                Text("resets in \(formatRelative(to: l.resetsAt, allowDays: daysExpected))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activeBlockSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Active 5h block")
            HStack {
                Text("Tokens").font(.system(size: 12))
                Spacer()
                Text(store.snapshot.activeBlockTokens.map(formatTokens) ?? "—")
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionHeader("Today")
            HStack {
                Text("Total").font(.system(size: 12))
                Spacer()
                Text(store.snapshot.today.map { formatTokens($0.total) } ?? "—")
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
            if let t = store.snapshot.today {
                tokenRow("input", t.input)
                tokenRow("output", t.output)
                tokenRow("cache read", t.cacheRead)
                tokenRow("cache write", t.cacheCreate)
            }
            HStack {
                Text("Messages").font(.system(size: 12))
                Spacer()
                Text(store.snapshot.todayMessages.map(String.init) ?? "—")
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
        }
    }

    private func tokenRow(_ label: String, _ value: UInt64) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
            Spacer()
            Text(formatTokens(value))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        try LaunchAtLogin.set(newValue)
                        launchAtLogin = newValue
                    } catch {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            ))
            .font(.system(size: 12))
            .toggleStyle(.checkbox)

            Button("Open ~/.claude in Finder") {
                let url = RealHome.url.appendingPathComponent(".claude", isDirectory: true)
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

            Button("About ClaudeUsage") {
                AboutWindow.show()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
            .keyboardShortcut("q")
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.6)
    }
}

func formatTokens(_ n: UInt64) -> String {
    let d = Double(n)
    if d >= 1_000_000 {
        return String(format: "%.2fM", d / 1_000_000)
    } else if d >= 1_000 {
        return String(format: "%.1fk", d / 1_000)
    } else {
        return "\(n)"
    }
}

func formatRelative(to date: Date, allowDays: Bool) -> String {
    let seconds = max(0, Int(date.timeIntervalSinceNow))
    let totalMinutes = seconds / 60
    let hours = totalMinutes / 60
    let mins = totalMinutes % 60
    if allowDays && hours >= 24 {
        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
    }
    if hours == 0 {
        return "\(mins)m"
    }
    return "\(hours)h \(mins)m"
}
