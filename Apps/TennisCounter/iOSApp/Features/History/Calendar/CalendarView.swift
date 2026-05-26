import SwiftUI

struct CalendarView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    @State private var displayedMonth = Date()

    var body: some View {
        VStack(spacing: 0) {
            MonthHeader(
                displayedMonth: displayedMonth,
                onPrevious: { changeMonth(by: -1) },
                onNext: { changeMonth(by: 1) }
            )

            WeekdayLabels()

            CalendarGrid(matches: matches, displayedMonth: displayedMonth, selectedMatch: $selectedMatch)
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
