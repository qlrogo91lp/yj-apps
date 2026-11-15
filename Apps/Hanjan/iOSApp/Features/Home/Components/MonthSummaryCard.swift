import SwiftUI

struct MonthSummaryCard: View {
    let summary: MonthSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 달").font(.headline)
            HStack {
                item("술자리", "\(summary.count)회")
                Spacer()
                item("소주 환산", "\(SojuFormat.string(summary.equivalent))잔")
                Spacer()
                item("한도 초과", "\(summary.exceededCount)회")
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func item(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) { Text(label).font(.caption).foregroundStyle(.secondary); Text(value).bold() }
    }
}

#Preview { MonthSummaryCard(summary: MonthSummary(count: 2, equivalent: 5, exceededCount: 1)) }
