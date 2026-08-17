import SwiftUI

/// 통계·기록 2탭. iOS는 입력 디바이스가 아니라 열람·정정 전용이라 "경기" 탭이 없다 (spec §2).
/// 통계가 첫 탭이다 — 앱을 열면 요약부터 보인다.
struct MainTabView: View {
    var body: some View {
        TabView {
            StatsView()
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }

            HistoryView()
                .tabItem { Label("기록", systemImage: "clock.fill") }
        }
    }
}
