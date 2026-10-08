import SwiftData
import SwiftUI

/// 홈 대시보드 (제품 스펙 02절) — 잔디 히어로 → 축적 스탯 → 이번 주 구성 → 최근 기록 2개.
struct HomeView: View {
    /// 전체 기록을 읽는다 — `전체 누적` 스탯이 필요하다. 잔디는 같은 결과에서 26주만 쓴다.
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @StateObject private var grass = GrassViewModel()
    @StateObject private var home = HomeViewModel()
    @State private var selected: WorkoutRecord?
    @State private var showingManualRecord = false

    let onShowAllRecords: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GrassHero(days: home.gridDays, level: { grass.level(on: $0) }, today: home.today)
                    VStack(spacing: 20) {
                        AccumulationStats(month: home.dashboard.monthStat, total: home.dashboard.totalStat)
                        WeekCompositionBar(week: home.dashboard.week,
                                           milestone: home.dashboard.milestone,
                                           emptyText: home.dashboard.emptyWeekText)
                        RecentRecordsSection(rows: home.recentRows,
                                             onSelect: { selected = $0 },
                                             onShowAll: onShowAllRecords)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(HaruchiPalette.bg.ignoresSafeArea())
            .refreshable { await sync.sync() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(home.dashboard.monthTitle).font(.headline).foregroundStyle(HaruchiPalette.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("수동 기록 추가", systemImage: "plus") { showingManualRecord = true }
                }
            }
            .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
            .onAppear(perform: rebuild)
            .onChange(of: records) { rebuild() }
            // 자정을 넘겨 앱에 돌아오면 `이번 주` · 오늘 칸을 다시 계산한다
            .onChange(of: scenePhase) { _, phase in if phase == .active { rebuild() } }
            .recordDetailSheet(item: $selected, onFinish: rebuild)
            .sheet(isPresented: $showingManualRecord) {
                ManualRecordView(onSaved: rebuild)
            }
        }
    }

    private func rebuild() {
        grass.rebuild(from: records)
        home.rebuild(from: records)
    }
}
