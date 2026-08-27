#if os(iOS)
    import SwiftUI

    /// 대시보드 지표 카드의 공통 컨테이너.
    struct MetricCard<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                content()
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
#endif
