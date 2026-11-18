# YJ-45 — iOS 타이브레이크 점수 수동 수정

상태: 구현 완료 — PR #82 (`🐛 fix: 타이브레이크 수동 점수 수정`)로 머지.
이슈: https://linear.app/yj-workpace/issue/YJ-45

## 목표와 원인

iPhone이 점수 입력 담당(driver)일 때 점수 영역을 길게 눌러 연 수정 시트의 +/−가 현재 화면에 보이는 점수를 변경한다.
현재 표시는 `Score.myDisplayScore`로 모드를 구분하지만 버튼은 항상 `myIndex`/`yourIndex`(일반 포인트)만 바꾼다.
타이브레이크에서는 표시가 그대로인데 `applyManualEdit()`가 undo 스택까지 지운다.
Watch에는 수정 시트가 없으므로 Watch UI 추가나 일반 undo 동작 변경은 범위 밖이다.

## 동작 결정

- 일반 모드는 기존 0·15·30·40·AD 수동 수정 범위를 유지한다. 일반 게임에서 +로 자동 게임 승리를 추가하지 않는다.
- 타이브레이크는 실제 TB 점수를 1씩 증감한다. 0 아래로 내려가지 않는다.
- 7점 세트 TB·10점 매치 TB 모두 지원하고 목표 점수 + 2점 차를 기존 경기 판정과 동일하게 적용한다.
- TB의 +로 승리 조건이 충족되면 일반 득점과 같은 게임/세트/경기 종료·완료 세트 저장·동기화 경로를 탄다.
- TB 종료로 모드나 경기 단계가 바뀌면 수정 시트를 닫는다. 새 게임의 점수가 같은 시트에서 연이어 수정되지 않아야 한다.
- 실제 변경이 있는 수동 수정은 새 기준점이므로 undo 이력을 지운다(기존 정책 유지).
- 0에서 −, 일반 모드 최대값에서 + 같은 no-op은 undo 이력·동기화 콜백을 건드리지 않는다.
- 수동 수정은 일반 탭의 undo 직후 0.4초 득점 차단에 우연히 막히지 않아야 한다.
- mirror 기기는 수정할 수 없다. wire format·SwiftData 스키마·저장된 기록은 변경하지 않는다.

## 변경 파일과 작업

### Task 1 — 재현 테스트와 모드별 수정 경로

- Modify: `Apps/TennisCounter/Shared/Models/Score.swift`
  - 일반/TB 모드의 수동 수정에 필요한 모델 API를 정의한다. private TB 필드를 UI에 공개하지 않는다.
  - 변경 여부와 TB 승자를 호출부가 판단할 수 있도록 최소한의 결과를 반환한다.
  - 기존 `addPoint`의 TB 목표·2점차 판정을 재사용해 별도 규칙이 갈라지지 않게 한다.
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift`
  - side와 증감 방향을 받는 수동 수정 진입점을 둔다.
  - 모델 변경·undo 초기화·TB 완료 처리를 책임진다. 승리 시 기존 finalize/checkSetUpdate 경로와 공통화한다.
  - UI에서 score를 직접 바꾼 뒤 알리는 기존 경로의 호출자를 모두 확인한다.
- Modify: `Apps/TennisCounter/iosTests/Shared/ScoreTests.swift`
- Modify: `Apps/TennisCounter/iosTests/WorkoutSession/Match/ScoreViewModelTests.swift`
  - 먼저 실제 수정 진입점에 대한 실패 테스트를 실행하고 구현한다. 기존 일반 수동 수정 테스트는 새 경로에 맞춰 갱신한다.

핵심 테스트:
1. TB 중 양쪽 +/−가 TB 표시 점수를 바꾸고 일반 포인트를 건드리지 않는다.
2. 0에서 −와 일반 포인트 상한 +는 no-op이며 undo 이력을 보존한다.
3. 실제 수정 후 기존 undo 이력은 지워지고, 다음 일반 득점부터 undo가 다시 정상 동작한다.
4. 7점 TB의 6:5→7:5에서 세트가 정상 종료된다. 6:6→7:6은 진행을 유지한다.
5. 10점 매치 TB의 9:8→10:8에서 경기 종료·완료 세트 점수가 정상이다. 9:9→10:9는 진행을 유지한다.
6. 상대 +로 상대가 승리하는 경우도 같은 규칙을 따른다.
7. 일반 게임 수동 수정은 기존 범위와 동작을 유지한다.
8. undo 직후 수동 수정이 일반 득점 차단에 막히지 않는다.
9. 실제 수정 시 onStateChanged가 수정 완료 상태를 보내고, no-op에는 보내지 않는다.

### Task 2 — 수정 시트 연결

- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/Components/ScoreEditSheet.swift`
  - 버튼이 일반 점수 필드를 직접 변경하지 않고 부모의 수동 수정 이벤트를 호출하게 한다.
  - 값은 아래로, 이벤트는 위로 보낸다. 컴포넌트에 ViewModel을 주입하지 않는다.
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreView.swift`
  - 표시값·버튼 콜백을 ViewModel의 새 경로에 연결한다.
  - TB 종료/경기 종료 시 시트를 닫는 동작과 기존 driver guard를 확인한다.

## 검증

명령은 저장소 루트에서 실행하며 `.github/scripts/pick-simulator.sh`의 UDID를 사용한다.

- 변경 테스트 RED→GREEN 후 `TennisCounter` iOS 전체 테스트
- 공유 Score 모델을 바꾸므로 `TennisCounter Watch App` + `-only-testing:RalliWatchTests` 전체 회귀
- `TennisLiveActivityExtension` iOS 빌드, `RalliComplicationExtension` Watch 빌드
- `make lint`, `make format`, `git diff --check`
- 시뮬레이터에서 일반/TB 시트의 표시 갱신, TB 종료 시 시트 닫힘, mirror 수정 불가 확인. 수동 확인을 못 하면 미실행으로 보고한다.
- 변경에 대해 독립 리뷰를 받고 중요한 지적을 해결한다.

## 구현 인계 조건

- 루트 및 앱 CLAUDE.md를 먼저 읽는다. 현재 main 기준 a5e4243 이후 변경 여부를 확인한다.
- 사용자는 작은 수정이면 바로 구현, 그보다 크면 플랜 작성 후 다른 세션 구현을 허용했다. 이 플랜을 실행할 때 재승인 질문을 반복하지 않는다.
- 코드 작업은 main에 하지 않는다. 기존 적절한 트랙을 재사용하거나 형제 경로 `../yj-apps-worktrees/<branch-leaf>`에 격리한다.
- 로컬 `.mcp.json`과 다른 트랙 파일은 건드리지 않는다.
- 커밋·푸시·PR·머지는 이번 요청에서 별도 지시받지 않았으므로 검증 결과와 변경만 사용자 검토용으로 남긴다.
- 플랜이 커밋·공유될 때 기존 YJ-45에 유효한 GitHub 문서 링크를 연결한다. 로컬 작성 상태를 배포된 링크로 보고하지 않는다.
