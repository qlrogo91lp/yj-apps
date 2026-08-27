# 워크아웃 기록 시간 부정확 버그 수정

## 작업일: 2026-05-27

## 문제

피트니스 앱 리스트에서 경기 시간이 정확하지 않게 표시됨. 일시정지 구간이 포함된 벽시계 시간(wall-clock time)을 저장하고 있었음.

## 분석

### 피트니스 앱 리스트 kcal vs 시간 표시 기준

피트니스 앱은 kcal가 의미 있는 값일 때 kcal를 표시하고, 0에 가까우면 시간으로 fallback한다. 테스트용 1초짜리 워크아웃은 kcal ≈ 0이라 시간(0:01)이 표시된 것. 실제 경기 길이(30분~1시간)로 워크아웃을 완료하면 kcal가 쌓여 자동으로 kcal로 표시된다. 코드 문제 아님.

### 시간 부정확 원인 (3곳)

1. **Watch `saveCurrentMatch()`** (`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`)
   - 기존: `Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))` — 일시정지 시간 포함
   - `healthKit.elapsedSeconds`는 타이머가 멈춘 동안 카운트하지 않으므로 정확한 플레이 시간 반영

2. **Watch → iOS 메시지 (`MatchEndMessage`)** (`Shared/Services/WatchConnectivityService.swift`)
   - 기존: 메시지에 `durationSeconds` 필드 없음 → iOS에서 `endedAt - startedAt`으로 재계산
   - `durationSeconds` 필드 추가 후 Watch에서 `healthKit.elapsedSeconds`를 전송

3. **iOS `startTimer()`** (`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`)
   - 기존: `elapsedSeconds = Int(Date().timeIntervalSince(startedAt))` — 일시정지 후 재개 시 paused 구간만큼 값이 점프
   - `pausedAt`, `totalPausedSeconds` 누적 변수를 추가해 정확한 활성 시간 계산

## 변경 파일

- `Shared/Services/WatchConnectivityService.swift` — `MatchEndMessage`에 `durationSeconds: Int` 필드 추가 (`toDictionary`, `init?(from:)`, `init(...)` 모두 업데이트)
- `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `saveCurrentMatch()`: `healthKit.elapsedSeconds` 사용, `sendMatchEndToiOS()`: `durationSeconds` 전달
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `pausedAt`, `totalPausedSeconds` 추가, `pauseSession()`/`resumeSession()` 업데이트, `startTimer()` 정확한 elapsed 계산, `buildMatchFromMessage()` / `buildMatchFromSession()` 수정
