import SwiftUI

/// 파 선택 화면 — 홀에 파가 없거나(신규 진입) 카운터의 [Par]로 재편집할 때 뜬다.
///
/// 세 par 버튼을 `ScrollView`에 담아 세로 예산 초과를 스크롤로 흡수한다. 고정 높이
/// `VStack`이던 이전 구조는 세로 요구량이 210pt여서 40mm(예산 150pt 안팎)에서 잘렸다.
/// 기기별 크기 세트(`ViewThatFits`)를 쓰지 않는 이유는 스크롤이 그 역할을 대신하기
/// 때문이다 — `CountingView`가 크기 세트를 쓰는 건 링이 스크롤될 수 없는 단일 도형이라서다.
///
/// 이 화면은 `RoundSessionView`의 **가로** `TabView(.page)` 안에만 있어 세로 크라운이
/// 비어 있다. 중첩 `.verticalPage` 안이라 `ScrollView`를 금지한 `ScoringView`와 달리,
/// 여기서는 크라운을 두고 다툴 상대가 없다.
struct ParSelectionView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 백버튼 원형 지름. 헤더 행 높이도 이 값이다.
    private let backButtonSize: CGFloat = 30

    /// 백버튼 탭 영역을 가로로만 넓힌 폭 — Apple 최소 탭 타깃(44pt)에 맞춘다.
    /// 세로로는 넓히지 않는다: 바로 아래가 전체 폭을 차지하는 Par 3 버튼이고 둘 사이엔
    /// `VStack` 간격 6pt밖에 없어, 세로로 키우면 그 탭 영역을 침범한다. 가로는 안전하다 —
    /// 왼쪽은 화면 가장자리, 오른쪽은 비조작 `Text` 라벨이라 이웃의 탭을 가로챌 일이 없다.
    /// `CircleIconButton`의 균일한 `hitInset`은 이런 축 하나만의 확장을 표현할 수 없어
    /// 쓰지 않고, `HoleArrowButton`과 같은 `.frame` + `.contentShape(Rectangle())` 패턴을
    /// 축만 바꿔 적용한다.
    private let backButtonHitWidth: CGFloat = 44

    /// 하단 가로 페이지 점 인디케이터가 마지막 par 행을 덮지 않도록 두는 여백.
    /// 인디케이터는 콘텐츠 위에 그려지므로 레이아웃이 알아서 피해주지 않는다.
    ///
    /// 이 화면의 인디케이터를 실기로 직접 측정하지 못해(라이브 시뮬레이터 검증 단계를
    /// 이번엔 건너뜀) `CountingSizing.pageIndicatorInset`(관련 시스템 크롬 인디케이터를
    /// 실기로 측정한 값, 12)을 보수적 기본값으로 그대로 가져왔다. 이 화면 전용으로
    /// 검증된 수치가 아니므로 사용자가 실기로 확인하면 다시 조정해야 한다.
    private let indicatorClearance: CGFloat = 12

    var body: some View {
        VStack(spacing: 6) {
            header

            ScrollView {
                VStack(spacing: 6) {
                    ForEach([3, 4, 5], id: \.self) { par in
                        ParOptionButton(par: par, isSelected: viewModel.currentPar == par) {
                            viewModel.selectPar(par)
                        }
                    }
                }
                .padding(.bottom, indicatorClearance)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 4)
    }

    /// 헤더는 `ScrollView` 밖에 둔다 — 안에 넣으면 스크롤했을 때 백버튼이 화면 밖으로
    /// 밀려, phantom hole의 유일한 탈출 경로가 사라진다.
    private var header: some View {
        HStack(spacing: 6) {
            backButton
                .frame(width: backButtonHitWidth, height: backButtonSize)
                .contentShape(Rectangle())

            Text(String(format: String(localized: "par_hole_number"), viewModel.currentHoleNumber))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(height: backButtonSize)
    }

    /// 재편집 중이면 편집만 닫고 카운터로 돌아간다(`xmark`) — [Par]로 들어온 사용자가
    /// 기대하는 취소는 홀 이동이 아니라 원래 화면으로 복귀다. 새 홀 진입이면 phantom hole을
    /// 제거하며 이전 홀로 돌아가고(`chevron.left`), 첫 홀에서는 갈 곳이 없어 비활성이다.
    ///
    /// `CircleIconButton`은 비활성 표현을 내장하지 않으므로 호출부에서 붙인다 —
    /// `CountingView.ringArea`의 홀 화살표와 같은 방식이다.
    @ViewBuilder
    private var backButton: some View {
        if viewModel.isEditingPar {
            CircleIconButton(systemName: "xmark",
                             size: backButtonSize,
                             action: viewModel.cancelParEditing)
        } else {
            CircleIconButton(systemName: "chevron.left",
                             size: backButtonSize,
                             action: viewModel.cancelToPreviousHole)
                .disabled(!viewModel.canGoToPreviousHole)
                .opacity(viewModel.canGoToPreviousHole ? 1 : 0.35)
        }
    }
}

#Preview("새 홀 진입") {
    ParSelectionView(viewModel: RoundViewModel())
}

#Preview("파 재편집") {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.beginParEditing()
    return ParSelectionView(viewModel: viewModel)
}
