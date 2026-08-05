import SwiftUI

/// "245 kcal" 형태의 수치 + 단위. 단위가 수치의 마지막 텍스트 베이스라인에 정렬된다.
public struct MetricValueLabel: View {
    private let value: String
    private let unit: String
    private let valueSize: CGFloat
    private let unitSize: CGFloat

    public init(value: String, unit: String, valueSize: CGFloat = 32, unitSize: CGFloat = 14) {
        self.value = value
        self.unit = unit
        self.valueSize = valueSize
        self.unitSize = unitSize
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: unitSize, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
