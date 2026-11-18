@testable import Hanjan
import Testing

struct SojuFormatTests {
    @Test func formatting() {
        #expect(SojuFormat.string(5) == "5"); #expect(SojuFormat.string(7.4) == "7.5"); #expect(SojuFormat.string(7.24) == "7"); #expect(SojuFormat
            .string(.nan) == "0")
    }
}
