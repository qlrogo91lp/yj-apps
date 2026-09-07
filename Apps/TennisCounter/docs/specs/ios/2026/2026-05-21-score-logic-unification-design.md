# 스코어 로직 통일 및 게임 임계값 설계

**날짜**: 2026-05-21  
**범위**: iOS + Watch 공통

---

## 배경

iOS와 Watch의 `ScoreViewModel`이 동일한 책임(세트 완료 판정, 타이브레이크 전환)을 다른 구현으로 처리하고 있어 버그가 이원화됨. 버그 2개 발견, 무승부(draw) 경로 미완성 상태.

---

## 확인된 버그

| 위치 | 증상 | 재현 조건 |
|------|------|-----------|
| iOS `isSetComplete():134` | 7-6에서 세트 종료 오판정 | `noTieRule=true`에서 6-6 → 7-6 |
| Watch `checkSetUpdate():96` | 6-5에서 세트 종료 오동작 | `noTieRule=true`에서 5-5 → 6-5 |

---

## 변경 목록

### 1. `MatchOptions` — `gameThreshold` 추가

```swift
struct MatchOptions {
    let mode: MatchFormat
    let noAdRule: Bool
    let noTieRule: Bool
    let gameThreshold: Int  // 5 또는 6, 기본값 6
}
```

`ModeViewModel`에서 `@Published` + `UserDefaults`로 마지막 설정값을 저장/복원:

```swift
class ModeViewModel: ObservableObject {
    @Published var noAdRule: Bool {
        didSet { UserDefaults.standard.set(noAdRule, forKey: "lastNoAdRule") }
    }
    @Published var noTieRule: Bool {
        didSet { UserDefaults.standard.set(noTieRule, forKey: "lastNoTieRule") }
    }
    @Published var gameThreshold: Int {
        didSet { UserDefaults.standard.set(gameThreshold, forKey: "lastGameThreshold") }
    }
    @Published var selectedMode: MatchFormat {
        didSet { UserDefaults.standard.set(selectedMode.rawValue, forKey: "lastSelectedMode") }
    }

    init() {
        let ud = UserDefaults.standard
        noAdRule       = ud.object(forKey: "lastNoAdRule") as? Bool ?? true
        noTieRule      = ud.object(forKey: "lastNoTieRule") as? Bool ?? false
        gameThreshold  = ud.object(forKey: "lastGameThreshold") as? Int ?? 6
        selectedMode   = MatchFormat(rawValue: ud.string(forKey: "lastSelectedMode") ?? "") ?? .oneSet
    }
}
```

**동작 원리:**

- `didSet`: 프로퍼티에 새 값이 할당된 직후 자동 호출 → UserDefaults에 즉시 저장
- `init`: 앱 시작 시 UserDefaults에서 마지막 저장값 복원 → 없으면 기본값 사용
- `UserDefaults.standard`: 앱별 샌드박스에 `.plist`로 저장되는 싱글톤. iOS 앱과 Watch 앱은 각자 독립된 저장소를 가짐

**전체 흐름:**

```
앱 시작 → init() → UserDefaults 복원 → ViewModel에 세팅
ModeView 열림 → ViewModel 값으로 Picker/Toggle UI 자동 채워짐
사용자가 설정 변경 → didSet → UserDefaults 저장
포맷 카드 탭 → selectionVM.options 계산 (현재 ViewModel 값 기준)
              → startMatch(options:) 호출
              → SessionStartMessage로 상대 기기에 전송
앱 종료 → UserDefaults는 디스크에 유지
앱 재시작 → init()에서 마지막 설정 복원
```

**iOS-Watch 연계:**

UserDefaults는 기기별로 독립(`App Group` 불필요). 실제 설정 동기화는 매치 시작 시 `SessionStartMessage(options:)` 전송으로 처리됨. UserDefaults 저장은 각 기기의 ModeView를 마지막 선택으로 미리 채우는 편의 기능.

---

### 2. 세트 완료 로직 — iOS/Watch 통일

iOS `isSetComplete()` 제거, Watch `checkSetUpdate()` 방식으로 통일하되 `gameThreshold`를 변수로 사용.

**통일된 규칙:**

```
// 타이브레이크 진행 중
if tieBreakInProgress:
    if (my == T+1 && your == T) || (your == T+1 && my == T):
        tieBreakInProgress = false
        finalizeSet(winner)
    return  // 아직 타이브레이크 중이면 다른 판정 생략

// 임계값(T) 도달 — T:T
if my == T && your == T:
    if noTieRule:
        finishMatch(result: .draw)  // 무승부로 매치 종료
    else:
        score.setTieBreakMode()
        tieBreakInProgress = true
    return

// 일반 세트 승리 (임계값 전)
// max >= T AND 리드 >= 2
if max >= T && (max - min) >= 2:
    finalizeSet(winner)
```

**유효한 승리 점수 예시 (T=6):**

| 게임 점수 | 유효 여부 |
|-----------|-----------|
| 6-0 ~ 6-4 | ✓ |
| 7-5 | ✓ (6-5에서 1게임 더) |
| 6-6 | → 무승부 또는 타이브레이크 |
| 7-6 (타이브레이크 후) | ✓ |

**유효한 승리 점수 예시 (T=5):**

| 게임 점수 | 유효 여부 |
|-----------|-----------|
| 5-0 ~ 5-3 | ✓ |
| 6-4 | ✓ (5-4에서 1게임 더) |
| 5-5 | → 무승부 또는 타이브레이크 |
| 6-5 (타이브레이크 후) | ✓ |

---

### 3. 무승부(Draw) 처리 완성

**현재 상태**: `MatchResult.draw` 모델/UI 준비됨, 실제 트리거 경로 없음.

**변경:**

- Watch `ScoreViewModel`: `noTieRule=true && T:T` 도달 시 `onMatchFinished(.draw, completedSets)` 호출
- iOS `ScoreViewModel`: 동일하게 `.draw` 경로 추가
- iOS `WorkoutSessionViewModel.finishMatch(didWin: Bool, ...)` → `finishMatch(result: MatchResult, ...)` 변경
- iOS `buildSession(from:)`: `msg.result == "win" ? .win : .loss` → `MatchResult(rawValue: msg.result) ?? .loss`

---

### 4. UI — ModeView (iOS + Watch)

기존 토글 행 위에 네이티브 Segmented Picker 추가:

```
포맷 카드 (1세트 / 3세트 매치)
───────────────────────────────
게임 수      [ 5게임 | 6게임 ]
No-AD        [toggle]
No-TIE       [toggle]
```

- `gameThreshold`는 No-tie와 독립적 (4가지 조합 모두 유효)
- Watch도 동일 구조 (ScrollView 내 동일 레이아웃)

---

### 5. 컴포넌트 이름 변경

| 변경 전 | 변경 후 | 플랫폼 |
|---------|---------|--------|
| `PlayerScoreZone` | `PlayerPointZone` | iOS |
| `PlayerScoreButton` | `PlayerPointButton` | Watch |

0, 15, 30, 40은 "Point"이므로 이름 일치.

---

### Best-of-3에서 무승부 처리

T:T 도달 시 무승부는 **해당 세트 스코어에 관계없이 매치 전체를 무승부로 종료**한다.

- 예: Best-of-3에서 1-0으로 앞서다 두 번째 세트가 T:T → 매치 무승부
- 레크리에이션 앱 특성상 "T:T면 합의 종료" 개념으로 단순화
- `completedSets`에는 T:T가 된 세트까지의 기록이 저장됨

---

## 적용 안 되는 조합 (없음)

| gameThreshold | noTieRule | 동작 |
|---|---|---|
| 6 | false | 타이브레이크 at 6:6 (현재 기본) |
| 6 | true | 무승부 at 6:6 |
| 5 | false | 타이브레이크 at 5:5 (단축 세트) |
| 5 | true | 무승부 at 5:5 (단축 세트) |

---

## 테스트 계획

| 테스트 | 검증 내용 |
|--------|-----------|
| `setWinsAt_T6_6to4` | T=6, 6-4에서 세트 종료 |
| `setWinsAt_T6_7to5` | T=6, 7-5에서 세트 종료 (임계값 직전) |
| `tiebreakAt_T6_6to6` | T=6, 6-6에서 타이브레이크 시작 |
| `setWinsAfterTiebreak_T6` | T=6, 타이브레이크 후 7-6 세트 종료 |
| `drawAt_T6_noTie` | T=6 + noTie, 6-6 → 무승부 |
| `setWinsAt_T5_5to3` | T=5, 5-3에서 세트 종료 |
| `setWinsAt_T5_6to4` | T=5, 6-4에서 세트 종료 (임계값 직전) |
| `tiebreakAt_T5_5to5` | T=5, 5-5에서 타이브레이크 시작 |
| `drawAt_T5_noTie` | T=5 + noTie, 5-5 → 무승부 |
| `noEarlyEndAt_T6_6to5_noTie` | T=6 + noTie, 6-5에서 세트 종료 안 됨 (Watch 버그 재현) |
| `noEarlyEndAt_T6_7to6_noTie` | T=6 + noTie, 7-6에서 세트 종료 안 됨 (iOS 버그 재현) |
