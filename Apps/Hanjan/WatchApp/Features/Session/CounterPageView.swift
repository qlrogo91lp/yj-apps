import SwiftUI

struct CounterPageView: View {
    let session: LiveSession
    let kinds: [DrinkKind]
    let notice: String?
    let onSelect: (UUID) -> Void
    let onToast: () -> Void
    let onUndo: () -> Void
    let onDrink: () -> Void
    @State private var picking = false
    private var exceeded: Bool {
        LimitLevel.of(equivalent: session.ledger.sojuEquivalent(), limit: session.limit) == .exceeded
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Button { picking = true } label: {
                    HStack(spacing: 3) { Text(kinds.first(where: { $0.id == session.currentKindId })?.name ?? "술"); Image(systemName: "chevron.down")
                    }
                    .font(.caption2).padding(.horizontal, 9).padding(.vertical, 6).background(.white.opacity(0.1), in: Capsule())
                }.buttonStyle(.plain)
                Spacer()
                Button("짠", action: onToast).font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 6)
                    .foregroundStyle(session.toast.every == nil ? Color.secondary : BrandColor.amber)
                    .background(session.toast.every == nil ? Color.white.opacity(0.1) : BrandColor.amber.opacity(0.2), in: Capsule())
                    .buttonStyle(.plain)
            }
            CountDisplay(equivalent: session.ledger.sojuEquivalent(), limit: session.limit, progress: session.toastProgress, exceeded: exceeded)
            if let notice { Text(notice).font(.caption2).foregroundStyle(BrandColor.amber).lineLimit(1) }
            LimitBar(equivalent: session.ledger.sojuEquivalent(), limit: session.limit, exceeded: exceeded)
            DrinkButtons(canUndo: session.ledger.last != nil, toastOnly: session.toastProgress.map { !$0.isDrinkTurn } ?? false,
                         exceeded: exceeded, onUndo: onUndo, onDrink: onDrink)
        }
        .sheet(isPresented: $picking) { KindPickerView(kinds: kinds, selected: session.currentKindId) { id in onSelect(id); picking = false } }
    }
}

#Preview { CounterPageView(
    session: LiveSession(id: UUID(), startedAt: Date(), limit: 8, currentKindId: DrinkPresets.soju.id),
    kinds: DrinkPresets.all,
    notice: nil,
    onSelect: { _ in },
    onToast: {},
    onUndo: {},
    onDrink: {}
) }
