import SwiftUI

/// 워치 스크린샷 위에 얹는 크라운 안내. 크라운은 오른쪽 가장자리 중간쯤이다.
///
/// 이미지에 그리지 않으므로 라벨이 로컬라이즈되고 위치 조정이 코드로 끝난다.
struct CrownArrowsOverlay: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            arrow("arrow.up", label: String(localized: "onboarding_crown_up"), color: .green)
            arrow("arrow.down", label: String(localized: "onboarding_crown_down"), color: .orange)
        }
        // 컨테이너 오른쪽 안쪽에 붙인다. scaledToFit 은 뷰가 가용 폭을 다 차지하므로
        // 바깥 좌표(width + n)를 주면 화면 밖으로 잘린다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
        // 크라운은 세로 가운데보다 조금 위다. 스크린샷이 들어오면 프리뷰에서 맞춘다.
        .offset(y: -24)
    }

    private func arrow(_ symbol: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7), in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        Color.gray.opacity(0.3)
            .frame(width: 220, height: 380)
            .overlay { CrownArrowsOverlay() }
    }
}
