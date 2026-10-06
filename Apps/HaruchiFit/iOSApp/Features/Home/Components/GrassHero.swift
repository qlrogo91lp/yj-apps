import SwiftUI

/// 잔디 히어로 — 26주를 가로로 스와이프하고 처음 위치는 오른쪽 끝(오늘)이다.
/// 오늘 칸은 테두리가 천천히 밝아졌다 어두워진다. 동작 줄이기가 켜져 있으면 고정 테두리다.
struct GrassHero: View {
    let days: [Date]
    let level: (Date) -> GrassLevel
    let today: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(16), spacing: 3), count: 7), spacing: 3) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(HaruchiPalette.grass(level(day)))
                        .frame(width: 16, height: 16)
                        .overlay {
                            if day == today {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(HaruchiPalette.text, lineWidth: 1.5)
                                    .opacity(reduceMotion || pulsing ? 1 : 0.25)
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
        .defaultScrollAnchor(.trailing)
        .frame(height: 7 * 16 + 6 * 3)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }
}
