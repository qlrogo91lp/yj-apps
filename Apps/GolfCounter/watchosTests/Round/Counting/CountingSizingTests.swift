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

    /// 화살표는 직접 누르는 탭 타깃이라 축소하지 않는다 — regular·compact는 헤더
    /// 버튼과 같은 크기, tight만 가로 폭 한계로 살짝 작다(그래도 `<=`는 항상 성립).
    /// 취소도 이제 헤더 버튼과 같은 크기를 쓰므로 이 위계에서 제외한다.
    @Test func 화살표는_헤더_버튼보다_작거나_같다() {
        for sizing in sets {
            #expect(sizing.arrowSize <= sizing.headerButtonSize)
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

    /// 각 세트가 커버하는 기기 중 **가장 좁은** 화면의 폭.
    ///
    /// 현행 제품군은 40 · 42 · 44 · 46 · 49mm 다섯 가지이고, 폭은 시뮬레이터 실측이다
    /// (2026-08-15): 40mm 162 · 44mm 184 · 42mm 187 · 46mm 208 · Ultra 49mm 211.
    /// 화면이 클수록 폭도 크다는 법칙이 없다 — 44mm가 42mm보다 좁고, 세트별 하한은
    /// mm 순서가 아니라 이 실측값에서 나온다.
    ///
    /// regular = 46mm · 49mm → 208 / compact = 42mm · 44mm → 184 / tight = 40mm → 162.
    /// tight는 마지막 후보라 이 아래로는 fallback이 없다.
    /// 단종 기기(41 · 45mm)는 `ViewThatFits`가 알아서 맞는 세트로 떨어뜨린다.
    private static let narrowestWidths: [(CountingSizing, CGFloat)] = [
        (.regular, 208.0), (.compact, 184.0), (.tight, 162.0),
    ]

    /// 헤더는 양끝 원형(Par·모드) 사이에 최장 라벨까지 들어가야 한다. 세로 페이지
    /// 인디케이터를 피해 좌우로 물러난 뒤 남는 폭이 기준이다 — 여기서 모자라면
    /// 가운데 텍스트가 `minimumScaleFactor`로 쪼그라들어, 글자를 키운 의미가 사라진다.
    ///
    /// `usesShortHoleLabel`이 켜진 세트는 "Hole 18 · 108"이 아니라 "H18 · 108"이
    /// 실제로 렌더되므로 그 짧은 라벨 기준으로 검사한다.
    @Test func 헤더_양끝_버튼_사이에_홀_라벨_공간이_남는다() {
        for (sizing, screenWidth) in Self.narrowestWidths {
            let available = screenWidth - CountingSizing.pageIndicatorInset * 2
            let textRoom = available - sizing.headerButtonSize * 2 - sizing.spacing * 2
            // "Hole 18 · 108"(13글자, 5.5em) / "H18 · 108"(9글자, 4.0em)의 폭 근사.
            // 숫자·글자가 섞여 있고 공백과 `·`가 좁아 글자당 폭을 보수적으로 낮게 잡는다.
            let neededEm: CGFloat = sizing.usesShortHoleLabel ? 4.0 : 5.5
            #expect(textRoom >= sizing.holeInfoFont * neededEm)
        }
    }

    /// 40mm에서만 헤더 라벨을 축약한다 — 나머지는 전체 표기가 들어간다.
    @Test func 헤더_라벨_축약은_가장_작은_세트에서만_켜진다() {
        #expect(CountingSizing.regular.usesShortHoleLabel == false)
        #expect(CountingSizing.compact.usesShortHoleLabel == false)
        #expect(CountingSizing.tight.usesShortHoleLabel)
    }

    /// 화살표가 링 좌우에 붙으므로 가로도 예산이 된다 — 가로 합계 = 화살표 두 개 + 간격 + 링.
    /// 링 존은 헤더와 달리 페이지 인디케이터를 피할 필요가 없어 좌우 패딩 4pt씩만 뺀다.
    @Test func 가로_합계는_가장_좁은_대상_기기의_폭_안에_들어간다() {
        for (sizing, screenWidth) in Self.narrowestWidths {
            let total = sizing.arrowSize * 2 + sizing.spacing * 2 + sizing.outerRadius * 2
            #expect(total <= screenWidth - 8)
        }
    }
}
