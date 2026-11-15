import SwiftUI

struct LimitBar: View {
    let equivalent: Double
    let limit: Double
    let exceeded: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(exceeded ? BrandColor.danger : BrandColor.amber).frame(width: geometry.size.width * min(
                    1,
                    max(0, equivalent / max(1, limit))
                ))
            }
        }.frame(height: 6)
    }
}

#Preview { LimitBar(equivalent: 5, limit: 8, exceeded: false) }
