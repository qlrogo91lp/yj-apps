import SwiftUI

/// 선택한 연도 전체를 날짜 누락 없이 그리는 잔디와 월 눈금.
struct AnnualGrass: View {
    let dashboard: StatisticsDashboard

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 16
    private let cellSpacing: CGFloat = 3

    private var columns: [[Date]] {
        stride(from: 0, to: dashboard.gridDays.count, by: 7).map {
            Array(dashboard.gridDays[$0 ..< min($0 + 7, dashboard.gridDays.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("연간 잔디")
                .font(.headline)
                .foregroundStyle(HaruchiPalette.text)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(columns.enumerated()), id: \.offset) { index, days in
                                VStack(spacing: cellSpacing) {
                                    ForEach(days, id: \.self) { day in
                                        cell(for: day)
                                    }
                                }
                                .id(index)
                            }
                        }

                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(columns.indices), id: \.self) { index in
                                monthLabel(for: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    proxy.scrollTo(dashboard.initialColumn,
                                   anchor: dashboard.isCurrentYear ? .trailing : .leading)
                }
            }
            .id(dashboard.year)

            legend
        }
    }

    private func cell(for day: Date) -> some View {
        let isInYear = calendar.component(.year, from: day) == dashboard.year
        let isFuture = dashboard.isCurrentYear && day > dashboard.today
        let level = dashboard.grassLevels[day] ?? .none
        return RoundedRectangle(cornerRadius: 3)
            .fill(isInYear ? HaruchiPalette.grass(level) : .clear)
            .frame(width: cellSize, height: cellSize)
            .opacity(isFuture ? 0.3 : 1)
            .overlay {
                if isInYear, day == dashboard.today {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(HaruchiPalette.text, lineWidth: 1.5)
                }
            }
            .accessibilityHidden(!isInYear || isFuture)
            .accessibilityLabel(accessibilityLabel(for: day, level: level))
    }

    private func monthLabel(for column: Int) -> some View {
        let month = dashboard.monthColumns.first { $0.value == column }?.key
        return Text(month.map { "\($0)월" } ?? "")
            .font(.caption2)
            .foregroundStyle(HaruchiPalette.dim)
            .frame(width: cellSize, alignment: .leading)
            .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("적음")
            ForEach([GrassLevel.light, .medium, .heavy, .peak], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(HaruchiPalette.grass(level))
                    .frame(width: 12, height: 12)
            }
            Text("많음")
        }
        .font(.caption)
        .foregroundStyle(HaruchiPalette.dim)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("운동량 적음에서 많음까지 네 단계")
    }

    private func accessibilityLabel(for day: Date, level: GrassLevel) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        let amount = switch level {
        case .none: "운동 없음"
        case .light: "운동량 적음"
        case .medium: "운동량 보통"
        case .heavy: "운동량 많음"
        case .peak: "운동량 매우 많음"
        }
        return "\(formatter.string(from: day)), \(amount)"
    }
}
