import SwiftUI

/// Phase 3 #4에서 목록과 상세 진입을 채울 기록 탭.
struct RecordsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("기록 화면 준비 중",
                                   systemImage: "list.bullet.rectangle",
                                   description: Text("다음 작업에서 기록 목록을 추가한다."))
                .foregroundStyle(HaruchiPalette.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HaruchiPalette.bg.ignoresSafeArea())
                .navigationTitle("기록")
                .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
        }
    }
}
