import SwiftUI
import AppKit

enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let w = NSWindow(contentViewController: hosting)
        w.title = "About ClaudeUsage"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 320, height: 220))
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("ClaudeUsage")
                .font(.title2.bold())
            Text("v\(version) (\(build))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Zero network. Sandboxed. MIT licensed.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
            if let url = URL(string: "https://github.com/raresmun/claudeusage") {
                Link("github.com/raresmun/claudeusage", destination: url)
                    .font(.system(size: 12))
            }
            Spacer()
            Text("© 2026 Stefan Muntenas")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 320, height: 220)
    }
}
