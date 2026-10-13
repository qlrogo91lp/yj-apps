import SwiftData
import SwiftUI

/// 기록 탭 — 주 단위 섹션의 최신순 목록 (제품 스펙 03b). 집계도 차트도 두지 않는다.
/// 행을 탭하면 기록 상세 시트가 열린다.
struct RecordsView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @EnvironmentObject private var alerts: AppAlertCenter
    @StateObject private var viewModel = RecordsViewModel()
    @State private var pendingDelete: WorkoutRecord?
    @State private var selected: WorkoutRecord?

    private var displayInputs: [RecordDisplayInput] {
        records.map(RecordDisplayInput.init(record:))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("records_mode_picker", selection: $viewModel.mode) {
                    ForEach(RecordsViewModel.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                content
            }
            .background(HaruchiPalette.bg.ignoresSafeArea())
            .refreshable { await sync.sync() }
            .navigationTitle("tab_records")
            .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
            .confirmationDialog("records_delete_confirm",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible)
            {
                Button("btn_delete", role: .destructive) { confirmDelete() }
                Button("btn_cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text(pendingDelete?
                    .source == .manual ? LocalizedStringKey("records_delete_note_manual") : LocalizedStringKey("records_delete_note_health"))
            }
            .onAppear { viewModel.rebuild(from: records) }
            .onChange(of: displayInputs) { _, _ in viewModel.rebuild(from: records) }
            .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.rebuild(from: records) } }
            .recordDetailSheet(item: $selected) { viewModel.rebuild(from: records) }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.mode == .calendar {
            RecordsCalendarView(month: viewModel.calendarMonth, selectedDay: viewModel.calendarState.selectedDay,
                                canMoveNext: viewModel.canMoveNext,
                                onPrevious: { viewModel.moveMonth(by: -1, from: records) },
                                onNext: { viewModel.moveMonth(by: 1, from: records) },
                                onSelectDay: { day in
                                    if let record = viewModel.select(day: day, from: records) { selected = record }
                                },
                                onSelectRecord: { selected = $0 })
                .refreshable { await sync.sync() }
        } else if viewModel.sections.isEmpty {
            // ScrollView 로 감싸야 빈 상태에서도 당겨서 새로고침이 걸린다
            ScrollView {
                ContentUnavailableView("records_empty_title",
                                       systemImage: "list.bullet.rectangle",
                                       description: Text("records_empty_message"))
                    .foregroundStyle(HaruchiPalette.dim)
                    .containerRelativeFrame(.vertical)
            }
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            Button { selected = row.record } label: { RecordRow(row: row) }
                                .listRowBackground(HaruchiPalette.surface)
                                .swipeActions(edge: .trailing) {
                                    // role: .destructive 를 쓰지 않는다 — 확인 전에 행이 먼저 사라지는 애니메이션이 돈다
                                    Button("btn_delete") { pendingDelete = row.record }
                                        .tint(HaruchiPalette.hr)
                                }
                        }
                    } header: {
                        Text(section.title)
                            .foregroundStyle(HaruchiPalette.dim)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func confirmDelete() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        if !modelContext.deleteRecord(record) {
            alerts.report(.deleteFailed)
        }
    }
}
