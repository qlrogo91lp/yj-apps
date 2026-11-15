import SwiftUI

/// 함께한 사람. 한 번 입력한 이름은 칩으로 남아 다음부터 누르기만 하면 된다.
struct CompanionField: View {
    let known: [String]
    let selected: [String]
    let onToggle: (String) -> Void
    let onAdd: (String) -> Void

    @State private var newName = ""

    private var chips: [String] {
        known + selected.filter { !known.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { name in
                            let isSelected = selected.contains(name)
                            Button {
                                onToggle(name)
                            } label: {
                                Text(name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isSelected ? BrandColor.amber : Color.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? BrandColor.amber.opacity(0.2) : Color.white.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("새 이름", text: $newName)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Button("추가", action: add)
                    .font(.system(size: 15, weight: .semibold))
                    .tint(BrandColor.amber)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onAdd(name)
        newName = ""
    }
}

#Preview {
    CompanionField(known: ["지민", "민수", "동료들"], selected: ["지민"], onToggle: { _ in }, onAdd: { _ in })
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
