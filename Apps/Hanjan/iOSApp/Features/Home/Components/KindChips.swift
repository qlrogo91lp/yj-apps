import SwiftUI

struct KindChips: View {
    let kinds: [DrinkKind]
    let selected: UUID
    let onSelect: (UUID) -> Void
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

        }.sheet(isPresented: $showMore) {
            NavigationStack {
                List(kinds) { kind in Button(kind.name) { onSelect(kind.id); showMore = false } }
                    .navigationTitle("술 선택").toolbar { Button("완료") { showMore = false } }
            }
        }
    }
}

#Preview { KindChips(kinds: DrinkPresets.all, selected: DrinkPresets.soju.id, onSelect: { _ in }) }
