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
            Spacer(minLength: 0)
            CountDisplay(equivalent: session.ledger.sojuEquivalent(), limit: session.limit, exceeded: exceeded)
            LimitBar(equivalent: session.ledger.sojuEquivalent(), limit: session.limit, exceeded: exceeded)
            if let progress = session.toastProgress {
                HStack(spacing: 8) {
                    ForEach(0 ..< progress.total, id: \.self) { index in
                        Circle().fill(index < progress.filled ? BrandColor.amber : BrandColor.amber.opacity(0.25)).frame(width: 10, height: 10)
                    }
                }.accessibilityLabel("\(progress.total)번 중 \(progress.filled)번째")
            }
            if let notice { Text(notice).font(.caption2).foregroundStyle(BrandColor.amber).lineLimit(1) }
            Spacer(minLength: 0)
            DrinkButtons(canUndo: session.ledger.last != nil, toastOnly: session.toastProgress.map { !$0.isDrinkTurn } ?? false,
                         exceeded: exceeded, onUndo: onUndo, onDrink: onDrink)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { picking = true } label: {
                    HStack(spacing: 3) {
                        Text(kinds.first(where: { $0.id == session.currentKindId })?.name ?? "술")
                        Image(systemName: "chevron.down")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("짠 모드", action: onToast).foregroundStyle(session.toast.every == nil ? Color.white : BrandColor.amber)
            }
        }
        .sheet(isPresented: $picking) { KindPickerView(kinds: kinds, selected: session.currentKindId) { id in onSelect(id); picking = false } }
    }
}
