import SwiftUI

struct RecordDayCell: View {
    let day: RecordCalendarDay
    let isSelected: Bool
    let calendar: Calendar
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HaruchiPalette.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(HaruchiPalette.grass(day.level), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isSelected || calendar.isDateInToday(day.date) ? 2 : 0)
                }
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture)
        .opacity(day.isFuture ? 0.3 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var borderColor: Color {
        isSelected ? HaruchiPalette.text : HaruchiPalette.accent
    }

    private var accessibilityLabel: String {
        let formatter = RecordListBuilder.formatter("yyyy년 M월 d일", calendar: calendar, locale: Locale(identifier: "ko_KR"))
        let workout = day.sessionCount == 0 ? "운동 기록 없음" : "운동 \(day.sessionCount)회, \(day.totalSeconds / 60)분"
        let today = calendar.isDateInToday(day.date) ? ", 오늘" : ""
        let selected = isSelected ? ", 선택됨" : ""
        return "\(formatter.string(from: day.date)), \(workout)\(today)\(selected)"
    }
}
