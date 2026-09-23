import SwiftUI

/// Phase 4 #9에서 연도 아카이브를 채울 통계 탭.
struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("통계 화면 준비 중",
                                   systemImage: "chart.bar.fill",
                                   description: Text("잔디와 기록이 쌓이면 통계를 보여준다."))
                .foregroundStyle(HaruchiPalette.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HaruchiPalette.bg.ignoresSafeArea())
                .navigationTitle("통계")
                .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
        }
    }
}
