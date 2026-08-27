#if os(watchOS)
    import SwiftUI

    /// 공백으로 구분된 라벨을 단어마다 한 줄씩 세로로 쌓는다.
    /// 워치의 좁은 폭에서 "ACTIVE KCAL" 같은 두 단어 라벨을 숫자 옆에 붙이기 위한 것.
    struct StackedLabel: View {
        let text: String
        let font: Font
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(text.split(separator: " ").map(String.init), id: \.self) { word in
                    Text(word)
                        .font(font)
                        .foregroundColor(color)
                }
            }
        }
    }
#endif
