import SwiftData
import SwiftUI

/// 선택한 연도의 누적·습관·구성을 보여 주는 통계 탭.
@MainActor
struct StatisticsView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @StateObject private var statistics = StatisticsViewModel()

    private var inputs: [StatisticsRecordInput] {
        records.map(StatisticsRecordInput.init(record:))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StatisticsYearPicker(years: statistics.dashboard.availableYears,
                                         selectedYear: statistics.dashboard.year)
                    {
                        statistics.select(year: $0, from: records)
                    }
                    AnnualGrass(dashboard: statistics.dashboard)
                    AnnualSummary(dashboard: statistics.dashboard)
                    if let message = statistics.dashboard.emptyMessage {
                        ContentUnavailableView(message, systemImage: "chart.bar.fill",
                                               description: Text("워치에서 운동을 기록하면 한 해의 흐름을 볼 수 있어요."))
                            .foregroundStyle(HaruchiPalette.dim)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        StatisticsFrequencyChart(title: "월별 운동", values: statistics.dashboard.months)
                        AnnualComposition(composition: statistics.dashboard.composition)
                        StatisticsFrequencyChart(title: "요일 패턴", values: statistics.dashboard.weekdays)
                        if !statistics.dashboard.bodyParts.isEmpty {
                            BodyPartFrequencyChart(values: statistics.dashboard.bodyParts)
                        }
                        AnnualMilestones(values: statistics.dashboard.displayedMilestones)
                    }
                }
                .padding(.vertical)
            }
            .background(HaruchiPalette.bg.ignoresSafeArea())
            .refreshable { await sync.sync() }
            .navigationTitle("통계")
            .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
            .onAppear { statistics.rebuild(from: records) }
            .onChange(of: inputs) { _, _ in statistics.rebuild(from: records) }
            .onChange(of: scenePhase) { _, phase in if phase == .active { statistics.rebuild(from: records) } }
        }
    }
}
