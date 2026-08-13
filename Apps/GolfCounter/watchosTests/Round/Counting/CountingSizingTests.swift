import CoreGraphics
@testable import GolfCounter_Watch_App
import Testing

struct CountingSizingTests {
    private let sets: [CountingSizing] = [.regular, .compact, .tight]

    /// ViewThatFits는 regular → compact → tight 순으로 시도해 첫 번째로 들어가는 것을 고른다.
    /// 뒤 세트가 앞 세트보다 큰 값이 하나라도 있으면 그 순서가 의미를 잃는다.
    @Test func 크기세트는_regular에서_tight로_갈수록_모든_값이_작아진다() {
        for (larger, smaller) in zip(sets, sets.dropFirst()) {
            #expect(smaller.headerHeight < larger.headerHeight)
            #expect(smaller.headerFont < larger.headerFont)
            #expect(smaller.parButtonSize < larger.parButtonSize)
            #expect(smaller.undoSize < larger.undoSize)
            #expect(smaller.ringDiameter < larger.ringDiameter)
            #expect(smaller.ringStroke < larger.ringStroke)
            #expect(smaller.overflowStroke < larger.overflowStroke)
            #expect(smaller.overflowGap < larger.overflowGap)
            #expect(smaller.scoreFont < larger.scoreFont)
            #expect(smaller.relativeFont < larger.relativeFont)
            #expect(smaller.arrowSize < larger.arrowSize)
            #expect(smaller.modeHeight < larger.modeHeight)
            #expect(smaller.modeWideWidth < larger.modeWideWidth)
            #expect(smaller.spacing < larger.spacing)
        }
    }

    /// 링 안쪽 원반은 라운드 중 가장 많이 눌리는 탭 타깃이다.
    /// 가장 작은 세트에서도 Apple 권장 최소 44pt 아래로 내려가면 안 된다.
    @Test func 가장_작은_크기세트도_링_안쪽_원반이_44pt_이상이다() {
        #expect(CountingSizing.tight.innerDiameter >= 44)
    }

    /// 취소와 Par는 헤더 안에 들어가므로 헤더 높이를 넘으면 행이 삐져나온다.
    @Test func 헤더_버튼은_헤더_높이를_넘지_않는다() {
        for sizing in sets {
            #expect(sizing.parButtonSize <= sizing.headerHeight)
            #expect(sizing.undoSize <= sizing.headerHeight)
        }
    }

    /// 알약 변형이 원형보다 좁으면 ViewThatFits의 두 후보 순서가 뒤집힌다.
    @Test func 알약_모드버튼은_원형보다_넓다() {
        for sizing in sets {
            #expect(sizing.modeWideWidth > sizing.modeHeight)
        }
    }

    /// 40mm에서만 헤더를 축약한다 — 나머지는 전체 표기가 들어간다.
    @Test func 헤더_축약은_가장_작은_세트에서만_켜진다() {
        #expect(CountingSizing.regular.usesShortHoleLabel == false)
        #expect(CountingSizing.compact.usesShortHoleLabel == false)
        #expect(CountingSizing.tight.usesShortHoleLabel)
    }

    /// 링이 실제로 프레임을 잡는 값은 ringDiameter가 아니라 outerRadius*2다 (초과 링 공간을
    /// 항상 예약하므로). 이 테스트는 그 실제 값 기준으로 세로 합계가 예산 안에 들어가는지 본다.
    ///
    /// 예산은 화면 높이가 아니라 `GeometryReader`로 실측한, `ScoringView`가 실제로 받는
    /// 가용 세로 공간이다 — 바깥 `TabView(.page)` + 안쪽 `TabView(.verticalPage)`가 중첩되며
    /// 화면 높이의 상당 부분을 페이지 인디케이터 크롬으로 가져가기 때문에 화면 높이 그대로
    /// 쓰면 예산이 실제보다 훨씬 크게 잡힌다 (46mm 168pt 아님 — 실측 167.5pt).
    @Test func 세로_합계는_실제_렌더_기준으로_예산_안에_들어간다() {
        let budgets: [(CountingSizing, CGFloat)] = [(.regular, 167.5), (.compact, 152.0), (.tight, 138.5)]
        for (sizing, budget) in budgets {
            let total = sizing.headerHeight + sizing.spacing * 2
                + sizing.outerRadius * 2 + sizing.modeHeight
            #expect(total <= budget)
        }
    }
}
