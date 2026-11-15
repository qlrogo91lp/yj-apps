import Foundation

/// 술 추가·편집 입력 검사. 도수 0%·용량 0ml 인 술은 소주 환산이 0 이 되어 숫자가 의미를 잃으므로 받지 않는다.
nonisolated enum KindValidation {
    static let abvRange = 0.0 ... 100.0
    static let volumeRange = 0.0 ... 2000.0

    static func validate(name: String, abv: Double, volumeML: Double) -> Result<Void, KindValidationError> {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .failure(.emptyName) }
        guard abv.isFinite, abv > abvRange.lowerBound, abv <= abvRange.upperBound else { return .failure(.abvOutOfRange) }
        guard volumeML.isFinite, volumeML > volumeRange.lowerBound, volumeML <= volumeRange.upperBound else {
            return .failure(.volumeOutOfRange)
        }
        return .success(())
    }
}
