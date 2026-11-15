import Combine
import Foundation

@MainActor final class SessionViewModel: ObservableObject {
    let store: WatchSessionStore
    @Published private(set) var notice: String?
    @Published private(set) var currentTime = Date()
    private var subscription: AnyCancellable?
    private var noticeTask: Task<Void, Never>?
    init(store: WatchSessionStore) {
        self.store = store
        subscription = store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func tick() {
        currentTime = Date(); store.tick()
    }

    func tapMain() {
        let toastOnly = store.session?.toastProgress.map { !$0.isDrinkTurn } ?? false
        store.tapMain()
        if toastOnly { show("짠만 했어요") }
    }

    func undo() {
        guard let entry = store.session?.ledger.last else { return }
        store.undo(); show(entry.isToastOnly ? "짠만 취소됨" : "\(entry.kindName) 1잔 취소됨")
    }

    func cycleToast() {
        store.cycleToast()
        if let every = store.session?.toast.every {
            show("짠 모드 \(every)번 중 1번")
        } else {
            show("짠 모드 끔")
        }
    }

    private func show(_ message: String) {
        noticeTask?.cancel(); notice = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}
