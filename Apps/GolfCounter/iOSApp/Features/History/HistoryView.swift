import SwiftData
import SwiftUI

/// 기록 탭. 최신순 전체 로드 — 골프는 연 수십 라운드 규모라 페이징을 두지 않는다 (spec §4).
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @State private var pendingDeletion: GolfRound?

    var body: some View {
        NavigationStack {
            Group {
                if rounds.isEmpty {
                    EmptyRounds()
                } else {
                    List {
                        ForEach(rounds) { round in
                            NavigationLink {
                                RoundDetailView(round: round)
                            } label: {
                                RoundCard(round: round)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = round
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .confirmationDialog("이 라운드를 삭제할까요?",
                                isPresented: deletionDialogBinding,
                                titleVisibility: .visible,
                                presenting: pendingDeletion)
            { round in
                Button("삭제", role: .destructive) { delete(round) }
                Button("취소", role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    /// 되돌릴 수 없는 동작이라 확인 단계를 생략하지 않는다 (spec §4).
    private var deletionDialogBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { pendingDeletion = nil }
                })
    }

    private func delete(_ round: GolfRound) {
        modelContext.delete(round)
        try? modelContext.save()
        pendingDeletion = nil
    }
}
