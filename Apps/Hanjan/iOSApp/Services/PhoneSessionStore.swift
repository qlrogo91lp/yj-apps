import Combine
import ConnectivityCore
import Foundation

@MainActor final class PhoneSessionStore: ObservableObject {
    @Published private(set) var session: LiveSession? {
        didSet {
            if let session, let data = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(data, forKey: "phoneLiveSession")
            } else {
                UserDefaults.standard.removeObject(forKey: "phoneLiveSession")
            }
        }
    }

    var onChange: ((LiveSession?) -> Void)?
    private let connectivity: ConnectivityService
    private let archive: SessionArchive
    private let settings: AppSettings
    private let now: () -> Date
    private let location = PhoneLocationService()
    private let notifier = LimitNotifier()
    private let reminder = ReviewReminder()
    private var pending = PendingEntries()

    init(connectivity: ConnectivityService, archive: SessionArchive, settings: AppSettings, now: @escaping () -> Date = Date.init) {
        self.connectivity = connectivity; self.archive = archive; self.settings = settings; self.now = now
        session = UserDefaults.standard.data(forKey: "phoneLiveSession").flatMap { try? JSONDecoder().decode(LiveSession.self, from: $0) }
        connectivity.onReceive(SessionStartMessage.self) { [weak self] in self?.receive($0.session) }
        connectivity.onReceive(SessionStateMessage.self) { [weak self] in if let value = $0.session { self?.receive(value) } }
        connectivity.onReceive(EntryAddMessage.self) { [weak self] in self?.receiveEntry($0.entry) }
        connectivity.onReceive(EntryRemoveMessage.self) { [weak self] in self?.receiveRemoval(sessionId: $0.sessionId, entryId: $0.entryId) }
        connectivity.onReceive(SessionEndMessage.self) { [weak self] in self?.receiveEnd($0) }
    }

    var kinds: [DrinkKind] {
        (try? archive.kinds()).flatMap { $0.isEmpty ? nil : $0 } ?? DrinkPresets.all
    }

    func start() {
        guard session == nil else { return }
        let value = LiveSession(id: UUID(), startedAt: now(), limit: settings.limit, currentKindId: kinds.first?.id ?? DrinkPresets.soju.id)
        session = value
        connectivity.send(SessionStartMessage(session: value), via: .reliable)
        changed(previous: .normal)
        location.request { [weak self] latitude, longitude in
            guard let self, var current = session, current.id == value.id else { return }
            current.latitude = latitude; current.longitude = longitude; session = current
            changed(previous: level(current))
        }
    }

    func tapMain() {
        guard var current = session else { return }
        let before = level(current)
        let kind = kinds.first { $0.id == current.currentKindId } ?? DrinkPresets.soju
        let entry = current.makeEntry(id: UUID(), at: now(), kind: kind, source: .phone)
        current.ledger.add(entry); session = current
        connectivity.send(EntryAddMessage(entry: entry), via: .reliable)
        changed(previous: before)
    }

    func undo() {
        guard var current = session, let last = current.ledger.last else { return }
        let before = level(current); current.ledger.remove(id: last.id); session = current
        connectivity.send(EntryRemoveMessage(sessionId: current.id, entryId: last.id), via: .reliable)
        changed(previous: before)
    }

    func cycleToast() {
        guard var current = session else { return }
        let next: Int? = current.toast.every == nil ? 2 : (current.toast.every == 2 ? 3 : nil)
        current.setToast(every: next, at: now()); session = current; changed(previous: level(current))
    }

    func selectKind(_ id: UUID) {
        guard var current = session, kinds.contains(where: { $0.id == id }) else { return }
        current.currentKindId = id; session = current; changed(previous: level(current))
    }

    func end() {
        finish(at: now())
    }

    func tick() {
        if let current = session, current.shouldAutoEnd(now: now()) { finish(at: current.lastActivityAt) }
    }

    func pushConfig() {
        connectivity.send(ConfigMessage(kinds: kinds, limit: settings.limit), via: .context)
    }

    private func finish(at date: Date) {
        guard var current = session else { return }
        current.endedAt = date
        connectivity.send(SessionEndMessage(sessionId: current.id, endedAt: date), via: .reliable)
        save(current); if settings.alertsEnabled { reminder.schedule(sessionId: current.id, endedAt: date) }
        session = nil; connectivity.send(SessionStateMessage(session: nil), via: .context); onChange?(nil)
    }

    private func level(_ session: LiveSession) -> LimitLevel {
        .of(equivalent: session.ledger.sojuEquivalent(), limit: session.limit)
    }

    private func save(_ value: LiveSession) {
        do { try archive.save(value) } catch { NSLog("한잔 저장 실패: %@", String(describing: error)) }
    }

    private func changed(previous: LimitLevel) {
        guard let value = session else { return }
        connectivity.send(SessionStateMessage(session: value), via: .context)
        save(value)
        if settings.alertsEnabled, let crossed = LimitLevel.crossed(from: previous, to: level(value)) { notifier.notify(crossed) }
        onChange?(value)
    }

    func receive(_ incoming: LiveSession) {
        var incoming = incoming
        pending.merge(into: &incoming)
        if let record = try? archive.record(owning: incoming.id), record.endedAt != nil {
            save(incoming); return
        }
        if let endedAt = incoming.endedAt, !(session?.owns(sessionId: incoming.id) ?? false),
           !(session.map { incoming.owns(sessionId: $0.id) } ?? false)
        {
            save(incoming)
            if settings.alertsEnabled { reminder.schedule(sessionId: incoming.id, endedAt: endedAt) }
            return
        }
        let old = session
        let before = old.map(level) ?? .normal
        if let current = session {
            session = current.owns(sessionId: incoming.id) || incoming.owns(sessionId: current.id)
                ? current.merging(incoming) : current.absorbing(incoming)
        } else { session = incoming }
        if session == old { return }
        if let ended = session?.endedAt { finish(at: ended) } else { changed(previous: before) }
    }

    private func receiveEntry(_ entry: DrinkEntry) {
        if var current = session, current.owns(sessionId: entry.sessionId) {
            let before = level(current); let old = current.ledger; current.ledger.add(entry)
            guard old != current.ledger else { return }; session = current; changed(previous: before); return
        }
        if !updateArchived(id: entry.sessionId, mutate: { $0.add(entry) }) { pending.add(entry) }
    }

    private func receiveRemoval(sessionId: UUID, entryId: UUID) {
        if var current = session, current.owns(sessionId: sessionId) {
            let before = level(current); let old = current.ledger; current.ledger.remove(id: entryId)
            guard old != current.ledger else { return }; session = current; changed(previous: before); return
        }
        if !updateArchived(id: sessionId, mutate: { $0.remove(id: entryId) }) { pending.remove(entryId, sessionId: sessionId) }
    }

    private func updateArchived(id: UUID, mutate: (inout DrinkLedger) -> Void) -> Bool {
        guard let record = try? archive.record(owning: id) else { return false }
        var ledger = record.ledger; mutate(&ledger)
        let value = LiveSession(id: record.id, startedAt: record.startedAt, endedAt: record.endedAt, limit: record.limit,
                                currentKindId: DrinkPresets.soju.id, latitude: record.latitude, longitude: record.longitude,
                                ledger: ledger, mergedSessionIds: record.mergedSessionIds)
        save(value)
        return true
    }

    private func receiveEnd(_ message: SessionEndMessage) {
        if let current = session, current.owns(sessionId: message.sessionId) { finish(at: message.endedAt); return }
        guard let record = try? archive.record(owning: message.sessionId) else {
            pending.end(sessionId: message.sessionId, at: message.endedAt)
            return
        }
        guard record.endedAt == nil else { return }
        let value = LiveSession(id: record.id, startedAt: record.startedAt, endedAt: message.endedAt, limit: record.limit,
                                currentKindId: DrinkPresets.soju.id, ledger: record.ledger, mergedSessionIds: record.mergedSessionIds)
        save(value)
    }
}
