import SwiftUI

/// 캘린더에서 고른 날의 술자리 요약 카드. "11월 7일 · 성수동 / 5잔 / 소주 환산 · 한도 이내 / 함께한 사람 · 지민, 민수"
struct DaySummaryCard: View {
    let session: SessionRecord

    private var isExceeded: Bool {
        session.limitLevel == .exceeded
    }

    private var title: String {
        let day = RecordFormat.shortDay(session.startedAt)
        guard let place = session.placeName, !place.isEmpty else { return day }
        return "\(day) · \(place)"
    }

    private var companions: [String] {
        (session.companions ?? []).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(RecordFormat.glasses(session.sojuEquivalent))
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(isExceeded ? BrandColor.danger : BrandColor.amber)
            Text(isExceeded ? "소주 환산 · 한도 초과" : "소주 환산 · 한도 이내")
                .font(.system(size: 13))
                .foregroundStyle(isExceeded ? BrandColor.danger : .secondary)
            if !companions.isEmpty {
                Text("함께한 사람 · \(companions.joined(separator: ", "))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let record = SessionRecord(startedAt: .now, endedAt: .now.addingTimeInterval(3600), limit: 8)
    record.totalGrams = DrinkPresets.soju.alcoholGrams * 9
    record.placeName = "성수동"
    return DaySummaryCard(session: record)
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
