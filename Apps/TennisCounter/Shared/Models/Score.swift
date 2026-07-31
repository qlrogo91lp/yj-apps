import Foundation

enum PlayerSide {
    case me, opponent
}

class Score: ObservableObject {
    enum GameMode: Equatable {
        case normal
        case tieBreak
    }

    fileprivate enum NormalState: Equatable {
        case zero, fifteen, thirty, forty, advantage
    }

    @Published private(set) var gameMode: GameMode = .normal
    @Published private(set) var myTieBreak: Int = 0
    @Published private(set) var yourTieBreak: Int = 0

    private var myNormal: NormalState = .zero
    private var yourNormal: NormalState = .zero

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
        switch gameMode {
        case .normal: addNormalPoint(side)
        case .tieBreak: addTieBreakPoint(side)
        }
    }

    func reset() {
        myNormal = .zero
        yourNormal = .zero
        myTieBreak = 0
        yourTieBreak = 0
        gameMode = .normal
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

    // swiftlint:disable:next cyclomatic_complexity
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

    // MARK: - Snapshot API

    /// Score의 복원 가능한 전체 상태. undo 스택은 ScoreViewModel이 소유하고,
    /// Score는 자기 상태를 봉인해 넘기고 되돌리는 방법만 제공한다.
    /// 멤버가 fileprivate라 다른 파일에서는 내부를 볼 수 없는 불투명 값이다.
    struct Snapshot {
        fileprivate let myNormal: NormalState
        fileprivate let yourNormal: NormalState
        fileprivate let myTieBreak: Int
        fileprivate let yourTieBreak: Int
        fileprivate let gameMode: GameMode
    }

    /// 현재 Score 상태를 불투명한 Snapshot으로 변환해 넘긴다.
    func makeSnapshot() -> Snapshot {
        Snapshot(myNormal: myNormal, yourNormal: yourNormal,
                 myTieBreak: myTieBreak, yourTieBreak: yourTieBreak,
                 gameMode: gameMode)
    }

    /// Snapshot 으로부터 이전 Score 상태를 복원한다.
    func restore(_ snapshot: Snapshot) {
        myNormal = snapshot.myNormal
        yourNormal = snapshot.yourNormal
        myTieBreak = snapshot.myTieBreak
        yourTieBreak = snapshot.yourTieBreak
        gameMode = snapshot.gameMode
        objectWillChange.send()
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
