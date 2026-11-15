import SwiftData
import SwiftUI

/// 기록 상세. 지도(좌표가 있을 때만), 소주 환산, 술별 잔 수, 짠만 횟수, 상태, 함께한 사람, 메모, 삭제.
struct RecordDetailView: View {
    let sessionId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [SessionRecord]
    @State private var isEditingEntries = false
    @State private var isEditingReview = false
    @State private var isConfirmingDelete = false

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _matches = Query(filter: #Predicate<SessionRecord> { $0.id == sessionId })
    }

    var body: some View {
        Group {
            if let session = matches.first {
                content(session)
            } else {
                Text("기록을 찾을 수 없어요")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BrandColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingEntries) {
            EntryEditView(sessionId: sessionId) { isEditingEntries = false }
        }
        .sheet(isPresented: $isEditingReview) {
            ReviewFormView(sessionId: sessionId) { isEditingReview = false }
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let session = matches.first {
                    try? RecordStore(context: modelContext).delete(session)
                }
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("iCloud 로 연결된 다른 기기에서도 지워지고 되돌릴 수 없어요.")
        }
    }

    private func content(_ session: SessionRecord) -> some View {
        let ledger = RecordStore.ledger(of: session)
        let isExceeded = session.limitLevel == .exceeded
        let companions = (session.companions ?? []).map(\.name)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(session)

                if let latitude = session.latitude, let longitude = session.longitude {
                    SessionMap(latitude: latitude, longitude: longitude, placeName: session.placeName)
                }

                card {
                    VStack(alignment: .leading, spacing: 12) {
                        row("장소", session.placeName?.isEmpty == false ? session.placeName : nil)
                        equivalentRow(ledger.sojuEquivalent(), limit: session.limit, isExceeded: isExceeded)
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 10) {
                        KindCountList(counts: ledger.countsByKind()) { isEditingEntries = true }
                        if session.toastOnlyCount > 0 {
                            Text("짠만 \(session.toastOnlyCount)번")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 12) {
                        row("함께한 사람", companions.isEmpty ? nil : companions.joined(separator: ", "))
                        row("어땠나요?", ReviewCondition.label(session.condition))
                        if let memo = session.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.system(size: 15))
                        }
                    }
                }

                CapsuleButton(title: session.condition == nil && session.memo == nil ? "회고 남기기" : "회고 고치기") {
                    isEditingReview = true
                }
                CapsuleButton(title: "기록 삭제", style: .danger) {
                    isConfirmingDelete = true
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private func header(_ session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(RecordFormat.day(session.startedAt))
                .font(.system(size: 24, weight: .bold))
            Text(RecordFormat.timeRange(session.startedAt, session.endedAt))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func equivalentRow(_ equivalent: Double, limit: Double, isExceeded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("소주 환산")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(RecordFormat.glasses(equivalent))
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                    .foregroundStyle(isExceeded ? BrandColor.danger : BrandColor.amber)
                Text("한도 \(SojuFormat.string(limit))잔")
                    .font(.system(size: 14))
                    .foregroundStyle(isExceeded ? BrandColor.danger : .secondary)
            }
        }
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value ?? "없음")
                .font(.system(size: 16))
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
}

#Preview {
    let container = RecordsPreviewData.container()
    return NavigationStack {
        RecordDetailView(sessionId: RecordsPreviewData.firstSessionId(in: container))
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
