import CoreGraphics
@testable import GolfCounter_Watch_App
import Testing

struct CounterSizingTests {
    /// ViewThatFits는 regular → compact → tight 순으로 시도해 첫 번째로 들어가는 것을 고른다.
    /// 뒤 세트가 앞 세트보다 큰 값이 하나라도 있으면 그 순서가 의미를 잃는다.
    @Test func 크기세트는_regular에서_tight로_갈수록_모든_값이_작아진다() {
        let sets: [CounterSizing] = [.regular, .compact, .tight]
        for (larger, smaller) in zip(sets, sets.dropFirst()) {
            #expect(smaller.headerFont < larger.headerFont)
            #expect(smaller.scoreFont < larger.scoreFont)
            #expect(smaller.strokeButton < larger.strokeButton)
            #expect(smaller.strokeIcon < larger.strokeIcon)
            #expect(smaller.controlHeight < larger.controlHeight)
            #expect(smaller.navHeight < larger.navHeight)
            #expect(smaller.spacing < larger.spacing)
        }
    }

    /// 타수 버튼은 라운드 중 가장 많이 눌리는 컨트롤이다.
    /// 가장 작은 세트에서도 Apple 권장 최소 탭 타깃 44pt 아래로 내려가면 안 된다.
    @Test func 가장_작은_크기세트도_타수버튼이_44pt_이상이다() {
        #expect(CounterSizing.tight.strokeButton >= 44)
    }
}
