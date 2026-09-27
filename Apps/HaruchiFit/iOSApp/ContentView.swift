import SwiftData
import SwiftUI

/// 세 탭의 공통 셸. 각 화면이 자신의 내비게이션 상태를 소유한다.
/// 실패 알림은 어느 탭에서든 생길 수 있어 여기서 띄운다.
struct ContentView: View {
    @EnvironmentObject private var alerts: AppAlertCenter

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }

            RecordsView()
                .tabItem { Label("기록", systemImage: "list.bullet.rectangle") }

            StatisticsView()
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }
        }
        .tint(HaruchiPalette.accent)
        .toolbarBackground(HaruchiPalette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert(alerts.current?.title ?? "",
               isPresented: Binding(get: { alerts.current != nil },
                                    set: { if !$0 { alerts.current = nil } }),
               presenting: alerts.current)
        { _ in
            Button("확인", role: .cancel) {}
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
