import SwiftUI

struct KindPickerView: View {
    let kinds: [DrinkKind]
    let selected: UUID
    let onSelect: (UUID) -> Void
    var body: some View {
        List(kinds) { kind in
            Button { onSelect(kind.id) } label: {
                HStack { Text(kind.name); Spacer(); if kind.id == selected { Image(systemName: "checkmark").foregroundStyle(BrandColor.amber) } }
            }
        }.navigationTitle("술 선택")
    }
}

#Preview { KindPickerView(kinds: DrinkPresets.all, selected: DrinkPresets.soju.id, onSelect: { _ in }) }
