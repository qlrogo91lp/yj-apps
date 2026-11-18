import SwiftUI

struct CountDisplay: View {
    let equivalent: Double
    let limit: Double
    let exceeded: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(SojuFormat.string(equivalent)).font(.system(size: 48, weight: .bold))
                .foregroundStyle(exceeded ? BrandColor.danger : .primary)
            Text("/ \(SojuFormat.string(limit))잔").font(.caption).foregroundStyle(.secondary)
        }.minimumScaleFactor(0.6).lineLimit(1)
    }
}
