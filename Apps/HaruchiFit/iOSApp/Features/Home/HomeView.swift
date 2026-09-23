import SwiftData
import SwiftUI

/// Phase 4 홈 대시보드 전까지 기존 잔디·HealthKit 동기화 확인 경로를 유지한다.
struct HomeView: View {
    /// 홈이 실제로 쓰는 6개월치만 읽는다.
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    grid
                    detail
                    Spacer()
                }
                .padding(.top)
            }
            .background(HaruchiPalette.bg.ignoresSafeArea())
            .refreshable { await sync.sync() }
            .navigationTitle("하루치 핏")
            .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
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
                        .fill(HaruchiPalette.grass(grass.level(on: day)))
                        .frame(width: 16, height: 16)
                        .overlay {
                            if selected == day {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(HaruchiPalette.text, lineWidth: 1.5)
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
                    .foregroundStyle(HaruchiPalette.text)
                if let aggregate = grass.aggregate(on: selected) {
                    Text("\(aggregate.totalSeconds / 60)분 · \(aggregate.sessionCount)회 · 농도 \(grass.level(on: selected).rawValue)단계")
                        .foregroundStyle(HaruchiPalette.text)
                    Text("근력 \(aggregate.strengthSeconds / 60)분 · 유산소 \(aggregate.cardioSeconds / 60)분")
                        .foregroundStyle(HaruchiPalette.dim)
                } else {
                    Text("기록 없음").foregroundStyle(HaruchiPalette.dim)
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
        } else {
            Text("칸을 탭하면 그날 값이 나온다.")
                .font(.footnote)
                .foregroundStyle(HaruchiPalette.dim)
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
}
