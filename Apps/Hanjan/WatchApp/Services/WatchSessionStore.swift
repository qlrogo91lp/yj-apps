import Combine
import ConnectivityCore
import Foundation
import WidgetKit

@MainActor final class WatchSessionStore: ObservableObject {
    @Published private(set) var session: LiveSession?
    @Published private(set) var kinds: [DrinkKind]
    @Published private(set) var limit: Double
    private let defaults: UserDefaults
    private let now: () -> Date
    private let send: (any ConnectivityMessage, Delivery) -> Void
    private let location: WatchLocationService?
    private let haptics: WatchHaptics?
    private let sessionKey = "hanjan.watch.session"
    private let configKey = "hanjan.watch.config"
    private let endedKey = "hanjan.watch.endedSessionIds"

    convenience init(connectivity: ConnectivityService, now: @escaping () -> Date = Date.init) {
        self.init(defaults: UserDefaults(suiteName: SessionSnapshotStore.appGroup) ?? .standard, now: now,
                  send: { message, delivery in connectivity.send(message, via: delivery) },
                  location: WatchLocationService(), haptics: WatchHaptics())
        connectivity.onReceive(SessionStartMessage.self) { [weak self] in self?.receive($0) }
        connectivity.onReceive(SessionEndMessage.self) { [weak self] in self?.receive($0) }
        connectivity.onReceive(EntryAddMessage.self) { [weak self] in self?.receive($0) }
        connectivity.onReceive(EntryRemoveMessage.self) { [weak self] in self?.receive($0) }
        connectivity.onReceive(SessionStateMessage.self) { [weak self] in self?.receive($0) }
        connectivity.onReceive(ConfigMessage.self) { [weak self] in self?.receive($0) }
    }

    init(defaults: UserDefaults, now: @escaping () -> Date = Date.init,
         send: @escaping (any ConnectivityMessage, Delivery) -> Void = { _, _ in },
         location: WatchLocationService? = nil, haptics: WatchHaptics? = nil)
    {
        self.defaults = defaults; self.now = now; self.send = send; self.location = location; self.haptics = haptics
        let decoder = JSONDecoder()
        let config = defaults.data(forKey: configKey).flatMap { try? decoder.decode(ConfigMessage.self, from: $0) }
        kinds = config?.kinds ?? DrinkPresets.all
        limit = config.map { max(1, $0.limit) } ?? 8
        session = defaults.data(forKey: sessionKey).flatMap { try? decoder.decode(LiveSession.self, from: $0) }
    }

    func start() {
        guard session == nil else { return }
        let current = LiveSession(id: UUID(), startedAt: now(), limit: limit, currentKindId: (kinds.first ?? DrinkPresets.soju).id)
        session = current
        publish(SessionStartMessage(session: current))
        let currentID = current.id
        location?.request { [weak self] latitude, longitude in
            guard let self, var current = session, current.id == currentID else { return }
            current.latitude = latitude; current.longitude = longitude; session = current
            publishState()
        }
    }

    func tapMain() {
        guard var current = session, let kind = kinds.first(where: { $0.id == current.currentKindId }) else { return }
        let previous = LimitLevel.of(equivalent: current.ledger.sojuEquivalent(), limit: current.limit)
        let entry = current.makeEntry(id: UUID(), at: now(), kind: kind, source: .watch)
        current.ledger.add(entry); session = current
        haptics?.click()
        let next = LimitLevel.of(equivalent: current.ledger.sojuEquivalent(), limit: current.limit)
        if let crossed = LimitLevel.crossed(from: previous, to: next) { haptics?.alert(crossed) }
        publish(EntryAddMessage(entry: entry))
    }

    func undo() {
        guard var current = session, let last = current.ledger.last else { return }
        current.ledger.remove(id: last.id); session = current
        publish(EntryRemoveMessage(sessionId: current.id, entryId: last.id))
    }

    func cycleToast() {
        guard var current = session else { return }
        let next: Int? = current.toast.every == nil ? 2 : (current.toast.every == 2 ? 3 : nil)
        current.setToast(every: next, at: now()); session = current; publishState()
    }

    func selectKind(_ id: UUID) {
        guard kinds.contains(where: { $0.id == id }), var current = session else { return }
        current.currentKindId = id; session = current; publishState()
    }

    func end() {
        finish(at: now())
    }

    func tick() {
        if let current = session, current.shouldAutoEnd(now: now()) { finish(at: current.lastActivityAt) }
    }

    private func finish(at date: Date) {
        guard let current = session else { return }
        for id in current.mergedSessionIds.union([current.id]) {
            rememberEnded(id)
        }
        session = nil; publish(SessionEndMessage(sessionId: current.id, endedAt: date))
    }

    func receive(_ message: SessionStartMessage) {
        merge(message.session)
    }

    func receive(_ message: SessionStateMessage) {
        guard let incoming = message.session else { session = nil; persist(); return }
        merge(incoming)
    }

    func receive(_ message: SessionEndMessage) {
        rememberEnded(message.sessionId)
        guard let current = session, current.owns(sessionId: message.sessionId) else { return }
        for id in current.mergedSessionIds.union([current.id]) {
            rememberEnded(id)
        }
        session = nil; persist()
    }

    func receive(_ message: EntryAddMessage) {
        guard var current = session, current.owns(sessionId: message.entry.sessionId) else { return }
        current.ledger.add(message.entry); session = current; persist()
    }

    func receive(_ message: EntryRemoveMessage) {
        guard var current = session, current.owns(sessionId: message.sessionId) else { return }
        current.ledger.remove(id: message.entryId); session = current; persist()
    }

    func receive(_ message: ConfigMessage) {
        kinds = message.kinds; limit = max(1, message.limit)
        if let data = try? JSONEncoder().encode(message) { defaults.set(data, forKey: configKey) }
        persist()
    }

    private func rememberEnded(_ id: UUID) {
        var ids = defaults.stringArray(forKey: endedKey) ?? []
        ids.removeAll { $0 == id.uuidString }
        ids.append(id.uuidString)
        defaults.set(Array(ids.suffix(20)), forKey: endedKey)
    }

    private func merge(_ incoming: LiveSession) {
        guard incoming.endedAt == nil, !(defaults.stringArray(forKey: endedKey) ?? []).contains(incoming.id.uuidString) else { return }
        if let current = session, !current.owns(sessionId: incoming.id), !incoming.owns(sessionId: current.id), !current.overlaps(incoming) { return }
        let merged = session
            .map { $0.owns(sessionId: incoming.id) || incoming.owns(sessionId: $0.id) ? $0.merging(incoming) : $0.absorbing(incoming) } ?? incoming
        session = merged.endedAt == nil ? merged : nil
        persist()
    }

    private func publish(_ event: any ConnectivityMessage) {
        send(event, .reliable); publishState()
    }

    private func publishState() {
        persist(); send(SessionStateMessage(session: session), .context)
    }

    private func persist() {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: sessionKey)
        } else {
            defaults.removeObject(forKey: sessionKey)
        }
        let name = kinds.first(where: { $0.id == session?.currentKindId })?.name ?? ""
        SessionSnapshotStore.write(SessionSnapshot(session: session, kindName: name))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
