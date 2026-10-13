import SwiftData
import SwiftUI

/// 세 탭의 공통 셸. 각 화면이 자신의 내비게이션 상태를 소유한다.
/// 실패 알림은 어느 탭에서든 생길 수 있어 여기서 띄운다.
struct ContentView: View {
    private enum Tab: Hashable {
        case home, records, statistics
    }

    @EnvironmentObject private var alerts: AppAlertCenter
    @State private var tab: Tab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView(onShowAllRecords: { tab = .records })
                .tabItem { Label("tab_home", systemImage: "house.fill") }
                .tag(Tab.home)

            RecordsView()
                .tabItem { Label("tab_records", systemImage: "list.bullet.rectangle") }
                .tag(Tab.records)

            StatisticsView()
                .tabItem { Label("tab_statistics", systemImage: "chart.bar.fill") }
                .tag(Tab.statistics)
        }
        .tint(HaruchiPalette.accent)
        .toolbarBackground(HaruchiPalette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert(alerts.current?.title ?? "",
               isPresented: Binding(get: { alerts.current != nil },
                                    set: { if !$0 { alerts.current = nil } }),
               presenting: alerts.current)
        { _ in
            Button("btn_ok", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

#Preview {
    let container = ContentPreview.container
    let alerts = AppAlertCenter()
    ContentView()
        .modelContainer(container)
        .environmentObject(WorkoutSyncCoordinator(context: ModelContext(container), alerts: alerts))
        .environmentObject(alerts)
        .preferredColorScheme(.dark)
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
