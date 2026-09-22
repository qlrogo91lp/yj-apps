import SwiftData
import SwiftUI

/// 농도 컷이 실제 데이터와 맞는지 **눈으로 보는 것**이 이 화면의 유일한 목적이다.
///
/// **제품 화면이 아니다** — Phase 3 탭 셸이 대체한다 (스펙 7절). 애니메이션·스와이프·스탯을
/// 넣지 않는다. 지금까지 이 파일에 달려 있던 "저장 확인용 임시 화면" 이라는 성격을 그대로 잇는다.
struct ContentView: View {
    /// **기간을 좁혀 읽는다.** 홈이 실제로 쓰는 건 6개월치뿐이라 전체를 읽을 이유가 없다 (스펙 5절).
    @Query private var records: [WorkoutRecord]
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @StateObject private var grass = GrassViewModel()
    @State private var selected: Date?

    private static let weeks = 26

    private let calendar = Calendar.current

    init() {
        let since = Calendar.current.date(byAdding: .weekOfYear, value: -Self.weeks, to: Date())
            ?? .distantPast
        _records = Query(filter: #Predicate<WorkoutRecord> { $0.startedAt >= since },
                         sort: \WorkoutRecord.startedAt)
    }

    var body: some View {
        NavigationStack {
            // 가로는 그리드용이다. 세로 당김은 바깥 ScrollView 만 받는다 —
            // 이 화면은 Phase 3 #3 이 통째로 대체할 임시 화면이라 그리드 구조는 그대로 둔다.
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    grid
                    detail
                    Spacer()
                }
                .padding(.top)
            }
            .refreshable { await sync.sync() }
            .navigationTitle("하루치 핏")
            .onAppear { grass.rebuild(from: records) }
            .onChange(of: records) { _, updated in grass.rebuild(from: updated) }
        }
    }

    /// 26주 × 7일. 왼쪽 위가 가장 오래된 날이다.
    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(16), spacing: 3), count: 7),
                      spacing: 3)
            {
                ForEach(gridDays, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: grass.level(on: day)))
                        .frame(width: 16, height: 16)
                        .overlay {
                            if selected == day {
                                RoundedRectangle(cornerRadius: 3).stroke(.primary, lineWidth: 1.5)
                            }
                        }
                        .onTapGesture { selected = day }
                }
            }
            .padding(.horizontal)
        }
        .defaultScrollAnchor(.trailing)
    }

    @ViewBuilder private var detail: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 4) {
                Text(selected.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                if let aggregate = grass.aggregate(on: selected) {
                    Text("\(aggregate.totalSeconds / 60)분 · \(aggregate.sessionCount)회 · 농도 \(grass.level(on: selected).rawValue)단계")
                    Text("근력 \(aggregate.strengthSeconds / 60)분 · 유산소 \(aggregate.cardioSeconds / 60)분")
                        .foregroundStyle(.secondary)
                } else {
                    Text("기록 없음").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
        } else {
            Text("칸을 탭하면 그날 값이 나온다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    /// 오늘이 든 주를 오른쪽 끝에 두고 26주를 거슬러 올라간다.
    private var gridDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let start = calendar.date(byAdding: .weekOfYear, value: -(Self.weeks - 1), to: thisWeek)
        else { return [] }
        return (0 ..< Self.weeks * 7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    /// **임시 색이다.** 디자인 토큰은 Phase 3 #3 에서 들어온다 (스펙 7절).
    private func color(for level: GrassLevel) -> Color {
        switch level {
        case .none: Color.secondary.opacity(0.15)
        case .light: Color.orange.opacity(0.3)
        case .medium: Color.orange.opacity(0.5)
        case .heavy: Color.orange.opacity(0.75)
        case .peak: Color.orange
        }
    }
}

#Preview {
    let container = ContentPreview.container
    ContentView()
        .modelContainer(container)
        .environmentObject(WorkoutSyncCoordinator(context: ModelContext(container)))
}

private enum ContentPreview {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: WorkoutRecord.self, Segment.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("미리보기 컨테이너를 만들지 못했다 — \(error)")
        }
    }()
}
