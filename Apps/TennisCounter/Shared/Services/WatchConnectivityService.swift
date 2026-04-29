import Combine
import Foundation
import WatchConnectivity

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedScoreUpdate: ScoreUpdate?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendScoreUpdate(_ update: ScoreUpdate) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else { return }
        #endif

        let message = update.toDictionary()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedScoreUpdate = ScoreUpdate(from: message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedScoreUpdate = ScoreUpdate(from: applicationContext)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}

struct ScoreUpdate {
    let myScore: Int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int

    func toDictionary() -> [String: Any] {
        ["my": myScore, "your": yourScore, "myGame": myGameScore, "yourGame": yourGameScore]
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int) {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
    }

    init?(from dict: [String: Any]) {
        guard let my = dict["my"] as? Int,
              let your = dict["your"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int else { return nil }
        myScore = my
        yourScore = your
        myGameScore = myGame
        yourGameScore = yourGame
    }
}
