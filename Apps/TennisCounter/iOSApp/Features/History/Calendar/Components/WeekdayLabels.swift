import SwiftUI

struct WeekdayLabels: View {
    private var labels: [String] {
        Calendar.current.shortWeekdaySymbols
    }

    var body: some View {
        HStack {
            ForEach(labels, id: \.self) { day in
                Text(day)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}
