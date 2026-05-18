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
            let projects = ProjectsReader.aggregate(projectsDir: projectsURL)
            if projects.activeBlockTokens > 0 {
                snap.activeBlockTokens = projects.activeBlockTokens
                snap.activeBlockStartedAt = projects.activeBlockStartedAt
                if let start = projects.activeBlockStartedAt {
                    snap.activeBlockEndsAt = start.addingTimeInterval(5 * 3600)
                }
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
