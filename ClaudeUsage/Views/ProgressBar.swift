import SwiftUI

struct ProgressBar: View {
    let value: Double   // 0...100
    var color: Color = .green

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(value, 100) / 100))
            }
        }
        .frame(height: 5)
    }
}
