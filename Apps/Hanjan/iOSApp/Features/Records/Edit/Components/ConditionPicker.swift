import SwiftUI

/// 회고의 상태 5단계. 글자 버튼, 이모지 없음. 고른 것을 다시 누르면 선택이 풀린다 (선택 입력).
struct ConditionPicker: View {
    let selection: Int?
    let onSelect: (Int?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ReviewCondition.values, id: \.self) { value in
                let isSelected = selection == value
                Button {
                    onSelect(isSelected ? nil : value)
                } label: {
                    Text(ReviewCondition.label(value) ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Color.black : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, 2)
                        .background(isSelected ? BrandColor.amber : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

#Preview {
    ConditionPicker(selection: 2) { _ in }
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
