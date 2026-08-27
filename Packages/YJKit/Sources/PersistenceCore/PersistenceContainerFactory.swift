import Foundation
import SwiftData

public enum PersistenceContainerFactory {
    /// CloudKit 동기화 시도 → 실패(iCloud 미로그인, 시뮬레이터, 엔타이틀먼트 부재 등) 시 로컬 폴백.
    /// 로컬조차 실패하면 앱이 저장소 없이 동작할 수 없으므로 fatalError (원본 iOSApp.swift 동작 유지).
    /// - Parameter inMemory: 테스트·프리뷰용. 디스크에 스토어 파일을 만들지 않는다.
    public static func make(for types: [any PersistentModel.Type],
                            cloudKit: Bool = true,
                            inMemory: Bool = false) -> ModelContainer
    {
        let schema = Schema(types)
        if cloudKit {
            do {
                let config = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: inMemory,
                                                cloudKitDatabase: .automatic)
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                // 로컬 폴백으로 진행
            }
        }
        do {
            let config = ModelConfiguration(schema: schema,
                                            isStoredInMemoryOnly: inMemory,
                                            cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("PersistenceContainerFactory: 로컬 ModelContainer 생성 실패 — \(error)")
        }
    }
}
