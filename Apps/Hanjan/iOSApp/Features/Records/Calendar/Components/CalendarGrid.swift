import SwiftUI

/// 요일 머리 + 한 달 날짜 칸. Ralli `History/Calendar/Components/CalendarGrid` · `DayCell` 을 복사해 고쳤다.
/// 마신 날은 앰버 점, 한도를 넘긴 날은 빨간 점. 날짜만 고르고, 상세는 아래 요약 카드에서 연다.
struct CalendarGrid: View {
    let month: Date
    let calendar: Calendar
    let marks: [Date: CalendarMarks.Mark]
    let selectedDate: Date?
    let onSelect: (Date) -> Void

    private var weekdayLabels: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(days().enumerated()), id: \.offset) { _, date in
                    if let date {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private func cell(_ date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let mark = marks[calendar.startOfDay(for: date)] ?? CalendarMarks.Mark.none
        return VStack(spacing: 3) {
            Text(verbatim: "\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .frame(width: 34, height: 34)
                // 오늘과 선택은 겹칠 수 있어 채움과 테두리로 나눈다
                .background(Circle().fill(isSelected ? BrandColor.amber : Color.clear))
                .overlay(Circle().strokeBorder(isToday && !isSelected ? BrandColor.amber : Color.clear, lineWidth: 1.5))
            Circle()
                .fill(dotColor(mark))
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(date) }
    }

    private func dotColor(_ mark: CalendarMarks.Mark) -> Color {
        switch mark {
        case .none: .clear
        case .drank: BrandColor.amber
        case .exceeded: BrandColor.danger
        }
    }

    /// 첫 주 앞의 빈칸은 nil. 주 시작 요일은 `calendar.firstWeekday` 를 따른다.
    private func days() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: interval.start) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return days
    }
}

#Preview {
    let calendar = RecordFormat.calendar
    let today = calendar.startOfDay(for: .now)
    let marks: [Date: CalendarMarks.Mark] = [
        calendar.date(byAdding: .day, value: -2, to: today) ?? today: .drank,
        calendar.date(byAdding: .day, value: -5, to: today) ?? today: .exceeded,
    ]
    return CalendarGrid(month: today, calendar: calendar, marks: marks, selectedDate: today) { _ in }
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
