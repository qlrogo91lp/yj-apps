import SwiftUI

/// 상단 정보행 — 양끝이 원형 버튼(Par·취소), 가운데가 텍스트다 (spec §5).
///
/// 취소가 사라져도 가운데 텍스트가 밀리면 안 되므로, 취소가 없을 때는 같은 크기의
/// 투명 자리채움을 둔다. `RoundSessionView`가 워크아웃 탭에서 쓰는 방식과 같다.
///
/// 누적 타수에 `+`를 붙이지 않는다. 골프에서 `+`는 오버파를 뜻하므로 `+41`은
/// "41 오버"로 읽히고, 링 안의 파 대비 표시와 부호가 겹친다.
struct CounterHeader: View {
    let holeNumber: Int
    let par: Int
    let totalStrokes: Int
    let canUndo: Bool
    let sizing: CountingSizing
    let onEditPar: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: sizing.spacing) {
            parButton
            Spacer(minLength: 0)
            Text(centerTitle)
                .font(.system(size: sizing.headerFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            undoSlot
        }
        .frame(height: sizing.headerHeight)
    }

    private var centerTitle: String {
        let hole = sizing.usesShortHoleLabel ? "H\(holeNumber)" : "\(holeNumber)번 홀"
        return "\(hole) · \(totalStrokes)타"
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
            .frame(width: sizing.parButtonSize, height: sizing.parButtonSize)
            .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var undoSlot: some View {
        if canUndo {
            UndoButton(size: sizing.undoSize, action: onUndo)
        } else {
            Color.clear
                .frame(width: sizing.undoSize, height: sizing.undoSize)
        }
    }
}

#Preview {
    VStack {
        CounterHeader(holeNumber: 7, par: 4, totalStrokes: 41, canUndo: true,
                      sizing: .regular, onEditPar: {}, onUndo: {})
        CounterHeader(holeNumber: 7, par: 4, totalStrokes: 41, canUndo: false,
                      sizing: .tight, onEditPar: {}, onUndo: {})
    }
}
