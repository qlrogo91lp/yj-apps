import ConnectivityCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @ObservedObject var store: PhoneSessionStore
    @ObservedObject var settings: AppSettings
    var onRecords: () -> Void
    var onSettings: () -> Void
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var records: [SessionRecord]
    @State private var confirmEnd = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let session = store.session {
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            let minutes = max(0, Int(timeline.date.timeIntervalSince(session.startedAt) / 60))
                            Text("기록 중 · \(minutes / 60)시간 \(minutes % 60)분 · \(session.startedAt.formatted(date: .omitted, time: .shortened)) 시작")
                                .font(.caption).foregroundStyle(BrandColor.amber)
                        }
                        Text("오늘의 술자리").font(.title.bold())
                        ActiveSessionCard(session: session)
                        HStack {
                            Text("마신 술").font(.headline)
                            Spacer()
                            Text(session.ledger.countsByKind().map { "\($0.name) \($0.count)" }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        KindChips(kinds: store.kinds, selected: session.currentKindId, toastEnabled: session.toast.every != nil,
                                  onSelect: store.selectKind, onToast: store.cycleToast)
                        DrinkButtons(canUndo: session.ledger.last != nil, toastOnly: session.toastProgress.map { !$0.isDrinkTurn } ?? false,
                                     exceeded: LimitLevel.of(equivalent: session.ledger.sojuEquivalent(), limit: session.limit) == .exceeded,
                                     onUndo: store.undo, onDrink: store.tapMain)
                        CapsuleButton(title: "종료", style: .danger) { confirmEnd = true }
                    } else {
                        Text("오늘의 한 잔").font(.title.bold())
                        VStack(alignment: .leading, spacing: 8) {
                            Text("나의 한도").font(.caption).foregroundStyle(.secondary)
                            Text("소주 \(SojuFormat.string(settings.limit))잔").font(.title2.bold())
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(
                            BrandColor.surface,
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        PrimaryButton(title: "시작", action: store.start)
                        MonthSummaryCard(summary: .of(records, month: Date()))
                        HStack { Text("최근 기록").font(.headline); Spacer(); Button("전체 보기", action: onRecords) }
                        ForEach(Array(records.filter { $0.endedAt != nil }.prefix(3))) { record in
                            Button(action: onRecords) { RecentSessionRow(record: record) }.buttonStyle(.plain)
                        }
                    }
                }.padding()
            }.background(BrandColor.background).toolbar { Button("설정", action: onSettings) }
                .confirmationDialog("술자리를 종료할까요?", isPresented: $confirmEnd) {
                    Button("종료", role: .destructive, action: store.end)
                }
        }.preferredColorScheme(.dark)
    }
}

#Preview {
    if let container = try? ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
        let settings = AppSettings()
        HomeView(
            store: PhoneSessionStore(
                connectivity: ConnectivityService(),
                archive: SessionArchive(context: container.mainContext),
                settings: settings
            ),
            settings: settings,
            onRecords: {},
            onSettings: {}
        ).modelContainer(container)
    }
}
