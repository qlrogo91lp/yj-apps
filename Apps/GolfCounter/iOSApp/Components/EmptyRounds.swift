import SwiftUI

/// 라운드가 하나도 없을 때의 안내. 기록 탭과 통계 탭이 같은 화면을 쓴다 (spec §4·§5).
struct EmptyRounds: View {
    var body: some View {
        ContentUnavailableView {
            Label("기록된 라운드가 없습니다", systemImage: "figure.golf")
        } description: {
            Text("Apple Watch에서 라운드를 시작하세요")
        }
    }
}

#Preview {
    EmptyRounds()
}
