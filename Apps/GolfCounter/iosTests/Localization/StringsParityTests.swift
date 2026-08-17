import Foundation
@testable import GolfCounter
import Testing

/// ko/en 번역표의 키가 어긋나면 한쪽 언어에서 키 문자열이 그대로 화면에 뜬다.
/// 파일을 손으로 관리하므로(String Catalog가 아니다) 이 검증이 필요하다 (spec §3).
struct StringsParityTests {
    private func keys(_ localization: String) throws -> Set<String> {
        let url = try #require(Bundle.main.url(forResource: "Localizable",
                                               withExtension: "strings",
                                               subdirectory: nil,
                                               localization: localization))
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return Set(table.keys)
    }

    @Test func iOS_두언어의_키집합이_같다() throws {
        let ko = try keys("ko")
        let en = try keys("en")

        #expect(ko == en, "ko에만: \(ko.subtracting(en)) / en에만: \(en.subtracting(ko))")
    }

    @Test func iOS_번역표가_비어있지_않다() throws {
        #expect(try keys("ko").count >= 25)
    }
}
