@testable import TennisCounter_Watch_App
import Foundation
import Testing

struct ScoreViewModelTests {

@Test @MainActor func watchNoEarlyEndAt_T6_6to5_noTie() {
    // Watch 버그: noTieRule=true에서 6-5에 세트 종료되는 것 방지
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
    let vm = ScoreViewModel(options: options)
    var finishCalled = false
    vm.onMatchFinished = { _, _ in finishCalled = true }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    #expect(vm.myGameScore == 6)
    #expect(vm.yourGameScore == 5)
    #expect(finishCalled == false)
}

@Test @MainActor func watchDrawAt_T6_noTie() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
    let vm = ScoreViewModel(options: options)
    var finishedResult: MatchResult?
    vm.onMatchFinished = { result, _ in finishedResult = result }
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(finishedResult == .draw)
}

@Test @MainActor func watchTiebreakStartsAt_T5() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5)
    let vm = ScoreViewModel(options: options)
    var finishCalled = false
    vm.onMatchFinished = { _, _ in finishCalled = true }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.score.gameMode == .tieBreak)
    #expect(finishCalled == false)
}

@Test @MainActor func watchDrawAt_T5_noTie() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 5)
    let vm = ScoreViewModel(options: options)
    var finishedResult: MatchResult?
    vm.onMatchFinished = { result, _ in finishedResult = result }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(finishedResult == .draw)
}

// 누수 진단: 강한 참조를 놓으면 ScoreViewModel이 해제되는지 검증.
// 통과 → VM 자체엔 retain cycle 없음(앱에서 deinit 안 보이는 건 SwiftUI StateObject 보유 때문).
@Test @MainActor func scoreViewModelDeallocatesWhenReleased() {
    weak var weakVM: ScoreViewModel?
    autoreleasepool {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.onMatchFinished = { _, _ in }
        weakVM = vm
        #expect(weakVM != nil)
    }
    #expect(weakVM == nil)
}

}
