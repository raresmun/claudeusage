import Foundation

enum StatuslineReader {
    /// Read the last valid JSON line from the statusline snapshot file by seeking
    /// to the tail of the file. Returns nil if the file does not exist, is empty,
    /// or contains no parseable line in the tail window.
    static func readLatest(at url: URL) -> UsageSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else { return nil }
        let tailSize: UInt64 = 16 * 1024
        let offset = size > tailSize ? size - tailSize : 0
        do {
            try handle.seek(toOffset: offset)
        } catch {
            return nil
        }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        for lineData in lines.reversed() {
            if let snapshot = parse(line: Data(lineData)) {
                return snapshot
            }
        }
        return nil
    }

    private static func parse(line: Data) -> UsageSnapshot? {
        guard let raw = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            return nil
        }
        var snap = UsageSnapshot()

        // Model: prefer `model.display_name`, fall back to bare `model` string.
        if let m = raw["model"] as? [String: Any], let name = m["display_name"] as? String {
            snap.model = name
        } else if let m = raw["model"] as? String {
            snap.model = m
        }

        // Cost: `cost.total_cost_usd` or legacy top-level `cost_usd`.
        if let cost = raw["cost"] as? [String: Any], let v = number(cost["total_cost_usd"]) {
            snap.sessionCostUSD = v
        } else {
            snap.sessionCostUSD = number(raw["cost_usd"])
        }

        // Timestamp: rarely present in Claude Code's input; fall back to "now".
        if let ts = raw["timestamp"] as? String, let d = parseDate(ts) {
            snap.statuslineAt = d
        } else if let ts = number(raw["timestamp"]) {
            snap.statuslineAt = Date(timeIntervalSince1970: ts)
        }

        // Rate limits: Claude Code uses `rate_limits` (plural); brief used `rate_limit`.
        let rl = (raw["rate_limits"] as? [String: Any]) ?? (raw["rate_limit"] as? [String: Any])
        if let rl {
            snap.fiveHour = parseLimit(rl["five_hour"])
            // Claude Code uses `seven_day` for the rolling weekly limit; brief used `weekly`.
            snap.weekly = parseLimit(rl["seven_day"]) ?? parseLimit(rl["weekly"])
        }

        let hasUsefulField = snap.fiveHour != nil || snap.weekly != nil ||
                             snap.sessionCostUSD != nil || snap.model != nil
        return hasUsefulField ? snap : nil
    }

    private static func parseLimit(_ raw: Any?) -> UsageSnapshot.ServerLimit? {
        guard let dict = raw as? [String: Any] else { return nil }
        let pct = number(dict["used_percentage"]) ?? number(dict["used_pct"])
        let resets = parseDate(dict["resets_at"])
        guard let pct, let resets else { return nil }
        return UsageSnapshot.ServerLimit(usedPercent: pct, resetsAt: resets)
    }

    /// Parse a date that may be an ISO 8601 string, a unix-timestamp number,
    /// or a numeric string.
    private static func parseDate(_ v: Any?) -> Date? {
        if let s = v as? String {
            if let d = ISODate.parse(s) { return d }
            if let n = Double(s) { return Date(timeIntervalSince1970: n) }
            return nil
        }
        if let n = number(v) {
            return Date(timeIntervalSince1970: n)
        }
        return nil
    }

    private static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }
}
