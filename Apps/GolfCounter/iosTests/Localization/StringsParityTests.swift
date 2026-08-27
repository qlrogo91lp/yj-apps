import Foundation
@testable import GolfCounter
import Testing

/// ko/en 번역표의 키가 어긋나면 한쪽 언어에서 키 문자열이 그대로 화면에 뜬다.
/// 파일을 손으로 관리하므로(String Catalog가 아니다) 이 검증이 필요하다 (spec §3).
struct StringsParityTests {
    private func table(_ localization: String) throws -> [String: String] {
        let url = try #require(Bundle.main.url(forResource: "Localizable",
                                               withExtension: "strings",
                                               subdirectory: nil,
                                               localization: localization))
        return try #require(NSDictionary(contentsOf: url) as? [String: String])
    }

    private func formatSpecs(_ value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+ #0]*(?:\d+)?(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?[diouxXeEfFgGaAcsS@%]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).map { (value as NSString).substring(with: $0.range) }
    }

    @Test func iOS_두언어의_키집합이_같다() throws {
        let ko = try Set(table("ko").keys)
        let en = try Set(table("en").keys)

        #expect(ko == en, "ko에만: \(ko.subtracting(en)) / en에만: \(en.subtracting(ko))")
    }

    @Test func iOS_번역표가_비어있지_않다() throws {
        #expect(try table("ko").count >= 25)
    }

    @Test func 두언어의_포맷_지정자가_키마다_일치한다() throws {
        let ko = try table("ko")
        let en = try table("en")

        for key in Set(ko.keys).intersection(en.keys) {
            let koSpecs = formatSpecs(ko[key] ?? "")
            let enSpecs = formatSpecs(en[key] ?? "")
            #expect(koSpecs == enSpecs, "\(key): ko=\(koSpecs) en=\(enSpecs)")
        }
    }
}
