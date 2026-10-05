import Foundation
import SwiftData
@testable import TennisCounter

/// 테스트 하나가 쓰는 저장소 묶음. 앱 싱글턴은 건드리지 않는다.
///
/// - 이름을 매번 새로 준다 — 이름 없는 설정은 모두 `default` 저장소를 가리켜 테스트끼리 섞인다
/// - `cloudKitDatabase: .none` — 앱에 iCloud 권한이 있어 기본값이면 인메모리 저장소에도 미러링이 붙는다
/// - 컨테이너를 정적 배열에 보관한다 — 테스트 함수가 끝나도 서비스가 든 컨텍스트가 죽지 않게
/// - 서비스와 화면은 프로덕션처럼 같은 컨테이너의 **서로 다른** 컨텍스트를 쓴다
@MainActor
struct TestPersistence {
    private static var retainedContainers: [ModelContainer] = []

    let container: ModelContainer
    let matches: MatchPersistenceService
    let sessions: SessionPersistenceService

    static func make() throws -> TestPersistence {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Match.self,
            SetRecord.self,
            WorkoutSessionRecord.self,
            configurations: configuration
        )
        retainedContainers.append(container)
        return TestPersistence(container: container)
    }

    /// 화면이 `@Environment(\.modelContext)`로 받는 컨텍스트에 해당한다.
    func newContext() -> ModelContext {
        ModelContext(container)
    }

    /// 같은 저장소를 새 서비스·컨텍스트로 다시 연다 — 앱 재실행 흉내.
    func relaunched() -> TestPersistence {
        TestPersistence(container: container)
    }

    private init(container: ModelContainer) {
        self.container = container
        matches = MatchPersistenceService()
        matches.configure(with: ModelContext(container))
        sessions = SessionPersistenceService()
        sessions.configure(with: ModelContext(container))
    }
}
