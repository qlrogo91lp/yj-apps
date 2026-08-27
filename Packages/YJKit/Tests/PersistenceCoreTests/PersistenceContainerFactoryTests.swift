import Foundation
import SwiftData
import Testing
@testable import PersistenceCore

@MainActor
struct PersistenceContainerFactoryTests {
    /// 로컬(비 CloudKit) 컨테이너가 만들어지고 실제 저장이 동작하는지 왕복 검증
    @Test func makeLocalContainerRoundTrips() throws {
        let container = PersistenceContainerFactory.make(
            for: [StubRecord.self], cloudKit: false, inMemory: true
        )
        let context = ModelContext(container)
        context.insert(StubRecord(value: 42))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<StubRecord>())
        #expect(fetched.first?.value == 42)
    }

    /// cloudKit: true여도 항상 사용 가능한 컨테이너를 반환한다
    /// (엔타이틀먼트 없는 테스트 환경 = CloudKit 실패 → 로컬 폴백 경로가 이 테스트로 실행된다)
    @Test func makeWithCloudKitFallsBackToUsableContainer() throws {
        let container = PersistenceContainerFactory.make(
            for: [StubRecord.self], cloudKit: true, inMemory: true
        )
        let context = ModelContext(container)
        context.insert(StubRecord(value: 7))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<StubRecord>())
        #expect(fetched.first?.value == 7)
    }
}
