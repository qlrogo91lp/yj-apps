import SwiftUI

/// 기록 목록의 한 행 — 날짜와 구간 칩, 부위, 우측 kcal. 문자열은 `RecordListRow` 가 다 만들어 온다.
struct RecordRow: View {
    let row: RecordListRow

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.dateTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HaruchiPalette.text)
                if !row.chips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(row.chips, id: \.self) { chip($0) }
                    }
                }
                if let parts = row.bodyPartsText {
                    Text(parts)
                        .font(.caption)
                        .foregroundStyle(HaruchiPalette.dim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let calories = row.caloriesText {
                Text(calories)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(HaruchiPalette.dim)
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ chip: RecordListRow.Chip) -> some View {
        let color = chip.kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio
        return Text(chip.text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
    }
}
