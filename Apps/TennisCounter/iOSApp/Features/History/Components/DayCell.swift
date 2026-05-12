import SwiftUI

struct DayCell: View {
    let date: Date
    let matches: [Match]
    let onTap: () -> Void

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var hasMatch: Bool { !matches.isEmpty }
    private var hasWin: Bool { matches.contains { $0.myTotalSets > $0.yourTotalSets } }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .blue : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(Circle())

            if hasMatch {
                Circle()
                    .fill(hasWin ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            } else {
                Color.clear.frame(width: 5, height: 5)
            }
        }
        .onTapGesture(perform: onTap)
    }
}
