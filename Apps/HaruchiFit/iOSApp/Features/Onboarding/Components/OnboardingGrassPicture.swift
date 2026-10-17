import SwiftUI

/// 1장 그림 — 7행 잔디 격자가 왼쪽부터 차례로 채워진다.
/// 칸 모양과 색은 홈 잔디(`GrassHero`)와 같다. 동작 줄이기가 켜져 있으면 채워진 상태로 선다.
struct OnboardingGrassPicture: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    private static let columns = 10
    private static let rows = 7
    /// 열마다 한 칸씩 — 난수 없이 고정한 무늬. 0 은 빈 칸, 1~4 는 진하기 단계.
    private static let pattern: [[Int]] = [
        [0, 1, 0, 2, 0, 0, 1], [0, 0, 2, 0, 3, 0, 0], [1, 0, 0, 3, 0, 2, 0],
        [0, 2, 0, 0, 4, 0, 1], [0, 0, 3, 0, 0, 2, 0], [2, 0, 0, 4, 0, 0, 3],
        [0, 3, 0, 0, 2, 0, 0], [0, 0, 4, 0, 3, 0, 2], [3, 0, 0, 4, 0, 4, 0],
        [0, 4, 0, 0, 4, 0, 4],
    ]

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 5
            let cell = min((geo.size.width - 40 - spacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns),
                           (geo.size.height - spacing * CGFloat(Self.rows - 1)) / CGFloat(Self.rows))
            HStack(spacing: spacing) {
                ForEach(0 ..< Self.columns, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0 ..< Self.rows, id: \.self) { row in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color(column: column, row: row))
                                .frame(width: cell, height: cell)
                                .animation(.easeOut(duration: 0.35).delay(Double(column) * 0.18 + Double(row) * 0.03),
                                           value: filled)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(HaruchiPalette.surface)
        .onAppear { filled = true }
        .onDisappear { filled = false }
        .accessibilityHidden(true)
    }

    private func color(column: Int, row: Int) -> Color {
        let shown = reduceMotion || filled
        guard shown, let level = GrassLevel(rawValue: Self.pattern[column][row]) else { return HaruchiPalette.grass(.none) }
        return HaruchiPalette.grass(level)
    }
}
