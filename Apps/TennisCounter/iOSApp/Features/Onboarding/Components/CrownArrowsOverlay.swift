import SwiftUI

/// 워치 스크린샷 위에 얹는 크라운 안내. 오른쪽 가장자리 중간이 크라운 자리다.
///
/// 이미지에 그리지 않으므로 라벨이 로컬라이즈되고 위치 조정이 코드로 끝난다.
struct CrownArrowsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                arrow("arrow.up", label: String(localized: "onboarding_crown_up"), color: .green)
                arrow("arrow.down", label: String(localized: "onboarding_crown_down"), color: .orange)
            }
            // 0.42 는 Series 11 46mm 스크린샷 기준 크라운 높이. 다른 기기 스크린샷을 쓰면 프리뷰에서 맞춘다.
            .position(x: geo.size.width + 4, y: geo.size.height * 0.42)
        }
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
