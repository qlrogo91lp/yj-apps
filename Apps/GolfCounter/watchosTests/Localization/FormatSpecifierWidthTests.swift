import Foundation
import Testing

/// arm64_32(워치 실기기)에서는 Swift `Int`가 32비트라, `%lld`(64비트 `long long`)로 포맷하면
/// 상위 32비트에 스택 쓰레기가 섞여 들어가 숫자가 깨지고 뒤따르는 `%@` 인자까지 밀려
/// 크래시로 이어진다(2026-08-18 실기기 크래시 — 스코어카드 합계 줄).
///
/// `%ld`(`long`)는 arm64_32·arm64 양쪽에서 항상 Swift `Int`와 같은 크기라 안전하다.
/// 시뮬레이터(arm64, 64비트)에서 문자열을 실제로 포맷해서는 이 버그를 재현할 수 없어(우연히
/// 크기가 맞아떨어진다) `.strings` 파일 내용을 직접 검사하는 방식으로 잡는다. `Bundle`이 아니라
/// `#filePath` 기준 경로로 직접 읽으므로 어느 타깃(워치·컴플리케이션·iOS)의 리소스인지와
/// 무관하게 동작한다.
struct FormatSpecifierWidthTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Localization/
        .deletingLastPathComponent() // watchosTests/
        .deletingLastPathComponent() // 저장소 루트

    private static let stringsFiles = [
        "WatchApp/ko.lproj/Localizable.strings",
        "WatchApp/en.lproj/Localizable.strings",
        "ComplicationApp/ko.lproj/Localizable.strings",
        "ComplicationApp/en.lproj/Localizable.strings",
        "iOSApp/ko.lproj/Localizable.strings",
        "iOSApp/en.lproj/Localizable.strings",
    ]

    /// 정수 계열 변환(`d·i·o·u·x·X`)의 길이 수식어만 뽑는다. `%@`·`%%` 등은 대상이 아니다.
    private func integerSpecifiers(in value: String) -> [String] {
        let pattern = #"%(hh|h|ll|l|q|z|t|j)?[dixXou]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = value as NSString
        return regex.matches(in: value, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    @Test func 워치_컴플리케이션_iOS_strings의_정수_지정자가_전부_ld다() throws {
        for relativePath in Self.stringsFiles {
            let url = Self.repoRoot.appendingPathComponent(relativePath)
            let content = try String(contentsOf: url, encoding: .utf8)
            let unsafe = integerSpecifiers(in: content).filter { $0 != "%ld" }
            #expect(unsafe.isEmpty, "\(relativePath): 안전하지 않은 정수 지정자 \(unsafe) — Swift Int에는 %ld만 쓸 것")
        }
    }
}
