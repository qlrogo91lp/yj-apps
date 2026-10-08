import SwiftUI

/// 통계가 표시할 연도를 고르는 가로 선택기.
struct StatisticsYearPicker: View {
    let years: [Int]
    let selectedYear: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    Button { onSelect(year) } label: {
                        Text("\(year)")
                            .font(.headline)
                            .foregroundStyle(year == selectedYear ? HaruchiPalette.bg : HaruchiPalette.text)
                            .frame(minWidth: 58, minHeight: 44)
                            .background(year == selectedYear ? HaruchiPalette.accent : HaruchiPalette.surface2,
                                        in: Capsule())
                    }
                    .accessibilityAddTraits(year == selectedYear ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }
}
