import ConnectivityCore
import Foundation
import SwiftData

/// 워치 → iOS 수신 등록. 앱 시작 시 한 번 만들어 앱이 사는 동안 살려 둔다 (spec §6).
///
/// ⚠️ `ConnectivityService`를 만든 **그 main-queue turn 안에서** `onReceive` 등록을 끝내야 한다.
/// 활성화 콜백(콜드런치 컨텍스트 배달)은 다음 turn에 main으로 들어오므로, 늦게 등록하면
/// 앱이 꺼져 있던 동안 도착한 라운드를 놓친다. 워치의 `RoundTransmitter`가 `lazy`로 미루는 것과
/// 정반대 이유다 — 그쪽은 발신 전용이라 미리 살아 있을 이유가 없다.
@MainActor
final class RoundReceiveService {
    private let service = ConnectivityService()
    private let importer: RoundImporter

    init(context: ModelContext) {
        let importer = RoundImporter(context: context)
        self.importer = importer
        // maxAge를 주지 않는다 — 며칠 뒤에 배달되는 라운드도 그대로 저장해야 한다.
        service.onReceive(RoundCompletedMessage.self) { message in
            importer.save(message)
        }
    }
}
