import SwiftUI

/// 라운드가 하나도 없을 때의 안내. 기록 탭과 통계 탭이 같은 화면을 쓴다 (spec §4·§5).
struct EmptyRounds: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "empty_rounds_title"), systemImage: "figure.golf")
        } description: {
            Text(String(localized: "empty_rounds_message"))
        }
    }
}

#Preview {
    EmptyRounds()
}
