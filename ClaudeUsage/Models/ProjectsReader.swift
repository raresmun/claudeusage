import Foundation

enum ProjectsReader {
    struct Result {
        var activeBlockTokens: UInt64 = 0
        var activeBlockStartedAt: Date?
        var today: UsageSnapshot.TokenBreakdown = .init()
        var todayMessages: Int = 0
    }

    /// Walk session JSONL files and aggregate per-window totals.
    /// Files older than the widest window of interest are skipped via mtime.
    static func aggregate(projectsDir: URL, now: Date = Date(), blockHours: Int = 5) -> Result {
        var result = Result()
        let blockStart = now.addingTimeInterval(-Double(blockHours) * 3600)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        // Pad cutoff by an hour to absorb clock skew and late-flushed lines.
        let mtimeCutoff = min(blockStart, todayStart).addingTimeInterval(-3600)

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            guard let mtime = values?.contentModificationDate, mtime >= mtimeCutoff else { continue }
            scan(file: url, blockStart: blockStart, todayStart: todayStart, into: &result)
        }
        return result
    }

    private static func scan(file: URL, blockStart: Date, todayStart: Date, into result: inout Result) {
        guard let stream = InputStream(url: file) else { return }
        stream.open()
        defer { stream.close() }

        var buffer = Data()
        let chunkSize = 64 * 1024
        var raw = [UInt8](repeating: 0, count: chunkSize)

        while stream.hasBytesAvailable {
            let read = stream.read(&raw, maxLength: chunkSize)
            if read <= 0 { break }
            buffer.append(raw, count: read)

            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: 0..<nl)
                buffer.removeSubrange(0...nl)
                processLine(line, blockStart: blockStart, todayStart: todayStart, into: &result)
            }
        }
        if !buffer.isEmpty {
            processLine(buffer, blockStart: blockStart, todayStart: todayStart, into: &result)
        }
    }

    private static func processLine(_ data: Data, blockStart: Date, todayStart: Date, into result: inout Result) {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tsStr = obj["timestamp"] as? String,
              let ts = ISODate.parse(tsStr) else {
            return
        }

        guard let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return
        }

        let input = uintField(usage["input_tokens"])
        let output = uintField(usage["output_tokens"])
        let cacheRead = uintField(usage["cache_read_input_tokens"])
        let cacheCreate = uintField(usage["cache_creation_input_tokens"])
        let total = input &+ output &+ cacheRead &+ cacheCreate

        if ts >= blockStart {
            result.activeBlockTokens &+= total
            if let existing = result.activeBlockStartedAt {
                if ts < existing { result.activeBlockStartedAt = ts }
            } else {
                result.activeBlockStartedAt = ts
            }
        }

        if ts >= todayStart {
            result.today.input &+= input
            result.today.output &+= output
            result.today.cacheRead &+= cacheRead
            result.today.cacheCreate &+= cacheCreate
            result.todayMessages &+= 1
        }
    }

    private static func uintField(_ v: Any?) -> UInt64 {
        if let n = v as? NSNumber { return n.uint64Value }
        if let d = v as? Double { return UInt64(max(0, d)) }
        if let i = v as? Int { return i > 0 ? UInt64(i) : 0 }
        return 0
    }
}
