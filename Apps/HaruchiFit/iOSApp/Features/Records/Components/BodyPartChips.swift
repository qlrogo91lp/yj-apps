import SwiftUI

struct BodyPartChips: View {
    let selected: [BodyPart]
    let onToggle: (BodyPart) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let isOn = selected.contains(part)
                Button { onToggle(part) } label: {
                    Text(part.title).font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? HaruchiPalette.bg : HaruchiPalette.text)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(isOn ? HaruchiPalette.accent : HaruchiPalette.surface2, in: Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
