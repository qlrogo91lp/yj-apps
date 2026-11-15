import SwiftData
import SwiftUI

/// 다음 날 회고 폼. 상태 · 함께한 사람 · 장소 · 메모, 전부 선택 입력.
/// 회고 알림 딥링크(T9)와 기록 상세가 시트로 띄운다. `onDone` 은 저장했든 `나중에 하기` 든 닫을 때 부른다.
struct ReviewFormView: View {
    let sessionId: UUID
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [SessionRecord]
    @State private var condition: Int?
    @State private var companions: [String] = []
    @State private var knownCompanions: [String] = []
    @State private var placeName = ""
    @State private var memo = ""
    @State private var didLoad = false
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
        Group {
            if let session = matches.first {
                form(session)
            } else {
                VStack(spacing: 16) {
                    Text("기록을 찾을 수 없어요")
                        .foregroundStyle(.secondary)
                    CapsuleButton(title: "닫기", action: onDone)
                        .frame(maxWidth: 200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BrandColor.background)
        .alert("저장하지 못했어요", isPresented: $saveFailed) {
            Button("확인", role: .cancel) {}
        }
        .task { await load() }
    }

    private func form(_ session: SessionRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(session)

                ConditionPicker(selection: condition) { condition = $0 }

                section("누구랑") {
                    CompanionField(
                        known: knownCompanions,
                        selected: companions,
                        onToggle: toggleCompanion,
                        onAdd: { name in
                            if !companions.contains(name) { companions.append(name) }
                        }
                    )
                }

                section("장소") {
                    TextField("장소 이름", text: $placeName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                section("메모") {
                    TextField("메모를 남겨보세요", text: $memo, axis: .vertical)
                        .lineLimit(3 ... 8)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "저장하기") { save(session) }
                    Button("나중에 하기", action: onDone)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func header(_ session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(RecordFormat.shortDay(session.startedAt))의 술자리")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandColor.amber)
            Text(RecordFormat.calendar.isDateInYesterday(session.startedAt) ? "어제 어땠나요?" : "어땠나요?")
                .font(.system(size: 28, weight: .bold))
            Text("기억이 생생할 때 남겨보세요.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    private func toggleCompanion(_ name: String) {
        if let index = companions.firstIndex(of: name) {
            companions.remove(at: index)
        } else {
            companions.append(name)
        }
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func load() async {
        guard !didLoad, let session = matches.first else { return }
        didLoad = true
        condition = session.condition
        companions = (session.companions ?? []).map(\.name)
        knownCompanions = store.companionNames()
        placeName = session.placeName ?? ""
        memo = session.memo ?? ""
        // 장소가 비어 있고 좌표가 있으면 역지오코딩으로 채운다. 그사이 사용자가 적었으면 덮지 않는다.
        if placeName.isEmpty, let latitude = session.latitude, let longitude = session.longitude,
           let name = await PlaceNameLookup.name(latitude: latitude, longitude: longitude), placeName.isEmpty
        {
            placeName = name
        }
    }

    private func save(_ session: SessionRecord) {
        do {
            try store.saveReview(session, condition: condition, companions: companions, placeName: placeName, memo: memo)
            onDone()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    let container = RecordsPreviewData.container()
    return ReviewFormView(sessionId: RecordsPreviewData.firstSessionId(in: container)) {}
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
