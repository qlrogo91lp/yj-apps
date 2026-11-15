import SwiftUI

struct RecentSessionRow: View {
    let record: SessionRecord
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.startedAt, format: .dateTime.month().day().weekday(.wide))
                if let place = record.placeName, !place.isEmpty { Text(place).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Text("\(SojuFormat.string(record.sojuEquivalent))잔").bold()
        }.padding(.vertical, 8)
    }
}

#Preview { RecentSessionRow(record: SessionRecord()) }
