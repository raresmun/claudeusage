import Foundation
import Darwin

/// The actual user home directory, even when the app is running inside a sandbox
/// container. `NSHomeDirectory()` returns the container path (`~/Library/Containers/.../Data`)
/// for sandboxed apps; this resolves the real `/Users/<user>` so the temporary-exception
/// entitlement for `~/.claude/` can actually find the file.
enum RealHome {
    static var url: URL {
        if let pw = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }
}

struct UsageSnapshot: Equatable {
    struct ServerLimit: Equatable {
        var usedPercent: Double
        var resetsAt: Date
    }

    struct TokenBreakdown: Equatable {
        var input: UInt64 = 0
        var output: UInt64 = 0
        var cacheRead: UInt64 = 0
        var cacheCreate: UInt64 = 0
        var total: UInt64 { input &+ output &+ cacheRead &+ cacheCreate }
    }

    // From ~/.claude/statusline.jsonl
    var fiveHour: ServerLimit?
    var weekly: ServerLimit?
    var sessionCostUSD: Double?
    var model: String?
    var statuslineAt: Date?

    // From ~/.claude/projects/**/*.jsonl
    var activeBlockTokens: UInt64?
    var activeBlockStartedAt: Date?
    var activeBlockEndsAt: Date?
    var today: TokenBreakdown?
    var todayMessages: Int?

    var worstPercent: Double? {
        [fiveHour?.usedPercent, weekly?.usedPercent].compactMap { $0 }.max()
    }
}

enum ISODate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        withFraction.date(from: s) ?? plain.date(from: s)
    }
}
