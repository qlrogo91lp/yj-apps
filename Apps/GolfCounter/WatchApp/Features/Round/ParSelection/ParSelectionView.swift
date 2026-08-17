import SwiftUI

/// 파 선택 화면 — 홀에 파가 없거나(신규 진입) 카운터의 [Par]로 재편집할 때 뜬다.
///
/// 세 par 버튼을 `ScrollView`에 담아 세로 예산 초과를 흡수한다(고정 `VStack`이던 이전
/// 구조는 210pt를 요구해 40mm에서 잘렸다). 가로 `TabView(.page)` 안에만 있어 세로 크라운을
/// 두고 다툴 상대가 없다 — `.verticalPage` 안이라 `ScrollView`를 금지한 `ScoringView`와 다르다.
struct ParSelectionView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 백버튼 원형 지름. 헤더 행 높이도 이 값이다.
    private let backButtonSize: CGFloat = 30

    /// 백버튼 탭 영역을 가로로만 넓힌 폭 — Apple 최소 탭 타깃(44pt)에 맞춘다.
    /// 세로로는 넓히지 않는다: 바로 아래 Par 3 버튼과 간격이 6pt뿐이라 그 탭 영역을 침범한다.
    /// 균일 확장인 `CircleIconButton.hitInset`으로는 축 하나만의 확장을 표현할 수 없다.
    private let backButtonHitWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            header

            // 하단 페이지 인디케이터는 safe area에 이미 잡혀 있어 따로 여백을 두지 않는다
            // (시뮬레이터 실측 2026-08-17, bottom inset 22~40pt / 전 기종 5종).
            ScrollView {
                VStack(spacing: 6) {
                    ForEach([3, 4, 5], id: \.self) { par in
                        ParOptionButton(par: par, isSelected: viewModel.currentPar == par) {
                            viewModel.selectPar(par)
                        }
                    }
                }
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

    /// 재편집 중이면 편집만 닫고 카운터로 돌아간다(`xmark`). 새 홀 진입이면 phantom hole을
    /// 제거하며 이전 홀로 돌아가고(`chevron.left`), 첫 홀에서는 갈 곳이 없어 비활성이다.
    /// `CircleIconButton`은 비활성 표현을 내장하지 않으므로 호출부에서 붙인다.
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
