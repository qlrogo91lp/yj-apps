import SwiftUI

/// 상단 정보행 — 양끝이 원형 버튼(Par·모드), 가운데가 홀·누적 타수 텍스트다 (spec §5).
///
/// 취소는 여기 없다 — 화면 왼쪽 아래 코너에 별도 오버레이로 뜬다(`CountingView` 참조).
/// 홀 번호·누적 타수는 표시 전용이라 버튼과 자리를 다툴 필요가 없지만, 링 중앙에
/// 텍스트 세 줄을 몰아넣으면 스코어 폰트가 눌리므로 다시 헤더로 올렸다.
///
/// 라벨은 영어로 쓴다 ("Hole 7 · 41") — 한글도 폭 자체는 문제없지만, 이 화면에서는
/// 홀·타수·모드 표기를 영어로 통일하기로 했다. 나머지 화면(ParSelection 등)은 그대로 한글이다.
struct HoleHeader: View {
    let holeNumber: Int
    let totalStrokes: Int
    let par: Int
    @Binding var mode: StrokeInputMode
    let sizing: CountingSizing
    let onEditPar: () -> Void

    var body: some View {
        HStack(spacing: sizing.spacing) {
            parButton
            Spacer(minLength: 0)
            Text(holeInfoText)
                .font(.system(size: sizing.holeInfoFont, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            ModeButton(mode: $mode, sizing: sizing)
        }
        .frame(height: sizing.headerButtonSize)
    }

    private var holeInfoText: String {
        let hole = sizing.usesShortHoleLabel ? "H\(holeNumber)" : "Hole \(holeNumber)"
        return "\(hole) · \(totalStrokes)"
    }

    private var parButton: some View {
        Button(action: onEditPar) {
            VStack(spacing: 0) {
                Text("Par")
                    .font(.system(size: sizing.headerFont * 0.6, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(par)")
                    .font(.system(size: sizing.headerFont, weight: .semibold))
            }
            .frame(width: sizing.headerButtonSize, height: sizing.headerButtonSize)
            .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -CountingSizing.headerButtonHitInset))
    }
}

#Preview {
    VStack {
        HoleHeader(holeNumber: 7, totalStrokes: 41, par: 4, mode: .constant(.swing),
                   sizing: .regular, onEditPar: {})
        HoleHeader(holeNumber: 7, totalStrokes: 41, par: 4, mode: .constant(.putt),
                   sizing: .tight, onEditPar: {})
    }
}
