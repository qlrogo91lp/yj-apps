import SwiftUI

/// 카운터 화면 — 크라운으로 넘기는 세로 페이지 (spec §4).
///
/// 1페이지가 카운터, 그 뒤로 스코어카드가 9홀씩 이어진다. 시스템이 세로 점
/// 인디케이터를 그려주므로 아래에 내용이 더 있다는 사실이 발견된다.
///
/// 이 화면은 `RoundSessionView`의 **가로** TabView 안에 들어 있다. 크라운(세로)과
/// 스와이프(가로)는 입력 채널이 달라 충돌하지 않는다. 페이지 안에 `ScrollView`를
/// 두지 않으므로 크라운을 쓰는 주체가 페이지 전환 하나뿐이고, 다툴 상대가 없다.
struct ScoringView: View {
    @ObservedObject var viewModel: RoundViewModel
    /// watchOS의 `.verticalPage` 스타일은 `selection` 바인딩이 없으면 첫 페이지가 아니라
    /// 마지막 페이지로 초기 진입하는 경우가 있다(시뮬레이터 탭 테스트로 확인).
    /// 태그를 명시하고 0으로 고정 초기화해 항상 카운터 페이지에서 시작하도록 만든다.
    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            ViewThatFits(in: .vertical) {
                CountingView(viewModel: viewModel, sizing: .regular)
                CountingView(viewModel: viewModel, sizing: .compact)
                CountingView(viewModel: viewModel, sizing: .tight)
            }
            .tag(0)

            ForEach(Array(chunks.enumerated()), id: \.element.lowerBound) { index, range in
                ScorecardView(snapshot: viewModel.snapshot,
                          holeRange: range,
                          showsTotal: range.upperBound == holeCount)
                    .padding(.horizontal, 4)
                    .tag(index + 1)
            }
        }
        .tabViewStyle(.verticalPage)
    }

    private var holeCount: Int {
        viewModel.snapshot.holeScores.count
    }

    private var chunks: [Range<Int>] {
        ScorecardChunks.ranges(holeCount: holeCount)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return ScoringView(viewModel: viewModel)
}
