import SwiftUI

/// 워치 앱의 뿌리. **세션 단계에 따라 어느 화면을 보일지만 정한다.**
///
/// 화면 자체는 각 단계가 갖는다 — 분기와 내용을 한 파일에 두면 단계가 늘 때마다
/// 이 파일이 커진다.
struct WorkoutRootView: View {
    @EnvironmentObject private var viewModel: WorkoutViewModel

    var body: some View {
        switch viewModel.phase {
        case .idle:
            StartView(viewModel: viewModel)
        case .active:
            SessionView(viewModel: viewModel)
        case .summary:
            SummaryView(viewModel: viewModel)
        }
    }
}
