import SwiftUI

struct ScoreView: View {
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @ObservedObject var viewModel: ScoreViewModel
    @State private var showExitConfirm = false
    /// 크라운 회전 누적. ±1 디텐트를 넘으면 포인트 하나로 바꾸고 0 으로 되돌린다 —
    /// 스침(1 미만)은 점수가 되지 않는다.
    @State private var crownAccumulator = 0.0
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
            $crownAccumulator,
            from: -1000, through: 1000, by: 1,
            sensitivity: .medium,
            isContinuous: false, // true 면 범위 끝에서 반대편으로 감겨 상대 포인트가 잘못 들어간다
            isHapticFeedbackEnabled: false // 포인트 햅틱은 MatchHaptics 가 울린다 — 두 번 울리지 않게
        )
        .onChange(of: crownAccumulator) { _, value in
            // 버튼과 같은 가드 — mirror 는 점수를 넣을 권한이 없다.
            guard flowViewModel.isDriver else { crownAccumulator = 0; return }
            if value >= 1 {
                for _ in 0 ..< Int(value) {
                    guard case .playing = flowViewModel.phase else { break }
                    viewModel.addPoint(.me)
                }
                crownAccumulator = 0
            } else if value <= -1 {
                for _ in 0 ..< Int(abs(value)) {
                    guard case .playing = flowViewModel.phase else { break }
                    viewModel.addPoint(.opponent)
                }
                crownAccumulator = 0
            }
        }
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
