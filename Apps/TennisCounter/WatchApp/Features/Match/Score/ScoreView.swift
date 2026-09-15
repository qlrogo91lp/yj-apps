import SwiftUI

struct ScoreView: View {
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @ObservedObject var viewModel: ScoreViewModel
    @State private var showExitConfirm = false
    /// 이번 회전의 누적량. 크라운이 멈추면(`onIdle`) 0 으로 되돌린다.
    @State private var crownOffset = 0.0
    /// 한 번 돌리기에 최대 1점 — 회전량이 아무리 커도 크라운이 멈출 때까지 잠근다.
    @State private var crownGate = CrownPointGate()
    /// 크라운은 포커스를 가진 뷰만 받는다. 탭을 오가거나 다이얼로그를 닫으면 돌아온다는 보장이 없어
    /// 화면이 보일 때마다 직접 잡는다. 잃으면 크라운이 에러 없이 조용히 죽는다.
    @FocusState private var isCrownFocused: Bool

    init(viewModel: ScoreViewModel, flowViewModel: WorkoutSessionViewModel) {
        self.viewModel = viewModel
        self.flowViewModel = flowViewModel
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                PlayerPointButton(
                    displayScore: viewModel.score.myDisplayScore,
                    player: String(localized: "watch_score_me"),
                    color: .green,
                    hasSetScore: viewModel.mySetScore > 0 || viewModel.yourSetScore > 0,
                    action: { guard flowViewModel.isDriver else { return }; viewModel.addPoint(.me) }
                )

                PlayerPointButton(
                    displayScore: viewModel.score.yourDisplayScore,
                    player: String(localized: "watch_score_opp"),
                    color: .orange,
                    hasSetScore: viewModel.mySetScore > 0 || viewModel.yourSetScore > 0,
                    action: { guard flowViewModel.isDriver else { return }; viewModel.addPoint(.opponent) }
                )
            }
            .ignoresSafeArea(.container)

            GeometryReader { geo in
                let isSmall = geo.size.width <= 162
                VStack(spacing: 4) {
                    SetScores(
                        mySetScore: viewModel.mySetScore,
                        yourSetScore: viewModel.yourSetScore
                    )
                    GameScores(
                        myGameScore: viewModel.myGameScore,
                        yourGameScore: viewModel.yourGameScore,
                        isTieBreak: viewModel.score.gameMode == .tieBreak
                    )
                }
                .padding(.top, isSmall ? 24 : 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .bottom) {
                    if !flowViewModel.isDriver {
                        MirrorBadge()
                            .padding(.bottom, isSmall ? 20 : 25)
                    } else if viewModel.canUndo {
                        UndoButton { viewModel.undo() }
                            .padding(.bottom, isSmall ? 20 : 25)
                    }
                }
                .ignoresSafeArea(.container)
                .animation(.easeInOut(duration: 0.2), value: viewModel.canUndo)
            }
        }
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownOffset,
            from: -1000, through: 1000,
            sensitivity: .low, // 가장 둔하게 — 많이 돌려야 점수가 들어간다
            isContinuous: false, // true 면 범위 끝에서 반대편으로 감겨 상대 포인트가 잘못 들어간다
            isHapticFeedbackEnabled: false, // 포인트 햅틱은 MatchHaptics 가 울린다 — 두 번 울리지 않게
            onChange: { event in
                // 버튼과 같은 가드 — mirror 는 점수를 넣을 권한이 없다.
                guard flowViewModel.isDriver, case .playing = flowViewModel.phase else { return }
                if let side = crownGate.rotate(to: event.offset) {
                    viewModel.addPoint(side)
                }
            },
            onIdle: {
                crownGate.idle()
                crownOffset = 0
            }
        )
        .onAppear { isCrownFocused = true }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
                // mirror에게는 눌러도 아무 일 없는 버튼 대신 자리를 비운다 — 워크아웃 탭들과 같은 방식.
                if flowViewModel.isDriver {
                    BackButton {
                        if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
                           viewModel.myGameScore == 0, viewModel.yourGameScore == 0
                        {
                            flowViewModel.startNewMatch()
                        } else {
                            showExitConfirm = true
                        }
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showExitConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                flowViewModel.startNewMatch()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .onChange(of: showExitConfirm) { _, shown in
            if !shown { isCrownFocused = true }
        }
    }
}

#Preview {
    ScoreView(
        viewModel: ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false)),
        flowViewModel: WorkoutSessionViewModel()
    )
}
