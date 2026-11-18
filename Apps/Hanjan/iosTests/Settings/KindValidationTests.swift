@testable import Hanjan
import Testing

struct KindValidationTests {
    private func error(_ result: Result<Void, KindValidationError>) -> KindValidationError? {
        if case let .failure(error) = result { return error }
        return nil
    }

    @Test func blankName_fails() {
        #expect(error(KindValidation.validate(name: "   ", abv: 16, volumeML: 50)) == .emptyName)
        #expect(error(KindValidation.validate(name: "", abv: 16, volumeML: 50)) == .emptyName)
    }

    @Test func abvOutOfRange_fails() {
        #expect(error(KindValidation.validate(name: "하이볼", abv: 0, volumeML: 200)) == .abvOutOfRange)
        #expect(error(KindValidation.validate(name: "하이볼", abv: -1, volumeML: 200)) == .abvOutOfRange)
        #expect(error(KindValidation.validate(name: "하이볼", abv: 100.1, volumeML: 200)) == .abvOutOfRange)
        #expect(error(KindValidation.validate(name: "하이볼", abv: .nan, volumeML: 200)) == .abvOutOfRange)
    }

    @Test func volumeOutOfRange_fails() {
        #expect(error(KindValidation.validate(name: "하이볼", abv: 7, volumeML: 0)) == .volumeOutOfRange)
        #expect(error(KindValidation.validate(name: "하이볼", abv: 7, volumeML: 2000.5)) == .volumeOutOfRange)
        #expect(error(KindValidation.validate(name: "하이볼", abv: 7, volumeML: .infinity)) == .volumeOutOfRange)
    }

    @Test func validValues_pass() {
        #expect(error(KindValidation.validate(name: "하이볼", abv: 7, volumeML: 200)) == nil)
        #expect(error(KindValidation.validate(name: "원액", abv: 100, volumeML: 2000)) == nil)
    }

    @Test func everyErrorHasMessage() {
        for error in [KindValidationError.emptyName, .abvOutOfRange, .volumeOutOfRange] {
            #expect(!error.message.isEmpty)
        }
    }
}
