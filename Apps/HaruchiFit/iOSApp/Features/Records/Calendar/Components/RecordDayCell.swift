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
        let formatter = DisplayDateFormat.formatter(.yearMonthDay, calendar: calendar, locale: .current)
        let workout = day.sessionCount == 0
            ? String(localized: "calendar_day_a11y_none")
            : String(localized: "calendar_day_a11y_workouts \(day.sessionCount) \(day.totalSeconds / 60)")
        var parts = [formatter.string(from: day.date), workout]
        if calendar.isDateInToday(day.date) { parts.append(String(localized: "calendar_day_a11y_today")) }
        if isSelected { parts.append(String(localized: "calendar_day_a11y_selected")) }
        return parts.joined(separator: ", ")
    }
}
