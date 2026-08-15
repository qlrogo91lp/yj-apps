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

    @Test func 요약_표시값은_트림_기준이다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole() // 미기록 홀

        #expect(viewModel.recordedHoleCount == 1)
        #expect(viewModel.trimmedTotalStrokes == 5)
        #expect(viewModel.trimmedRelativeToPar == 1)
    }
}
