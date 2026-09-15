import SwiftUI

struct ScoreView: View {
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @ObservedObject var viewModel: ScoreViewModel
    @State private var showExitConfirm = false
    /// 크라운이 딸깍 걸릴 때마다 1 씩 바뀌는 값. 절대값에는 의미가 없다 — 변화량만 본다.
    @State private var crownDetent = 0.0
    /// 한 번 돌리기에 최대 1점 — 여러 칸이 뛰어도 크라운이 멈출 때까지 잠근다.
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
        // 디텐트 방식 — 시스템이 "한 칸"을 정해 주므로 회전량 단위를 추측하지 않는다.
        // 회전량을 직접 재던 앞선 구현들은 한 번에 4점이 들어가거나 몇 바퀴를 돌려야 1점이었다.
        .digitalCrownRotation(
            detent: $crownDetent,
            from: -1000, through: 1000, by: 1,
            sensitivity: .low, // 한 칸에 필요한 회전이 가장 큰 단계 — 손목이 스쳐도 안 걸리게
            isContinuous: false, // true 면 범위 끝에서 반대편으로 감겨 상대 포인트가 잘못 들어간다
            isHapticFeedbackEnabled: false, // 포인트 햅틱은 MatchHaptics 가 울린다 — 두 번 울리지 않게
            onIdle: { crownGate.idle() }
        )
        .onChange(of: crownDetent) { _, value in
            // 버튼과 같은 가드 — mirror 는 점수를 넣을 권한이 없다.
            guard flowViewModel.isDriver, case .playing = flowViewModel.phase else { return }
            if let side = crownGate.detentChanged(to: value) {
                viewModel.addPoint(side)
            }
        }
        // 크라운을 돌리면 화면 가장자리에 스크롤 바가 뜬다 — 점수 화면엔 스크롤할 게 없다.
        .digitalCrownAccessory(.hidden)
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
