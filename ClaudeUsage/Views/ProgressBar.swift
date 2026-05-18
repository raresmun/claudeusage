import SwiftUI

struct ProgressBar: View {
    let value: Double  // 0...100
    var width: Int = 12

    var body: some View {
        let clamped = max(0, min(100, value))
        let filled = Int((clamped / 100.0 * Double(width)).rounded())
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
        Text(bar)
            .font(.system(size: 11, design: .monospaced))
    }
}
