import SwiftUI

/// 최근 기록 2개 — 헤더 우측 `전체 보기 ›` 는 기록 탭으로 간다. 값과 콜백만 받는다.
struct RecentRecordsSection: View {
    let rows: [RecordListRow]
    let onSelect: (WorkoutRecord) -> Void
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 기록").font(.subheadline.weight(.semibold)).foregroundStyle(HaruchiPalette.text)
                Spacer()
                if !rows.isEmpty {
                    Button("전체 보기 ›", action: onShowAll)
                        .font(.footnote)
                        .foregroundStyle(HaruchiPalette.dim)
                }
            }
            if rows.isEmpty {
                Text("아직 기록이 없어요")
                    .font(.footnote)
                    .foregroundStyle(HaruchiPalette.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { onSelect(row.record) } label: { RecordRow(row: row) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        if row.id != rows.last?.id { Divider().overlay(HaruchiPalette.line) }
                    }
                }
                .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
