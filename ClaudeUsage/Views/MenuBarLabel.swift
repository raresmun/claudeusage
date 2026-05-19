import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .monospacedDigit()
        }
        .foregroundColor(color)
    }

    private var text: String {
        var segments: [String] = []
        if let v = snapshot.fiveHour?.usedPercent {
            segments.append("5h \(Int(v.rounded()))%")
        }
        if let v = snapshot.weekly?.usedPercent {
            segments.append("wk \(Int(v.rounded()))%")
        }
        return segments.isEmpty ? "—" : segments.joined(separator: " · ")
    }

    private var color: Color {
        guard let worst = snapshot.worstPercent else { return .primary }
        return UsageColor.color(forPercent: worst)
    }
}

enum UsageColor {
    static func color(forPercent p: Double) -> Color {
        switch p {
        case ..<35:  return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        case ..<60:  return Color(red: 1.000, green: 0.800, blue: 0.000) // #FFCC00
        case ..<85:  return Color(red: 1.000, green: 0.584, blue: 0.000) // #FF9500
        default:     return Color(red: 1.000, green: 0.231, blue: 0.188) // #FF3B30
        }
    }
}
