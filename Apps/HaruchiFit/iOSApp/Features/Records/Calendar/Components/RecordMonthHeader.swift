import SwiftUI

struct RecordMonthHeader: View {
    let title: String
    let summary: String
    let canMoveNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                controls
                Spacer()
                Text(summary).foregroundStyle(HaruchiPalette.dim)
            }
            VStack(alignment: .leading, spacing: 8) {
                controls
                Text(summary).foregroundStyle(HaruchiPalette.dim)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            Button(action: onPrevious) { Image(systemName: "chevron.left") }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("이전 달")
            Text(title).font(.headline).foregroundStyle(HaruchiPalette.text)
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!canMoveNext)
                .accessibilityLabel("다음 달")
        }
    }
}
