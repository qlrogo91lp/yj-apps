import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 헤더(Par · 홀·타수 · 모드)와 링 존(◁ 링 ▷) 두 블록으로
/// 이루어진다 (spec §5). 취소는 링 존 안, 왼쪽 아래 코너에 오버레이로 뜬다.
///
/// 헤더-링 간격은 `sizing.spacing`으로 고정한다. 남는 세로 공간은 이 둘을 감싼
/// 블록 위아래의 `Spacer`가 균등하게 나눠 가져 화면 안에서 수직 중앙에 놓이게 한다.
/// 헤더-링 간격 자체를 `Spacer`로 메우던 이전 방식은, 46mm처럼 남는 공간이 유독
/// 큰 세트에서 그 간격만 부자연스럽게 벌어지는 문제가 있었다 (실기 확인, 2026-08-15).
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `ScoringView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CountingView: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CountingSizing

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// 링 존의 가로 패딩. 헤더는 이 값을 쓰지 않는다 — 세로 페이지 인디케이터를 피해
    /// 더 안쪽으로 물러나야 하므로 `CountingSizing.pageIndicatorInset`을 따로 쓴다.
    private let horizontalPadding: CGFloat = 4

    var body: some View {
        // `HoleHeader`는 내부 `Spacer` 때문에 항상 전체 폭을 채우지만, `ringArea`는
        // 고정 폭(화살표+링+화살표)이라 그보다 좁다 — 기본 `.center` 정렬을 쓰면
        // VStack이 ringArea를 가운데로 밀어서 화살표·취소의 x가 Par와 어긋난다.
        // `.leading`으로 두 블록의 왼쪽 원점을 강제로 맞춘다.
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: sizing.spacing) {
                HoleHeader(holeNumber: viewModel.currentHoleNumber,
                           totalStrokes: viewModel.totalStrokes,
                           par: viewModel.currentPar,
                           mode: $viewModel.inputMode,
                           sizing: sizing,
                           onEditPar: viewModel.beginParEditing)
                    .padding(.horizontal, CountingSizing.pageIndicatorInset)

                ringArea
                    .padding(.horizontal, horizontalPadding)
            }

            Spacer(minLength: 0)
        }
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
    }

    /// 한 홀에 연속으로 여러 번 누를 수 있어 길면 다음 탭에서 애니메이션이 겹쳐 밀린다.
    /// 값 기반이라 진행 중 새 값이 들어오면 그쪽으로 바로 따라간다.
    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    /// 링 존 — 이전/다음 홀 화살표가 링 좌우 세로 중앙에 붙는다. 화살표는 세로 공간을
    /// 쓰지 않는 죽은 자리(링 옆 여백)에 들어가므로 링 크기와 다투지 않는다.
    ///
    /// 자체 `ZStack`을 갖는다 — 취소 오버레이가 이 뷰의 원점을 공유해야 x축이
    /// 어긋나지 않는데, `CountingView` 전체를 감싸는 바깥 `ZStack`에 두면 헤더의
    /// 별도 패딩(`pageIndicatorInset`)까지 끼어들어 계산이 두 군데로 흩어진다.
    private var ringArea: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: sizing.spacing) {
                CircleIconButton(systemName: "chevron.left",
                                 size: sizing.arrowSize,
                                 action: viewModel.goToPreviousHole)
                    .disabled(!viewModel.canGoToPreviousHole)
                    .opacity(viewModel.canGoToPreviousHole ? 1 : 0.35)
                    .frame(width: sizing.arrowSize, height: CountingSizing.arrowHitHeight)
                    .contentShape(Rectangle())

                ring

                CircleIconButton(systemName: "chevron.right",
                                 size: sizing.arrowSize,
                                 action: viewModel.goToNextHole)
                    .frame(width: sizing.arrowSize, height: CountingSizing.arrowHitHeight)
                    .contentShape(Rectangle())
            }

            undoOverlay
        }
    }

    /// 링 · 가운데 텍스트 · 탭 타깃을 겹쳐 놓는다.
    /// 탭 타깃은 맨 위에 두되 링 안쪽 원반으로 한정한다 — 링 호와 그 바깥은 탭 영역이 아니다.
    /// 가운데는 이 홀 타수 · 파 대비 두 줄뿐이다 — 홀 번호·누적 타수는 헤더에 있다.
    private var ring: some View {
        ZStack {
            StrokeRing(segments: segments, sizing: sizing)

            VStack(spacing: 0) {
                Text("\(viewModel.currentScore)")
                    .font(.system(size: sizing.scoreFont, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                    .font(.system(size: sizing.relativeFont, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button(action: addStroke) {
                Circle()
                    .fill(.clear)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: sizing.innerDiameter, height: sizing.innerDiameter)
        }
    }

    /// `ringArea`의 오른쪽 아래 코너 오버레이. `ZStack` 안에 있어 등장·퇴장이 화살표·링을
    /// 밀어내지 않는다.
    ///
    /// x축은 `›`가 아니라 **모드 버튼**과 대칭으로 맞춘다 — 모드는 페이지 인디케이터를
    /// 피해 이미 `pageIndicatorInset`(12pt)만큼 화면 가장자리에서 물러나 있어서,
    /// `›`(4pt만 물러난) 기준으로 맞출 때보다 훨씬 여유롭다. 그 여유 덕분에 취소를
    /// 헤더 버튼과 같은 크기(`headerButtonSize`)로 키워도 화면 밖으로 나가지 않는다.
    /// `ringArea` 자신은 `horizontalPadding`(4pt)만큼 안쪽으로 이미 밀려 있으므로,
    /// 모드 버튼의 실제 위치(화면 기준 12pt)에 맞추려면 그 차이(12-4=8pt)만 보정하면
    /// 된다.
    ///
    /// 세로는 실측으로 확인한 값(`undoBottomOffset`)만큼 링 아래로 더 내린다 — `ringArea`의
    /// 레이아웃 경계를 넘어서지만, `TabView(.verticalPage)`가 페이지 콘텐츠를 잘라내지
    /// 않는다는 걸 스크린샷으로 확인했다 (2026-08-15).
    @ViewBuilder
    private var undoOverlay: some View {
        if viewModel.canUndo {
            CircleIconButton(systemName: "arrow.uturn.backward",
                             size: sizing.headerButtonSize,
                             hitInset: CountingSizing.undoHitInset,
                             action: undo)
                .padding(.trailing, CountingSizing.pageIndicatorInset - horizontalPadding)
                .offset(y: CountingSizing.undoBottomOffset)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var segments: RingSegments {
        RingSegments(par: viewModel.currentPar,
                     strokes: viewModel.currentScore,
                     putts: viewModel.currentPutts)
    }

    private func addStroke() {
        viewModel.incrementStroke()
        WKInterfaceDevice.current().play(.click)
    }

    private func undo() {
        viewModel.undo()
        WKInterfaceDevice.current().play(.directionDown)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CountingView(viewModel: viewModel, sizing: .regular)
}
