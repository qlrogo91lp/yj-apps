import SwiftUI

/// 애플식 "새로운 기능" 목록 — 아이콘 + 제목 + 한 줄, 세로로 쌓는다.
struct OnboardingFeatureListPage: View {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let body: String
        var id: String {
            symbol
        }
    }

    let title: String
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            ForEach(items) { item in
                Row(item: item)
            }
        }
        .padding(.horizontal, 32)
    }

    private struct Row: View {
        let item: Item

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: item.symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.brand)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingFeatureListPage(title: "그리고 이런 것도", items: [
            .init(
                symbol: "applewatch.radiowaves.left.and.right",
                title: "어느 쪽에서 시작해도",
                body: "폰과 워치 중 먼저 시작한 쪽이 심판, 다른 쪽은 따라옵니다"
            ),
            .init(
                symbol: "arrow.uturn.backward",
                title: "되돌리기는 끝까지",
                body: "게임·세트 경계를 넘어 경기 시작까지 되돌립니다"
            ),
        ])
    }
}
