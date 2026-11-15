import SwiftUI

/// 기록 목록 한 줄. "11월 7일 토요일 / 성수동 · 지민, 민수 ··· 5잔 ›"
struct RecordRow: View {
    let session: SessionRecord

    private var isExceeded: Bool {
        session.limitLevel == .exceeded
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(RecordFormat.day(session.startedAt))
                    .font(.system(size: 16, weight: .semibold))
                if let subtitle = RecordFormat.subtitle(
                    placeName: session.placeName,
                    companions: (session.companions ?? []).map(\.name)
                ) {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(RecordFormat.glasses(session.sojuEquivalent))
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundStyle(isExceeded ? BrandColor.danger : BrandColor.amber)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let record = SessionRecord(startedAt: .now.addingTimeInterval(-86400), endedAt: .now.addingTimeInterval(-80000))
    record.totalGrams = DrinkPresets.soju.alcoholGrams * 5
    record.placeName = "성수동"
    return RecordRow(session: record)
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
