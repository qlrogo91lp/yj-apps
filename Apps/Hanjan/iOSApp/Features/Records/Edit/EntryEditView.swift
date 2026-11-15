import SwiftData
import SwiftUI

/// 기록 상세의 잔 수 편집. 술별 스테퍼로 고치고 `변경사항 저장` 에서 한 번에 반영한다.
struct EntryEditView: View {
    let sessionId: UUID
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [SessionRecord]
    @State private var kinds: [DrinkKind] = []
    @State private var draft: [UUID: Int] = [:]
    @State private var shownKindIds: [UUID] = []
    @State private var saveFailed = false

    init(sessionId: UUID, onDone: @escaping () -> Void) {
        self.sessionId = sessionId
        self.onDone = onDone
        _matches = Query(filter: #Predicate<SessionRecord> { $0.id == sessionId })
    }

    private var store: RecordStore {
        RecordStore(context: modelContext)
    }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("마신 술 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onDone)
                }
            }
            .alert("저장하지 못했어요", isPresented: $saveFailed) {
                Button("확인", role: .cancel) {}
            }
        }
        .tint(BrandColor.amber)
        .onAppear(perform: load)
    }

    private func content(_ session: SessionRecord) -> some View {
        let hidden = kinds.filter { !shownKindIds.contains($0.id) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(RecordFormat.day(session.startedAt))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                ForEach(shownKindIds, id: \.self) { id in
                    if let kind = kinds.first(where: { $0.id == id }) {
                        stepperRow(kind)
                    }
                }

                if !hidden.isEmpty {
                    Menu {
                        ForEach(hidden) { kind in
                            Button(kind.name) {
                                shownKindIds.append(kind.id)
                                draft[kind.id] = max(1, draft[kind.id] ?? 0)
                            }
                        }
                    } label: {
                        Text("다른 술 추가")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BrandColor.amber)
                            .padding(.vertical, 6)
                    }
                }

                HStack {
                    Text("소주 환산")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(RecordFormat.glasses(previewEquivalent(session)))
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundStyle(BrandColor.amber)
                }
                .padding(.top, 8)

                PrimaryButton(title: "변경사항 저장", isEnabled: hasChanges(session)) { save(session) }
                    .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private func stepperRow(_ kind: DrinkKind) -> some View {
        Stepper(value: binding(for: kind.id), in: 0 ... 99) {
            HStack {
                Text(kind.name)
                Spacer()
                Text("\(draft[kind.id] ?? 0)잔")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 17))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func binding(for id: UUID) -> Binding<Int> {
        Binding(get: { draft[id] ?? 0 }, set: { draft[id] = max(0, $0) })
    }

    private func currentCounts(_ session: SessionRecord) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: RecordStore.ledger(of: session).countsByKind().map { ($0.kindId, $0.count) })
    }

    private func load() {
        guard let session = matches.first, kinds.isEmpty else { return }
        kinds = RecordStore.editableKinds(of: session, catalog: store.catalog())
        draft = currentCounts(session)
        shownKindIds = kinds.map(\.id).filter { (draft[$0] ?? 0) > 0 }
    }

    private func hasChanges(_ session: SessionRecord) -> Bool {
        let current = currentCounts(session)
        return kinds.contains { (draft[$0.id] ?? 0) != (current[$0.id] ?? 0) }
    }

    /// 저장 전 미리보기. 같은 순수 함수로 계산해 저장 결과와 어긋나지 않게 한다.
    private func previewEquivalent(_ session: SessionRecord) -> Double {
        var entries = RecordStore.entries(of: session)
        for kind in kinds {
            entries = EntryEdit.adjust(entries, kind: kind, to: draft[kind.id] ?? 0, sessionId: session.id, now: session.startedAt)
        }
        var ledger = DrinkLedger()
        for entry in entries {
            ledger.add(entry)
        }
        return ledger.sojuEquivalent()
    }

    private func save(_ session: SessionRecord) {
        let current = currentCounts(session)
        do {
            for kind in kinds where (draft[kind.id] ?? 0) != (current[kind.id] ?? 0) {
                try store.setCount(draft[kind.id] ?? 0, kind: kind, in: session, now: Date())
            }
            onDone()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    let container = RecordsPreviewData.container()
    return EntryEditView(sessionId: RecordsPreviewData.firstSessionId(in: container)) {}
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
