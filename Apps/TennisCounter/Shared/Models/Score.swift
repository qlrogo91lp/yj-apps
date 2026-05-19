import Foundation

enum PlayerSide {
    case me, opponent
}

enum LastAction {
    case myPoint
    case opponentPoint
    case none
}

class Score: ObservableObject {
    enum GameMode: Equatable {
        case normal
        case tieBreak
    }

    private enum NormalState: Equatable {
        case zero, fifteen, thirty, forty, advantage
    }

    private struct SnapShot {
        let myNormal: NormalState
        let yourNormal: NormalState
        let myTieBreak: Int
        let yourTieBreak: Int
        let gameMode: GameMode
    }

    @Published private(set) var gameMode: GameMode = .normal
    @Published private(set) var lastAction: LastAction = .none
    @Published private(set) var myTieBreak: Int = 0
    @Published private(set) var yourTieBreak: Int = 0

    private var myNormal: NormalState = .zero
    private var yourNormal: NormalState = .zero
    private var snapshot: SnapShot?

    var noAdRule: Bool = true

    /// Display text for the score pad
    var myDisplayScore: String {
        switch gameMode {
        case .normal: text(for: myNormal)
        case .tieBreak: "\(myTieBreak)"
        }
    }

    var yourDisplayScore: String {
        switch gameMode {
        case .normal: text(for: yourNormal)
        case .tieBreak: "\(yourTieBreak)"
        }
    }

    /// Returns the winning side if the game ends, nil otherwise
    @discardableResult
    func addPoint(_ side: PlayerSide) -> PlayerSide? {
        snapshot = SnapShot(myNormal: myNormal, yourNormal: yourNormal,
                            myTieBreak: myTieBreak, yourTieBreak: yourTieBreak,
                            gameMode: gameMode)
        lastAction = side == .me ? .myPoint : .opponentPoint

        switch gameMode {
        case .normal: return addNormalPoint(side)
        case .tieBreak: return addTieBreakPoint(side)
        }
    }

    func undo() {
        guard let s = snapshot else { return }
        myNormal = s.myNormal
        yourNormal = s.yourNormal
        myTieBreak = s.myTieBreak
        yourTieBreak = s.yourTieBreak
        gameMode = s.gameMode
        lastAction = .none
        snapshot = nil
        objectWillChange.send()
    }

    func reset() {
        myNormal = .zero
        yourNormal = .zero
        myTieBreak = 0
        yourTieBreak = 0
        gameMode = .normal
        lastAction = .none
        snapshot = nil
        objectWillChange.send()
    }

    func setTieBreakMode() {
        gameMode = .tieBreak
        myTieBreak = 0
        yourTieBreak = 0
        objectWillChange.send()
    }

    /// True when both at 40 and noAdRule is OFF (standard deuce) — show DEUCE label
    var isDeuce: Bool {
        gameMode == .normal && myNormal == .forty && yourNormal == .forty && !noAdRule
    }

    private func addNormalPoint(_ side: PlayerSide) -> PlayerSide? {
        if side == .me {
            switch myNormal {
            case .zero: myNormal = .fifteen
            case .fifteen: myNormal = .thirty
            case .thirty: myNormal = .forty
            case .forty:
                if yourNormal == .advantage {
                    yourNormal = .forty // back to deuce
                } else if yourNormal == .forty {
                    if noAdRule { return .me } else { myNormal = .advantage }
                } else {
                    return .me
                }
            case .advantage:
                return .me
            }
        } else {
            switch yourNormal {
            case .zero: yourNormal = .fifteen
            case .fifteen: yourNormal = .thirty
            case .thirty: yourNormal = .forty
            case .forty:
                if myNormal == .advantage {
                    myNormal = .forty // back to deuce
                } else if myNormal == .forty {
                    if noAdRule { return .opponent } else { yourNormal = .advantage }
                } else {
                    return .opponent
                }
            case .advantage:
                return .opponent
            }
        }
        objectWillChange.send()
        return nil
    }

    private func addTieBreakPoint(_ side: PlayerSide) -> PlayerSide? {
        if side == .me { myTieBreak += 1 } else { yourTieBreak += 1 }
        let diff = abs(myTieBreak - yourTieBreak)
        if myTieBreak >= 7, diff >= 2 { return .me }
        if yourTieBreak >= 7, diff >= 2 { return .opponent }
        return nil
    }

    private func text(for state: NormalState) -> String {
        switch state {
        case .zero: "0"
        case .fifteen: "15"
        case .thirty: "30"
        case .forty: "40"
        case .advantage: "AD"
        }
    }

    // MARK: - iOS Backward Compatibility

    // scoreArr index 0-4 maps to zero/fifteen/thirty/forty/advantage; 50 signals game win.

    private static let normalStates: [NormalState] = [.zero, .fifteen, .thirty, .forty, .advantage]
    private static let scoreValues = [0, 15, 30, 40, 50]

    var myScore: Int {
        Self.scoreValues[myIndex]
    }

    var yourScore: Int {
        Self.scoreValues[yourIndex]
    }

    var myIndex: Int {
        get { Self.normalStates.firstIndex(of: myNormal) ?? 0 }
        set {
            guard newValue >= 0, newValue < Self.normalStates.count else { return }
            myNormal = Self.normalStates[newValue]
            objectWillChange.send()
        }
    }

    var yourIndex: Int {
        get { Self.normalStates.firstIndex(of: yourNormal) ?? 0 }
        set {
            guard newValue >= 0, newValue < Self.normalStates.count else { return }
            yourNormal = Self.normalStates[newValue]
            objectWillChange.send()
        }
    }

    func resetData() {
        reset()
    }

    func applyRemote(myScore: Int, yourScore: Int, isTieBreak: Bool) {
        snapshot = nil
        lastAction = .none
        if isTieBreak {
            gameMode = .tieBreak
            myTieBreak = myScore
            yourTieBreak = yourScore
        } else {
            gameMode = .normal
            let myIdx = Self.scoreValues.firstIndex(of: myScore) ?? 0
            let yourIdx = Self.scoreValues.firstIndex(of: yourScore) ?? 0
            myNormal = Self.normalStates[myIdx]
            yourNormal = Self.normalStates[yourIdx]
        }
        objectWillChange.send()
    }
}
