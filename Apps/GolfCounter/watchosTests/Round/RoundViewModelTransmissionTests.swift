import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelTransmissionTests {
    private func makeViewModel(holeCount: Int = 18,
                               publisher: RoundSnapshotPublisherSpy,
                               transmitter: RoundTransmitterSpy) -> RoundViewModel
    {
        RoundViewModel(holeCount: holeCount,
                       startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: publisher,
                       transmitter: transmitter)
    }

    /// 한 홀을 파 선택 → 타수 입력까지 채운다.
    private func playHole(_ viewModel: RoundViewModel, par: Int, strokes: Int) {
        viewModel.selectPar(par)
        for _ in 0 ..< strokes {
            viewModel.incrementStroke()
        }
    }

    @Test func 종료하면_요약_단계가_되고_종료시각이_기록된다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)

        viewModel.finishRound()

        #expect(viewModel.phase == .summary)
        #expect(viewModel.endedAt != nil)
    }

    @Test func 메트릭이_이미_있으면_즉시_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(RoundMetrics(calories: 412, avgHeartRate: 118, distanceMeters: 6200, steps: 9100))

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.count == 1)
        #expect(transmitter.sent.first?.metrics.calories == 412)
        #expect(viewModel.didComplete)
    }

    @Test func 메트릭이_아직_없으면_전송_대기_상태가_된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.isEmpty)
        #expect(viewModel.isTransmitting)
        #expect(viewModel.didComplete == false)
    }

    @Test func 대기_중_메트릭이_도착하면_이어서_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.saveAndTransmit()

        viewModel.applyMetrics(RoundMetrics(calories: 300, avgHeartRate: 100, distanceMeters: 1000, steps: 500))

        #expect(transmitter.sent.count == 1)
        #expect(viewModel.isTransmitting == false)
        #expect(viewModel.didComplete)
    }

    @Test func 워크아웃_결과를_못받으면_0값으로_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.metrics == .empty)
    }

    @Test func 기록홀이_없으면_전송하지_않고_스냅샷만_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.isEmpty)
        #expect(publisher.clearCallCount == 1)
        #expect(viewModel.didComplete)
    }

    @Test func 전송_페이로드는_트림된_배열이다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole() // 파를 안 고른 채 남겨 말단 미기록 홀을 만든다
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holeScores == [5])
        #expect(transmitter.sent.first?.holePars == [4])
    }

    @Test func 전송하면_스냅샷을_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(publisher.clearCallCount == 1)
    }

    @Test func 라운드_id는_발행을_거듭해도_바뀌지_않는다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())

        viewModel.start()
        playHole(viewModel, par: 4, strokes: 2)

        let ids = Set(publisher.published.map(\.id))
        #expect(ids.count == 1)
        #expect(ids.first == viewModel.id)
    }

    @Test func 복구한_라운드는_스냅샷의_id와_홀수를_잇는다() {
        let id = UUID()
        let snapshot = RoundSnapshot(id: id,
                                     holeCount: 9,
                                     startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: nil,
                                     currentHoleIndex: 0,
                                     holeScores: [3],
                                     holePars: [3],
                                     puttCounts: [1])

        let viewModel = RoundViewModel(resuming: snapshot,
                                       publisher: RoundSnapshotPublisherSpy(),
                                       transmitter: RoundTransmitterSpy())

        #expect(viewModel.id == id)
        #expect(viewModel.snapshot.holeCount == 9)
    }

    @Test func 마지막_홀에서는_다음홀로_갈_수_없다() {
        let viewModel = makeViewModel(holeCount: 9,
                                      publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        for _ in 1 ..< 9 {
            viewModel.selectPar(4)
            viewModel.goToNextHole()
        }

        #expect(viewModel.canGoToNextHole == false)

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 9)
    }

    @Test func 마지막_홀에서_다음홀_시도는_입력모드와_되돌리기_기록을_보존한다() {
        let viewModel = makeViewModel(holeCount: 9,
                                      publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        for _ in 1 ..< 9 {
            viewModel.selectPar(4)
            viewModel.goToNextHole()
        }
        viewModel.selectPar(4)
        viewModel.inputMode = .putt
        viewModel.incrementStroke()

        #expect(viewModel.canGoToNextHole == false)
        #expect(viewModel.canUndo)

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 9)
        #expect(viewModel.inputMode == .putt)
        #expect(viewModel.canUndo)
    }

    @Test func 요약_표시값은_트림_기준이다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole() // 미기록 홀

        #expect(viewModel.recordedHoleCount == 1)
        #expect(viewModel.trimmedTotalStrokes == 5)
        #expect(viewModel.trimmedRelativeToPar == 1)
    }

    // MARK: - discardRound (저장 안 함)

    @Test func 저장안함_전송하지않고_스냅샷을_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        viewModel.discardRound()

        #expect(transmitter.sent.isEmpty)
        #expect(publisher.clearCallCount == 1)
        #expect(viewModel.didComplete == true)
    }

    @Test func 저장안함_메트릭을_기다리지_않는다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        // 워크아웃 집계가 아직 안 온 상태에서도 즉시 끝난다 — 버릴 라운드에 메트릭은 필요 없다.
        viewModel.discardRound()

        #expect(viewModel.didComplete == true)
        #expect(viewModel.isTransmitting == false)
    }

    @Test func 저장안함_대기중이던_전송을_취소한다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        // 메트릭이 아직 안 왔으므로 saveAndTransmit()은 대기 상태로 들어간다.
        viewModel.saveAndTransmit()
        #expect(viewModel.isTransmitting == true)

        viewModel.discardRound()
        // 취소 후 뒤늦게 메트릭이 도착해도 isTransmitting이 꺼져 있으므로 전송되지 않는다.
        viewModel.applyMetrics(RoundMetrics(calories: 300, avgHeartRate: 100, distanceMeters: 5000, steps: 8000))

        #expect(transmitter.sent.isEmpty)
    }

    // MARK: - 종료 시 미타구 홀 정규화

    @Test func 종료하면_파만고른_말단홀이_전송에서_빠진다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 파만 고르고 종료

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        // 파가 0으로 돌아간 뒤 말단이므로 trimmed()가 배열에서 아예 제거한다.
        #expect(transmitter.sent.first?.holePars == [4])
        #expect(transmitter.sent.first?.holeScores == [5])
        #expect(viewModel.recordedHoleCount == 1)
    }

    @Test func 종료하면_이전버튼으로_두고온_파만고른홀도_정리된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 홀 2에 파만 남기고
        viewModel.goToPreviousHole() // 홀 1로 돌아와 종료 (invariant spec §4.2)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holePars == [4])
        #expect(transmitter.sent.first?.holeScores == [5])
        #expect(viewModel.recordedHoleCount == 1)
    }

    /// 정규화된 홀이 배열 **중간**에 남는 경우 — 위 두 테스트는 전부 말단 케이스라
    /// `trimmed()`가 홀 자체를 지워 버린다. 중간 홀은 파만 0으로 돌아가고 배열엔 남아
    /// 전송된다. `finishRound()`가 실제로 발행하는 스냅샷도 여기서 처음 검증한다 —
    /// 이전까지는 스파이를 만들고 버려서 발행 내용이 고정돼 있지 않았다.
    @Test func 종료하면_중간의_파만고른홀은_파가0인채_배열에남아전송된다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 홀 2에 파만 남기고
        viewModel.goToNextHole() // 홀 3으로 — 홀 2는 배열 중간에 par-only로 남는다
        playHole(viewModel, par: 5, strokes: 4)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holePars == [4, 0, 5])
        #expect(transmitter.sent.first?.holeScores == [5, 0, 4])
        #expect(viewModel.recordedHoleCount == 2)
        #expect(publisher.published.last?.holePars == [4, 0, 5])
        #expect(publisher.published.last?.holeScores == [5, 0, 4])
    }

    @Test func 전부_파만고른_라운드는_빈라운드로_처리된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        viewModel.selectPar(4)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        // 기록 홀이 0이므로 iOS에 빈 라운드를 만들지 않는다 (invariant spec §5.3).
        #expect(transmitter.sent.isEmpty)
        #expect(viewModel.didComplete)
    }
}
