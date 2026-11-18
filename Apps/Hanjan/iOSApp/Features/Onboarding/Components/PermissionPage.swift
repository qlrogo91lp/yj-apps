import SwiftUI

/// 온보딩 ④ 알림·위치 권한. 이유를 한 줄씩 보이고, 버튼을 눌렀을 때만 시스템 창을 띄운다. 둘 다 건너뛰어도 된다.
struct PermissionPage: View {
    let notification: OnboardingPermissionState
    let location: OnboardingPermissionState
    let onRequestNotification: () -> Void
    let onRequestLocation: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 10) {
                Text("두 가지만 허락해 주세요")
                    .font(.system(size: 28, weight: .bold))
                Text("허락하지 않아도 기록은 그대로 쓸 수 있어요.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                PermissionRow(
                    title: "알림",
                    reason: "한도에 가까워지면 알려 드리고, 다음 날 회고를 챙겨 드려요.",
                    state: notification,
                    action: onRequestNotification
                )
                PermissionRow(
                    title: "위치",
                    reason: "술자리를 시작할 때 한 번 받아 장소를 기록에 남겨요.",
                    state: location,
                    action: onRequestLocation
                )
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// 권한 하나의 이유와 요청 버튼. 물은 뒤에는 결과만 보인다 (거부를 다시 물으려면 설정 앱으로 가야 한다).
private struct PermissionRow: View {
    let title: String
    let reason: String
    let state: OnboardingPermissionState
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(reason)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            switch state {
            case .notAsked:
                Button(action: action) {
                    Text("허용")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(BrandColor.amber)
            case .granted:
                Text("허용됨")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColor.amber)
            case .denied:
                Text("허용 안 함")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PermissionPage(notification: .granted, location: .notAsked, onRequestNotification: {}, onRequestLocation: {})
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
