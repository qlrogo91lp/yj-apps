import Foundation

/// 경기 저장 요청을 보관함에 넣는 좁은 인터페이스. 뷰모델 테스트가 스파이를 넣는다.
@MainActor
protocol MatchSaveEnqueuing {
    func enqueue(_ message: MatchEndMessage)
}

/// 워치가 보낸 경기 저장 요청을 폰의 저장 확인(ACK)을 받을 때까지 보관하고 다시 보낸다.
///
/// 한 번 보내고 잊으면 활성화 전 전송·시스템 단 전송 실패·폰 저장 실패·폰 구버전 중 무엇이든
/// 기록이 사라진다 — 워치 화면은 "전송됨" 인데 폰에는 없다. 그래서 먼저 적고, 보내고,
/// ACK 가 올 때까지 앱 시작·세션 활성화·연결 복귀 때 다시 보낸다.
/// 폰 저장이 `matchId` upsert 라 같은 경기가 여러 번 도착해도 기록은 하나다.
///
/// 저장 형식: `defaults` 의 `"pendingMatchSaves"` 에 `[[String: Any]]`.
/// 각 원소는 `"payload"`(= `MatchEndMessage.toSaveDictionary()`)와, `send` 가 실제로 보냈을 때만 적는
/// `"lastSentAt"`(epoch 초) 를 갖는다.
@MainActor
final class MatchSaveOutbox: MatchSaveEnqueuing {
    static let storageKey = "pendingMatchSaves"

    private enum EntryKey {
        static let payload = "payload"
        static let lastSentAt = "lastSentAt"
    }

    private typealias Entry = [String: Any]

    private let defaults: UserDefaults
    private let send: (MatchEndMessage) -> Bool
    private let now: () -> Date
    private let resendInterval: TimeInterval
    private let maxAge: TimeInterval

    /// - Parameter send: WCSession 전송 API 를 실제로 불렀으면 `true`. `false` 면 보낸 것으로 치지 않는다.
    init(defaults: UserDefaults,
         send: @escaping (MatchEndMessage) -> Bool,
         now: @escaping () -> Date = Date.init,
         resendInterval: TimeInterval = 60,
         maxAge: TimeInterval = 14 * 24 * 3600)
    {
        self.defaults = defaults
        self.send = send
        self.now = now
        self.resendInterval = resendInterval
        self.maxAge = maxAge
    }

    /// 보관 중인 경기의 matchId. 테스트와 진단용.
    var pendingMatchIds: [UUID] {
        loadEntries().compactMap { Self.message(in: $0)?.matchId }
    }

    /// 보관함에 적고 바로 한 번 보낸다. matchId 가 없는 메시지는 보관하지 않고 보내기만 한다 —
    /// ACK 로 지울 키가 없다.
    func enqueue(_ message: MatchEndMessage) {
        guard let matchId = message.matchId else {
            _ = send(message)
            return
        }
        // 같은 경기(재시도 버튼)는 교체한다. 보내기 전에 먼저 적는다 — 보내는 도중 앱이 죽어도 남는다.
        var entries = loadEntries().filter { Self.message(in: $0)?.matchId != matchId }
        entries.append([EntryKey.payload: message.toSaveDictionary()])
        saveEntries(entries)

        guard send(message) else { return }
        let sentAt = now().timeIntervalSince1970
        saveEntries(loadEntries().map { entry in
            guard Self.message(in: entry)?.matchId == matchId else { return entry }
            var updated = entry
            updated[EntryKey.lastSentAt] = sentAt
            return updated
        })
    }

    /// success 면 항목을 지운다 — matchId 가 있으면 그 경기 하나, 없으면(구버전 폰) 같은 sessionId 전부.
    /// 실패 ACK 는 항목을 남기고 마지막 전송 시각을 지워 다음 flush 에서 다시 보내게 한다.
    func acknowledge(_ result: MatchSaveResultMessage) {
        let isTarget: (Entry) -> Bool = { entry in
            guard let message = Self.message(in: entry) else { return false }
            if let matchId = result.matchId { return message.matchId == matchId }
            return message.sessionId == result.sessionId
        }
        let entries = loadEntries()
        guard entries.contains(where: isTarget) else { return }
        if result.success {
            saveEntries(entries.filter { !isTarget($0) })
        } else {
            saveEntries(entries.map { entry in
                guard isTarget(entry) else { return entry }
                var updated = entry
                updated[EntryKey.lastSentAt] = nil
                return updated
            })
        }
    }

    /// endedAt 이 maxAge 를 넘긴 항목과 읽을 수 없는 항목을 버린다. 남은 것 중 한 번도 못 보냈거나
    /// 마지막 전송 후 resendInterval 이 지난 항목을 다시 보낸다.
    func flush() {
        let current = now()
        var kept: [Entry] = []
        for entry in loadEntries() {
            guard let message = Self.message(in: entry),
                  current.timeIntervalSince(message.endedAt) <= maxAge else { continue }
            guard Self.isDue(entry, at: current, interval: resendInterval), send(message) else {
                kept.append(entry)
                continue
            }
            var updated = entry
            updated[EntryKey.lastSentAt] = current.timeIntervalSince1970
            kept.append(updated)
        }
        saveEntries(kept)
    }

    // MARK: - Storage

    /// 원소 하나가 깨져도 배열 전체를 버리지 않는다 — `as? [[String: Any]]` 로 한 번에 캐스팅하면
    /// 원소 하나 때문에 모든 기록을 잃는다.
    private func loadEntries() -> [Entry] {
        (defaults.array(forKey: Self.storageKey) ?? []).compactMap { $0 as? Entry }
    }

    private func saveEntries(_ entries: [Entry]) {
        defaults.set(entries, forKey: Self.storageKey)
    }

    /// matchId 가 없는 항목도 읽을 수 없는 것으로 본다 — enqueue 가 그런 항목을 만들지 않으므로 손상이다.
    private static func message(in entry: Entry) -> MatchEndMessage? {
        guard let payload = entry[EntryKey.payload] as? [String: Any],
              let message = MatchEndMessage(from: payload),
              message.matchId != nil else { return nil }
        return message
    }

    private static func isDue(_ entry: Entry, at current: Date, interval: TimeInterval) -> Bool {
        guard let lastSentAt = entry[EntryKey.lastSentAt] as? Double else { return true }
        return current.timeIntervalSince1970 - lastSentAt >= interval
    }
}
