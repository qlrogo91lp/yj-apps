import SwiftData
import SwiftUI

/// 기록 탭 — 주 단위 섹션의 최신순 목록 (제품 스펙 03b). 집계도 차트도 두지 않는다.
/// 행 탭 → 기록 상세는 Phase 3 #5 가 붙인다.
struct RecordsView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @EnvironmentObject private var alerts: AppAlertCenter
    @StateObject private var viewModel = RecordsViewModel()
    @State private var pendingDelete: WorkoutRecord?

    var body: some View {
        NavigationStack {
            content
                .background(HaruchiPalette.bg.ignoresSafeArea())
                .refreshable { await sync.sync() }
                .navigationTitle("기록")
                .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
                .confirmationDialog("이 기록을 삭제할까요?",
                                    isPresented: Binding(get: { pendingDelete != nil },
                                                         set: { if !$0 { pendingDelete = nil } }),
                                    titleVisibility: .visible)
                {
                    Button("삭제", role: .destructive) { confirmDelete() }
                    Button("취소", role: .cancel) { pendingDelete = nil }
                } message: {
                    Text("건강 앱의 운동 기록은 그대로 남아요.")
                }
                .onAppear { viewModel.rebuild(from: records) }
                .onChange(of: records) { _, updated in viewModel.rebuild(from: updated) }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.sections.isEmpty {
            // ScrollView 로 감싸야 빈 상태에서도 당겨서 새로고침이 걸린다
            ScrollView {
                ContentUnavailableView("아직 기록이 없어요",
                                       systemImage: "list.bullet.rectangle",
                                       description: Text("워치에서 운동을 저장하면 여기에 쌓여요."))
                    .foregroundStyle(HaruchiPalette.dim)
                    .containerRelativeFrame(.vertical)
            }
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            RecordRow(row: row)
                                .listRowBackground(HaruchiPalette.surface)
                                .swipeActions(edge: .trailing) {
                                    // role: .destructive 를 쓰지 않는다 — 확인 전에 행이 먼저 사라지는 애니메이션이 돈다
                                    Button("삭제") { pendingDelete = row.record }
                                        .tint(.red)
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
        if !viewModel.delete(record, in: modelContext) {
            alerts.report(.deleteFailed)
        }
    }
}
