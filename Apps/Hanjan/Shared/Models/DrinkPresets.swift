import Foundation

nonisolated enum DrinkPresets {
    static let soju = make(1, "소주", 16, 50)
    static let beer = make(2, "맥주", 4.5, 200)
    static let somaek = make(3, "소맥", 7, 200)
    static let wine = make(4, "와인", 13, 150)
    static let whisky = make(5, "위스키", 40, 30)
    static let other = make(6, "기타", 16, 50)
    static let all = [soju, beer, somaek, wine, whisky, other]
    private static func make(_ n: Int, _ name: String, _ abv: Double, _ volume: Double) -> DrinkKind {
        DrinkKind(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(n))),
            name: name,
            abv: abv,
            volumeML: volume,
            isPreset: true,
            sortOrder: n - 1
        )
    }
}
