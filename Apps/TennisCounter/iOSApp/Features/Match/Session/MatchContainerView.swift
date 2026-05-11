import SwiftUI

struct MatchContainerView: View {
    let format: MatchFormat

    @StateObject private var viewModel = MatchContainerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 1

    var body: some View {
        // 앱 하단 탭 숨김: MatchContainerView가 NavigationStack에 push될 때
        // .toolbar(.hidden, for: .tabBar)를 outer TabView(앱 탭바)에 전달한다.
        // inner TabView 자체에 붙이면 inner 탭바를 숨길 위험이 있으므로
        // Group으로 래핑해서 modifier를 분리한다.
        Group {
            TabView(selection: $selectedTab) {
                if viewModel.watchConnected {
                    WorkoutTabView(
                        metrics: viewModel.metrics,
                        onPauseResume: {},
                        onEnd: { dismiss() }
                    )
                    .tabItem {
                        Label(String(localized: "tab_workout"), systemImage: "figure.run")
                    }
                    .tag(0)
                }

                ScoreTabView(format: format)
                    .tabItem {
                        Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                    }
                    .tag(1)
            }
        }
        .toolbar(.hidden, for: .tabBar) // 앱 하단 탭 숨김 (outer TabView 대상)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MatchContainerView(format: .bestOfThree)
    }
}
