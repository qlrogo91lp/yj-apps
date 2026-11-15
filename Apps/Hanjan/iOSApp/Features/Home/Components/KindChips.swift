import SwiftUI

struct KindChips: View {
    let kinds: [DrinkKind]
    let selected: UUID
    let toastEnabled: Bool
    let onSelect: (UUID) -> Void
    let onToast: () -> Void
    @State private var showMore = false
    var body: some View {
        HStack {
            ForEach(Array(kinds.prefix(3))) { kind in
                Button(kind.name) { onSelect(kind.id) }.buttonStyle(.plain).padding(8)
                    .background(kind.id == selected ? BrandColor.amber.opacity(0.2) : BrandColor.surface, in: Capsule())
                    .foregroundStyle(kind.id == selected ? BrandColor.amber : .primary)
            }
            Button("더보기") { showMore = true }.buttonStyle(.plain).font(.caption)
            Spacer(minLength: 0)
            Button("짠", action: onToast).buttonStyle(.plain).padding(8)
                .background(toastEnabled ? BrandColor.amber.opacity(0.2) : Color.primary.opacity(0.1), in: Capsule())
                .foregroundStyle(toastEnabled ? BrandColor.amber : .secondary)
        }.sheet(isPresented: $showMore) {
            NavigationStack {
                List(kinds) { kind in Button(kind.name) { onSelect(kind.id); showMore = false } }
                    .navigationTitle("술 선택").toolbar { Button("완료") { showMore = false } }
            }
        }
    }
}

#Preview { KindChips(kinds: DrinkPresets.all, selected: DrinkPresets.soju.id, toastEnabled: true, onSelect: { _ in }, onToast: {}) }
