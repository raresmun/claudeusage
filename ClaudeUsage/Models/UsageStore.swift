import Foundation
import SwiftUI
import AppKit

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private let refreshInterval: TimeInterval = 30

    private var statuslineURL: URL {
        RealHome.url.appendingPathComponent(".claude/statusline.jsonl")
    }
    private var projectsURL: URL {
        RealHome.url.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    init() {
        startTimer()
        observeSleepWake()
        Task { await refresh() }
    }

    func refresh() async {
        let statuslineURL = self.statuslineURL
        let projectsURL = self.projectsURL
        let result = await Task.detached(priority: .utility) {
            var snap = StatuslineReader.readLatest(at: statuslineURL) ?? UsageSnapshot()
            let now = Date()
            // Use server-side block boundary when available so the token count
            // matches Claude Code's fixed window (resetsAt - 5h) rather than
            // a rolling "last 5 hours" that over-counts from a previous block.
            let serverBlockStart: Date?
            if let resetsAt = snap.fiveHour?.resetsAt, resetsAt > now {
                serverBlockStart = resetsAt.addingTimeInterval(-5 * 3600)
            } else {
                serverBlockStart = nil
            }
            let projects = ProjectsReader.aggregate(projectsDir: projectsURL, now: now, serverBlockStart: serverBlockStart)
            if projects.activeBlockTokens > 0 {
                snap.activeBlockTokens = projects.activeBlockTokens
                snap.activeBlockStartedAt = projects.activeBlockStartedAt
                snap.activeBlockEndsAt = snap.fiveHour?.resetsAt
            }
            if projects.todayMessages > 0 {
                snap.today = projects.today
                snap.todayMessages = projects.todayMessages
            }
            return snap
        }.value

        self.snapshot = result
        self.lastUpdated = Date()
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopTimer() }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.startTimer()
                await self?.refresh()
            }
        }
    }
}
