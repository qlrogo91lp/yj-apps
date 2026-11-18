import Combine
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    init(store: WatchSessionStore) {
        _viewModel = StateObject(wrappedValue: SessionViewModel(store: store))
    }

    var body: some View {
        Group {
            if let session = viewModel.store.session {
                NavigationStack {
                    TabView {
                        CounterPageView(session: session, kinds: viewModel.store.kinds, notice: viewModel.notice,
                                        onSelect: viewModel.store.selectKind, onToast: viewModel.cycleToast,
                                        onUndo: viewModel.undo, onDrink: viewModel.tapMain)
                        SummaryPageView(session: session, now: viewModel.currentTime, onEnd: viewModel.store.end)
                    }.tabViewStyle(.page)
                }
            } else { StartView(onStart: viewModel.store.start) }
        }
        .background(BrandColor.background)
        .onAppear { viewModel.tick() }
        .onReceive(timer) { _ in viewModel.tick() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.tick() } }
    }
}

#Preview { SessionView(store: WatchSessionStore(defaults: .standard)) }
