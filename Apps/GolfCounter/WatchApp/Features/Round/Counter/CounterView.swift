import SwiftUI

/// 카운터 화면 — 크라운으로 넘기는 세로 페이지 스크롤.
///
/// 1페이지는 화면 높이에 정확히 고정된 카운터, 그 아래가 전체 스코어카드다 (spec §4).
/// 스코어카드가 한 화면을 넘으면 `.paging`이 컨테이너 높이 단위로 알아서 더 나눈다.
///
/// 라운드 초반(기록된 홀이 적을 때)은 전체 스크롤 콘텐츠가 한 화면을 간신히 넘는 정도라,
/// 스크롤이 콘텐츠의 최대 오프셋에서 클램핑되어 "2페이지"가 카운터 하단 일부 + 스코어카드
/// 전체가 겹쳐 보이는 형태로 뜬다. 이는 `ScrollView`의 정상적인 클램핑 동작이지 버그가 아니며,
/// 모든 라운드가 시작 시점에 거치는 상태다.
///
/// 이 화면은 `RoundSessionView`의 **가로** TabView 안에 들어 있다. 크라운(세로)과
/// 스와이프(가로)는 입력 채널이 달라 충돌하지 않는다 — 세로 TabView를 중첩하지 않은 이유다.
struct CounterView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    CounterPage(viewModel: viewModel, sizing: .regular)
                    CounterPage(viewModel: viewModel, sizing: .compact)
                    CounterPage(viewModel: viewModel, sizing: .tight)
                }
                .containerRelativeFrame(.vertical)

                Scorecard(snapshot: viewModel.snapshot)
                    .padding(.horizontal, 4)
            }
        }
        .scrollTargetBehavior(.paging)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterView(viewModel: viewModel)
}
