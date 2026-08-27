import SwiftUI

struct CalendarView: View {
    let matches: [Match]
    let currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Binding var selectedMatch: Match?

    var body: some View {
        VStack(spacing: 0) {
            MonthHeader(
                displayedMonth: currentMonth,
                onPrevious: onPrevious,
                onNext: onNext
            )
            WeekdayLabels()
            CalendarGrid(
                matches: matches,
                displayedMonth: currentMonth,
                selectedMatch: $selectedMatch
            )
        }
    }
}
