# 크라운 포커스 복구와 워크아웃 종료 시각 보존

## 작업일: 2026-09-28

## 증상

### 점수 화면의 크라운이 간헐적으로 반응하지 않는다

워치 점수 화면에서 평소에는 크라운 입력이 되지만, 알림이 화면을 덮었다가 사라진 뒤에는 회전에
반응하지 않는 경우가 있었다. 점수 버튼은 계속 동작했고 화면을 한 번 탭하면 크라운도 즉시
살아났다. mirror 권한이나 `CrownPointGate` 잠금이 아니라 점수 화면이 크라운 포커스를 잃은 증상이다.

### 세션 시간은 맞지만 종료 시각이 늦게 저장된다

9월 23일 기록은 시작 시각이 오후 6:49, 운동 시간이 3시간 9분인데 종료 시각은 오후 11:21로
저장됐다. 시간대로 계산하면 실제 종료는 오후 9:58 전후여야 한다. 기존 기록은 운동 시간과 종료
시각이 서로 다른 순간을 기준으로 만들어지고 있었다.

## 원인

### 포커스 복구 신호가 부족했다

`ScoreView`는 처음 나타날 때와 조기 종료 다이얼로그가 닫힐 때만 `isCrownFocused = true`를
실행했다. 알림이 앱을 잠시 inactive로 만들거나 화면이 저휘도 상태로 바뀌어도 `ScoreView` 자체는
사라지지 않으므로 `onAppear`가 다시 호출되지 않는다. 사용자가 화면을 탭하면 focusable 뷰가
포커스를 되찾기 때문에 크라운이 다시 동작했다.

포커스 값이 false가 될 때마다 즉시 되찾는 방식은 쓰지 않는다. 그렇게 하면 조기 종료
다이얼로그나 옆 탭이 포커스를 가져가야 할 때도 점수 화면이 다시 빼앗을 수 있다.

### HealthKit 종료와 메시지 종료 시각을 다른 순간에 기록했다

`WorkoutSessionService.stopWorkout()`은 `session.end()`를 호출한 뒤 `endCollection`, 통계 수집,
`finishWorkout()`을 기다린다. 워크아웃 세션이 끝난 뒤 손목을 내리면 워치 앱 실행이 멈췄다가
다시 깨어날 수 있다.

Ralli의 `MatchConnectivity.sendWorkoutEnd`는 이 비동기 작업이 모두 끝난 뒤 새 `Date()`를 만들어
메시지의 `endedAt`으로 썼다. 따라서 HealthKit 세션은 이미 끝났지만 Ralli 기록만 다음 앱 활성화
시각으로 밀릴 수 있었다.

## 수정

- `ScoreView`가 `scenePhase == .active`로 돌아올 때 포커스를 다시 요청한다. 알림·제어센터 등이
  사라지고 앱이 다시 활성화되는 경로다.
- `isLuminanceReduced == false`로 돌아올 때도 포커스를 다시 요청한다. 손목을 올려 저휘도 화면에서
  복귀하는 경로다.
- `WorkoutResult`에 optional `endedAt`을 추가했다. 기본값은 `nil`이라 기존 소비자 호출부는
  그대로 컴파일된다.
- `WorkoutSessionService`가 `session.end()` 직후 한 번 만든 `endDate`를 경과시간 계산,
  `endCollection`, `WorkoutResult.endedAt`에 함께 쓴다.
- `MatchConnectivity`는 현재 시각을 새로 만들지 않고 `WorkoutResult.endedAt`을
  `WorkoutEndMessage`에 전달한다.
- YJKit 결과와 Ralli 메시지 매핑에 회귀 테스트를 추가했다.

기존에 저장된 기록은 바꾸지 않는다. 이번 수정은 앞으로 Ralli에서 저장하는 세션에만 적용된다.
GolfCounter는 이미 종료 동작을 시작할 때 시각을 붙들고 있어 같은 수정이 필요 없다. 하루치 핏은
`WorkoutViewModel`에서 `stopWorkout()` 뒤 `Date()`를 만드는 경로가 남아 있으며, 진행 중인 03b 기록
목록 작업 다음 후속 항목으로 `TODO.md`에 남겼다.

## 자동 검증

- `make kit-test KIT_DESTINATION="id=<iOS Simulator UDID>"` — 93개 통과
- `MatchConnectivityTests` — 4개 통과, `WorkoutResult.endedAt` 전달 확인
- `make lint` — GolfCounter 67개, TennisCounter 89개, HaruchiFit 41개 파일 위반 0건
- `TennisCounter Watch App` 빌드 — 통과
- `TennisCounter` 빌드 — 통과
- `HaruchiFit Watch App` 빌드 — 통과. YJKit 필드 추가가 기존 하루치 핏 호출부를 깨지 않음을 확인

## 실기기 확인

- [ ] 점수 화면에서 알림을 받고 닫은 직후, 화면을 탭하지 않아도 첫 크라운 회전이 반영된다.
- [ ] 점수 화면에서 손목을 내렸다 올린 직후, 화면을 탭하지 않아도 첫 크라운 회전이 반영된다.
- [ ] 조기 종료 다이얼로그와 다른 탭이 떠 있는 동안 점수 화면이 포커스를 빼앗지 않는다.
- [ ] 워크아웃을 종료한 직후 손목을 내리고 나중에 앱을 다시 열어도, Ralli 기록의 종료 시각이
      다시 연 시각이 아니라 피트니스 앱의 워크아웃 종료 시각과 일치한다.
- [ ] 폰에서 워크아웃 종료를 지시한 경로에서도 같은 종료 시각이 저장된다.
