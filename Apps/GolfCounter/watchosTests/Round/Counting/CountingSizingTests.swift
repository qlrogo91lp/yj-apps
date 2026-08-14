import CoreGraphics
@testable import GolfCounter_Watch_App
import Testing

struct CountingSizingTests {
    private let sets: [CountingSizing] = [.regular, .compact, .tight]

    /// ViewThatFits는 regular → compact → tight 순으로 시도해 첫 번째로 들어가는 것을 고른다.
    /// 뒤 세트가 앞 세트보다 큰 값이 하나라도 있으면 그 순서가 의미를 잃는다.
    @Test func 크기세트는_regular에서_tight로_갈수록_모든_값이_작아진다() {
        for (larger, smaller) in zip(sets, sets.dropFirst()) {
            #expect(smaller.headerButtonSize < larger.headerButtonSize)
            #expect(smaller.headerFont < larger.headerFont)
            #expect(smaller.holeInfoFont < larger.holeInfoFont)
            #expect(smaller.arrowSize < larger.arrowSize)
            #expect(smaller.ringDiameter < larger.ringDiameter)
            #expect(smaller.ringStroke < larger.ringStroke)
            #expect(smaller.overflowStroke < larger.overflowStroke)
            #expect(smaller.overflowGap < larger.overflowGap)
            #expect(smaller.scoreFont < larger.scoreFont)
            #expect(smaller.relativeFont < larger.relativeFont)
            #expect(smaller.undoSize < larger.undoSize)
            #expect(smaller.spacing < larger.spacing)
        }
    }

    /// 링 안쪽 원반은 라운드 중 가장 많이 눌리는 탭 타깃이다.
    /// 가장 작은 세트에서도 Apple 권장 최소 44pt 아래로 내려가면 안 된다.
    @Test func 가장_작은_크기세트도_링_안쪽_원반이_44pt_이상이다() {
        #expect(CountingSizing.tight.innerDiameter >= 44)
    }

    /// 링을 키우는 리디자인의 핵심 약속 — 탭 원반이 모든 세트에서 넉넉히 크다.
    @Test func 탭_원반은_모든_세트에서_70pt_이상이다() {
        for sizing in sets {
            #expect(sizing.innerDiameter >= 70)
        }
    }

    /// 헤더 안 두 원형(Par·모드)은 같은 지름이라 시각적으로 대칭을 이룬다.
    /// `headerButtonSize` 하나를 공유하는 것으로 이 대칭이 보장되므로 별도 필드 비교는
    /// 필요 없지만, 화살표·취소가 헤더 버튼보다 작다는 위계는 지켜야 한다.
    @Test func 화살표와_취소는_헤더_버튼보다_작거나_같다() {
        for sizing in sets {
            #expect(sizing.arrowSize <= sizing.headerButtonSize)
            #expect(sizing.undoSize <= sizing.headerButtonSize)
        }
    }

    /// 링이 실제로 프레임을 잡는 값은 ringDiameter가 아니라 outerRadius*2다 (초과 링 공간을
    /// 항상 예약하므로). 이 테스트는 그 실제 값 기준으로 세로 합계가 예산 안에 들어가는지 본다.
    ///
    /// 예산은 화면 높이가 아니라 `GeometryReader`로 실측한, `ScoringView`가 실제로 받는
    /// 가용 세로 공간이다 — 바깥 `TabView(.page)` + 안쪽 `TabView(.verticalPage)`가 중첩되며
    /// 화면 높이의 상당 부분을 페이지 인디케이터 크롬으로 가져가기 때문에 화면 높이 그대로
    /// 쓰면 예산이 실제보다 훨씬 크게 잡힌다 (46mm 168pt 아님 — 실측 167.5pt).
    /// 세로 합계 = 헤더 버튼 지름 + spacing(Spacer 최소값) + 링. 취소는 오버레이라 세로
    /// 예산에 들어가지 않는다.
    @Test func 세로_합계는_실제_렌더_기준으로_예산_안에_들어간다() {
        let budgets: [(CountingSizing, CGFloat)] = [(.regular, 167.5), (.compact, 152.0), (.tight, 138.5)]
        for (sizing, budget) in budgets {
            let total = sizing.headerButtonSize + sizing.spacing + sizing.outerRadius * 2
            #expect(total <= budget)
        }
    }

    /// 화살표가 링 좌우에 붙으므로 가로도 예산이 된다 — 가로 합계 = 화살표 두 개 + 간격 + 링.
    /// 예산은 각 세트가 커버하는 기기 중 가장 좁은 화면의 폭에서 좌우 패딩 8pt를 뺀 값이다:
    /// regular = Ultra 49mm(205pt) → 197, compact = 41mm(176pt) → 168, tight = 40mm(162pt) → 154.
    @Test func 가로_합계는_가장_좁은_대상_기기의_폭_안에_들어간다() {
        let budgets: [(CountingSizing, CGFloat)] = [(.regular, 197.0), (.compact, 168.0), (.tight, 154.0)]
        for (sizing, budget) in budgets {
            let total = sizing.arrowSize * 2 + sizing.spacing * 2 + sizing.outerRadius * 2
            #expect(total <= budget)
        }
    }
}
