# Summary·History 데이터 무결성 설계

## 작성일: 2026-08-09

## 요약

워크아웃 하나에서 경기를 두 판 이상 하면 **먼저 저장한 경기가 삭제된다.** 중복 제거 키가 경기 단위가 아니라 워크아웃 단위이기 때문이다. 이 데이터 손실이 Summary의 모든 집계와 History의 목록·캘린더에 그대로 반영된다.

같은 저장 경로에 지표 의미가 섞이는 문제도 있다. 칼로리는 경기 구간 차분으로, 시간은 워크아웃 누적값으로 저장돼 한 레코드 안에서 두 지표의 기준이 다르다. 중복 제거를 고치면 이 불일치가 곧바로 드러나 운동 시간이 경기 수만큼 부풀어 오른다. 두 문제는 함께 수정해야 한다.

이 스펙은 **저장되는 값의 정확성**만 다룬다. 집계 표현·화면 동작 문제는 Non-goals에 분리했다.

---

## 1. 현재 문제

### 1-1. 🔴 같은 워크아웃의 두 번째 경기를 저장하면 첫 경기가 삭제된다

**증상**

워크아웃을 켜고 1경기 → 저장 → 새 경기 → 2경기 → 저장 하면, History에 2경기 한 건만 남는다. 1경기는 사라진다. 재경기(rematch)도 같다.

**근본 원인**

중복 제거 키가 `workoutSessionId`다. 이 값은 **워크아웃 식별자**라 워크아웃 안의 모든 경기가 같은 값을 공유한다.

`iOSApp/Services/MatchPersistenceService.swift:32`
```swift
func upsert(_ match: Match) throws {
    if let sid = match.workoutSessionId {
        try store.upsert(match, replacing: #Predicate<Match> { $0.workoutSessionId == sid })
    }
    ...
}
```

`PersistenceService.upsert(_:replacing:)`는 predicate에 걸린 레코드를 **전부 `context.delete`** 한 뒤 삽입한다(`ralli-kit/Sources/PersistenceCore/PersistenceService.swift:26`).

`workoutSessionId`가 경기마다 바뀌지 않는 것은 양쪽 타겟에서 확인된다.

- iOS `WorkoutSessionViewModel.swift:243` — `startNewMatch()`는 `_currentSession`만 비우고 `sessionId`는 유지
- Watch `WorkoutSessionViewModel.swift:13` — `let workoutSessionId: UUID = .init()`, 워크아웃 수명 동안 불변

**중복 제거가 필요한 진짜 이유** (제거하면 안 되는 이유)

1. 폰·워치가 동시에 결과 화면을 띄우므로 양쪽에서 저장 버튼을 누를 수 있다
2. 워치의 저장 재시도 — ack 타임아웃 후 같은 `MatchEndMessage`를 재전송한다 (`WatchApp/.../WorkoutSessionViewModel.swift:247`)

즉 "같은 경기"를 식별하는 키 자체는 필요하다. 문제는 키의 **입도**다.

**영향 범위**

| 화면 | 영향 |
|---|---|
| Summary 경기 수·승·승률 | 워크아웃당 1건만 집계 |
| Summary 운동 시간·칼로리·심박 | 마지막 경기 값만 반영 |
| History 목록 | 워크아웃당 1건만 표시 |
| History 캘린더 | 동일 |

**복구 불가**: 이미 삭제된 레코드는 되살릴 수 없다.

### 1-2. 🟠 `durationSeconds`만 워크아웃 누적값이다

**증상**

경기 상세 시트에 "칼로리 250 / 시간 40분"처럼 **칼로리는 그 경기 것, 시간은 워크아웃 전체 것**이 나란히 뜬다.

**근본 원인**

앱은 경기 시작·종료 시점에 HealthKit 누적값 스냅샷을 찍어 차분을 저장한다. 시간만 **시작 스냅샷을 찍지 않아** 차분을 낼 수 없어 누적값을 그대로 넣고 있다.

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:194` (경기 시작)
```swift
let session = MatchSession(
    workoutSessionId: id,
    options: options,
    kcalAtStart: healthKit.currentCalories,                                       // 찍음
    totalKcalAtStart: healthKit.currentCalories + healthKit.currentBasalCalories  // 찍음
)                                                                                 // elapsed는 안 찍음
```

`:350` (저장)
```swift
calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,   // 차분 → 경기 구간
durationSeconds: healthKit.elapsedSeconds,                  // 누적값 그대로
```

iOS 경로도 동일하다 (`iOSApp/.../WorkoutSessionViewModel.swift:349-351`).

| 지표 | 시작 스냅샷 | 저장값 | 실제 의미 |
|---|---|---|---|
| 활동 칼로리 | `kcalAtStart` ✅ | 차분 | 경기 구간 ✅ |
| 총 칼로리 | `totalKcalAtStart` ✅ | 차분 | 경기 구간 ✅ |
| 평균 심박 | — | HealthKit 구간 쿼리 | 경기 구간 ✅ |
| **경과 시간** | **없음** ❌ | **누적값** | **워크아웃 누적** ❌ |

`healthKit.elapsedSeconds`를 쓴 것 자체는 의도적 결정이었다 — 일시정지 구간을 빼기 위한 것으로, `docs/superpowers/logs/2026-05-27-duration-bug-fix.md`에 기록돼 있다. 당시에는 "워크아웃 1개 = 경기 1개"를 전제했다.

**1-1과의 결합**

지금은 워크아웃당 레코드가 1건뿐이라 이 문제가 가려져 있다. 1-1을 고치면 즉시 드러난다.

워크아웃 60분에 경기 3판(각 20분·20분·20분, 사이 휴식)을 한 경우:

| | Summary "운동 시간" | 실제 |
|---|---|---|
| 지금 (1-1 있음) | 60분 (마지막 경기의 누적값 1건) | 60분 — **우연히 맞음** |
| 1-1만 고친 뒤 | 20+40+60 = **120분** | 60분 |

칼로리는 반대로 샌다. 워크아웃 60분·누적 800kcal, 경기 구간 합 680kcal일 때:

| | Summary "총 칼로리" | 실제 |
|---|---|---|
| 지금 (1-1 있음) | 80kcal (마지막 경기 구간만) | 800kcal |
| 1-1만 고친 뒤 | 680kcal (휴식 120kcal 누락) | 800kcal |

즉 **한쪽은 부풀고 한쪽은 샌다.** 원인은 하나 — 레코드 안에 경기 구간과 워크아웃 누적이 섞여 있고 화면마다 어느 쪽을 쓰는지 정해져 있지 않다.

### 1-3. 🟠 폰이 driver일 때 경기 시작 시각이 워크아웃 시작 시각으로 저장된다

**근본 원인**

iOS의 `startedAt` 프로퍼티는 **워크아웃** 시작 시각인데, 그대로 `MatchSession.startedAt`에 넘긴다.

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:151`
```swift
func startSession(startDate: Date = Date()) { startedAt = startDate }   // 워크아웃 시작
```
`:173`
```swift
_currentSession = MatchSession(
    workoutSessionId: self.sessionId,
    options: options,
    startedAt: startedAt ?? Date(),    // ← 워크아웃 시작 시각을 경기 시작 시각으로
    ...
)
```

워치는 `MatchSession(startedAt: Date())` 기본값을 써서 경기 시작 시각이 맞게 들어간다 (`WatchApp/.../WorkoutSessionViewModel.swift:194`). **두 저장 경로가 서로 다른 값을 넣고 있다.**

**영향**

`startedAt`은 History 정렬 키(`HistoryViewModel.swift:40`), 캘린더 날짜 배치(`HistoryViewModel.swift:68`), Summary 기간 필터(`SummaryViewModel.swift:98`)에 모두 쓰인다. 워크아웃 안 2·3번째 경기가 전부 워크아웃 시작 시각으로 기록되어 정렬이 불안정해지고, 자정을 걸친 워크아웃은 날짜가 어긋난다.

### 1-4. 🟠 `workoutSessionId`가 워크아웃 도중에 바뀔 수 있다

**근본 원인**

워치가 로컬에서 새 경기를 시작하면 `activeSessionId`(폰에서 채택한 값)를 버리고 자기 `workoutSessionId`로 되돌아간다.

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:192`
```swift
let id = sessionId ?? workoutSessionId    // sessionId가 nil이면 activeSessionId를 무시
activeSessionId = id
```

**재현 경로**: 폰이 driver로 1경기 → 워치가 폰의 id를 채택(`activeSessionId = 폰id`) → 워치에서 2경기 시작 → 인자가 nil이라 `id = 워치의 workoutSessionId` → 같은 워크아웃인데 id가 갈린다.

**왜 지금 중요해지는가**

현재는 `workoutSessionId`가 중복 제거와 조회에만 쓰여 영향이 좁다. 이 스펙에서 **Summary의 워크아웃 그룹핑 키**가 되므로, id가 갈리면 누적값을 두 그룹에서 각각 더해 과대 집계된다.

**반대 방향은 안전** — 새 워크아웃이 이전 id를 물려받는 경우는 없다. 폰·워치 모두 `WorkoutSessionViewModel`이 `WorkoutSessionView`의 `@StateObject`이고, iOS는 `endSession()`·`remoteWorkoutEnded` 둘 다 `onExit()`로 뷰를 제거해 VM이 파괴된다 (`WorkoutSessionView.swift:70,89`).

### 1-5. ⚪ 폰 단독 저장 경기는 평균 심박이 항상 nil이다

`iOSApp/.../WorkoutSessionViewModel.swift:344`의 `buildMatchFromSession`이 `averageHeartRate`를 설정하지 않는다. 워치 경로(`buildMatchFromMessage:332`)는 설정한다.

근본 원인은 폰에 HealthKit 워크아웃이 없어서 구간 심박 쿼리를 할 수 없다는 것이다. 완전한 해결은 워치에 구간 심박을 요청하는 왕복이 필요하다. **이 스펙에서는 원인만 기록하고 구현하지 않는다** (Non-goals 참조).

---

## 2. 설계

### 2-1. 데이터 모델

**`Shared/Persistence/Match.swift`** — CloudKit 요구사항에 따라 모두 optional로 추가

```swift
/// 이 경기의 고유 식별자. 폰·워치가 SessionStartMessage로 공유한다. 중복 제거 키.
var matchId: UUID?

/// 워크아웃 시작부터 이 경기 종료 시점까지의 누적값.
/// Summary가 workoutSessionId로 그룹핑해 그룹당 최댓값만 합산한다.
var workoutElapsedSeconds: Int?
var workoutCaloriesBurned: Double?
var workoutTotalCaloriesBurned: Double?
```

`Match.id`(기존 SwiftData 속성)는 재사용하지 않는다. `Identifiable` 식별자와 중복 제거 키를 겸하게 하면 시트 표시·`ForEach` 동일성과 저장 규칙이 엮인다.

**기존 필드 의미 교정** (스키마 변경 없음)

| 필드 | 지금 | 앞으로 |
|---|---|---|
| `durationSeconds` | 워크아웃 누적 ❌ | **경기 구간** = `elapsedAtEnd - elapsedAtStart` |
| `caloriesBurned` | 경기 구간 ✅ | 그대로 |
| `totalCaloriesBurned` | 경기 구간 ✅ | 그대로 |
| `startedAt` | 폰 경로에서 워크아웃 시작 시각 ❌ | **경기 시작 시각** (양쪽 통일) |
| `averageHeartRate` | 경기 구간 (워치 경로만) | 그대로 (1-5는 Non-goal) |

**`Shared/Models/MatchSession.swift`** — `kcalAtStart`와 대칭인 시작 스냅샷 추가

```swift
/// 경기 구간 시간 계산용. elapsed는 일시정지를 제외한 값이라
/// 차분을 내면 일시정지 제외가 그대로 따라온다.
let elapsedAtStart: Int
var elapsedAtEnd: Int?
```

스냅샷 소스는 양쪽 모두 Int다 — 워치는 `healthKit.elapsedSeconds`, 폰은 `elapsedSeconds`(앵커 보간값).

**`Shared/Services/ConnectivityMessages.swift`** — 앱 소유 파일. **RalliKit은 건드리지 않는다.**

```swift
struct SessionStartMessage {
    let sessionId: UUID
    let matchId: UUID?         // 추가 (구버전 페이로드 호환을 위해 optional)
    ...
}

struct MatchEndMessage {
    let sessionId: UUID
    let matchId: UUID?         // 추가 (동일)
    let durationSeconds: Int   // 의미 변경: 워크아웃 누적 → 경기 구간
    let workoutElapsedSeconds: Int?      // 추가
    let workoutCalories: Double?         // 추가
    let workoutTotalCalories: Double?    // 추가
    ...
}
```

`init?(from:)`에서 새 키는 모두 optional로 읽어 구버전 페이로드를 거부하지 않는다.

**`SessionStartMessage.matchId`를 optional로 두는 이유.** 구버전 워치가 보낸 페이로드에 키가 없을 때 `init?(from:)`이 nil을 반환하면 세션 시작 자체가 실패해 경기 미러링이 통째로 깨진다 — 데이터 무결성을 고치려다 더 큰 회귀를 만드는 셈이다. 대신 mirror는 `msg.matchId`가 nil이면 **로컬에서 새 `matchId`를 발급**해 진행한다. 이 경우 mirror가 자기 화면에서 저장하면 driver와 다른 `matchId`로 중복 레코드가 생길 수 있으나, 이는 구버전 워치 조합에서만 발생하는 accepted limitation이다 (5장 참조).

### 2-2. 저장 계층

**중복 제거 키 교체** — `iOSApp/Services/MatchPersistenceService.swift`

```swift
func upsert(_ match: Match) throws {
    guard let store else { throw PersistenceError.notConfigured }
    do {
        if let mid = match.matchId {
            try store.upsert(match, replacing: #Predicate<Match> { $0.matchId == mid })
        } else {
            try store.upsert(match)      // matchId 없으면 중복 제거하지 않는다
        }
    } catch {
        throw PersistenceError.saveFailed(error)
    }
}
```

`workoutSessionId` 기반 predicate는 제거한다. `fetchByWorkoutSession(_:)`은 조회 전용이므로 그대로 둔다.

**`matchId` 생성·전파** — 기존 `sessionId` 채택 패턴을 그대로 따른다

| 시점 | 동작 |
|---|---|
| driver `startMatch()` | 새 `matchId` 발급 → `MatchSession(id:)`에 주입, `SessionStartMessage`로 전송 |
| mirror `handleIncomingSessionStart()` | `msg.matchId` 채택 (`sessionId` 채택 코드 옆) |
| `startNewMatch()` | 새 `matchId`. **`sessionId`는 유지** |
| `restartMatch()` | 새 `matchId`. `sessionId` 유지 |
| 워치 저장 재시도 | 같은 `MatchEndMessage` 재전송 → `matchId` 동일 → 중복 없음 ✅ |
| 폰·워치 양쪽 저장 | 같은 `matchId` → 뒤에 온 것이 앞의 것을 대체 ✅ |
| 콜드런치 재동기화 (`iOSApp/.../WorkoutSessionViewModel.swift:44`) | 현재 `matchId`를 실어 재전송 |

`sessionId`가 하는 일(워크아웃 종료 가드, 매치 리셋 가드, pause 왕복, 동시 시작 race 우선권)은 **하나도 바뀌지 않는다.** `matchId`는 그 옆의 별개 축이다 — `sessionId`는 "어느 워크아웃", `matchId`는 "그 안의 어느 경기".

**값 기록 규칙**

경기 시작 (`startMatch`):
```swift
elapsedAtStart: <워치: healthKit.elapsedSeconds / 폰: elapsedSeconds>
kcalAtStart, totalKcalAtStart          // 기존 그대로
startedAt: Date()                       // 1-3 수정: 폰도 경기 시작 시각
```

`startMatch`는 driver 경로와 mirror 경로(`handleIncomingSessionStart`)가 함께 쓴다. mirror에서도 `Date()`를 그대로 쓴다 — `SessionStartMessage`는 워크아웃 시작 시각만 나르고 경기 시작 시각은 나르지 않으며, 메시지 도달 지연이 무시할 수준이라 수신 시각이 driver의 경기 시작 시각에 근사한다. 통상 경로에서는 driver 쪽 레코드가 저장되므로 이 근사값이 persist되지 않고, mirror가 자기 화면에서 저장한 경우에만 쓰인다. 경기 시작 시각을 메시지에 싣는 것은 이 스펙의 범위 밖이다.

경기 종료 (`finishMatch`):
```swift
session.elapsedAtEnd = <워치: healthKit.elapsedSeconds / 폰: elapsedSeconds>
session.kcalAtEnd, session.totalKcalAtEnd    // 기존 그대로
```

저장 (`buildMatchFromSession` / `buildMatchFromMessage`):
```swift
match.durationSeconds          = elapsedAtEnd - elapsedAtStart      // 경기 구간
match.workoutElapsedSeconds    = elapsedAtEnd                       // 누적
match.caloriesBurned           = kcalAtEnd - kcalAtStart            // 경기 구간 (기존)
match.workoutCaloriesBurned    = kcalAtEnd                          // 누적
match.totalCaloriesBurned      = totalKcalAtEnd - totalKcalAtStart  // 경기 구간 (기존)
match.workoutTotalCaloriesBurned = totalKcalAtEnd                   // 누적
```

누적값은 새로 측정하는 것이 아니라 **이미 손에 쥐고 있다가 버리던 값**이다.

**1-4 수정** — `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:192`

```swift
let id = sessionId ?? activeSessionId    // workoutSessionId로 되돌아가지 않는다
```

이로써 다음 불변식이 성립한다:

> **워크아웃 하나 = `workoutSessionId` 하나.** 워크아웃이 끝날 때까지 바뀌지 않고, 새 워크아웃은 반드시 새 값을 갖는다.

이 불변식은 2-3의 그룹핑 정확도가 의존하는 전제이므로 테스트로 고정한다.

### 2-3. 집계 로직

**`iOSApp/Features/Summary/SummaryViewModel.swift`**

누적 지표와 구간 지표를 다르게 접는다.

```swift
/// 누적 지표는 워크아웃당 최댓값 하나만 취한다 — 같은 워크아웃의 경기들이 하나의
/// 누적 축을 공유하므로 단순 합산하면 같은 칼로리·시간을 여러 번 세게 된다.
private func sumOfWorkoutMaxima<T: Comparable & AdditiveArithmetic>(
    _ matches: [Match], _ value: (Match) -> T?
) -> T? {
    var maxByWorkout: [UUID: T] = [:]
    var ungrouped: [T] = []          // workoutSessionId가 없는 레코드는 각자 한 워크아웃으로 취급
    for match in matches {
        guard let v = value(match) else { continue }
        if let sid = match.workoutSessionId {
            maxByWorkout[sid] = Swift.max(maxByWorkout[sid] ?? v, v)
        } else {
            ungrouped.append(v)
        }
    }
    let all = Array(maxByWorkout.values) + ungrouped
    return all.isEmpty ? nil : all.reduce(.zero, +)
}
```

지표별 적용:

| Summary 카드 | 계산 |
|---|---|
| 운동 시간 | `sumOfWorkoutMaxima { $0.workoutElapsedSeconds ?? $0.durationSeconds }` |
| 활동 칼로리 | `sumOfWorkoutMaxima { $0.workoutCaloriesBurned ?? $0.caloriesBurned }` |
| 총 칼로리 | `sumOfWorkoutMaxima { $0.workoutTotalCaloriesBurned ?? $0.totalCaloriesBurned }` |
| 경기 수 · 승 · 승률 | 지금 그대로 (경기 단위 카운트) |
| 평균 심박 | 지금 그대로 — 단순 산술평균 유지 (Non-goal) |

기존 `durationSeconds`의 `endedAt - startedAt` 폴백(`SummaryViewModel.swift:71-75`)은 유지한다.

**경기 상세 시트**(`MatchDetailSheet.swift`)는 변경하지 않는다. 이미 `durationSeconds`·`caloriesBurned`를 읽고 있고, 이 값들이 경기 구간으로 교정되면서 자동으로 올바른 값이 된다 — 지금 시간을 누적값으로 잘못 보여주던 문제가 함께 해소된다.

**폴백(`??`)이 구버전 레코드 처리를 겸한다**

- **시간**: 기존 레코드는 `workoutElapsedSeconds`가 nil이고 그 레코드의 `durationSeconds`가 마침 누적값이라 정확히 맞는다. 신규 레코드는 `workoutElapsedSeconds`가 채워져 있어 구간값을 잘못 쓸 일이 없다.
- **칼로리**: 폴백값 `caloriesBurned`는 누적이 아니라 구간값이라 과소 집계다. 원본 누적값이 남아 있지 않아 이보다 나은 방법이 없다. 다만 **지금 화면에 뜨는 값과 정확히 같아서 기존 기록에 회귀가 없다.**

### 2-4. 마이그레이션

**스키마**: optional 필드 4개 추가는 SwiftData lightweight migration으로 자동 처리된다. 현재 `VersionedSchema`를 쓰지 않으므로(`PersistenceContainerFactory.make(for:)`) 별도 마이그레이션 코드가 없다.

**백필하지 않는다**: 기존 레코드의 `matchId`는 nil로 남는다. nil이면 중복 제거 대상이 아니므로 기존 기록이 서로를 지우는 일은 없다. 누적 필드도 nil로 두고 2-3의 폴백에 맡긴다 — 원본 정보가 없어 백필하면 추측이 된다.

**복구 불가**: 1-1로 이미 삭제된 경기는 되살릴 수 없다. 수정은 앞으로의 저장에만 적용된다.

---

## 3. 테스트

CLAUDE.md 규칙대로 **재현 테스트를 먼저 작성한 뒤 수정**한다. 프레임워크는 Swift Testing.

### `iosTests/Services/MatchPersistenceServiceTests.swift` — 전면 개정

현재 테스트가 "같은 워크아웃이면 덮어쓴다"를 **올바른 동작으로 못박고 있어서**, 그대로 두면 수정이 테스트에 막힌다.

- `upsert_sameWorkoutDifferentMatchId_keepsBoth` ← **1-1 재현**
- `upsert_sameMatchId_replaces`
- `upsert_nilMatchId_alwaysInserts`

### `iosTests/Summary/SummaryViewModelTests.swift`

- `stats_sameWorkoutMultipleMatches_doesNotDoubleCountDuration` ← **1-2 재현**
- `stats_sameWorkoutMultipleMatches_usesWorkoutMaximumCalories`
- `stats_legacyRecordsWithoutWorkoutFields_matchPreviousValues` (회귀 방지)
- `stats_matchesWithoutWorkoutSessionId_sumIndependently`
- 기존 `statsWithWorkoutData_aggregatesCorrectly` — 두 경기가 서로 다른 워크아웃임을 명시하도록 수정

### `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- `startNewMatch_keepsSessionId_issuesNewMatchId`
- `restartMatch_issuesNewMatchId`
- `buildMatchFromSession_startedAtIsMatchStart_notWorkoutStart` ← **1-3 재현**
- `buildMatchFromSession_durationIsMatchInterval_notWorkoutTotal`
- `buildMatchFromSession_recordsCumulativeWorkoutMetrics`

### `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- `startMatch_afterRemoteDrivenMatch_keepsActiveSessionId` ← **1-4 재현**
- `startNewMatch_keepsActiveSessionId_issuesNewMatchId`

### `iosTests/Shared/MatchEndMessageTests.swift` · `ConnectivityMessagesTests.swift`

- `matchEndMessage_roundTrip_preservesMatchIdAndWorkoutMetrics`
- `matchEndMessage_fromLegacyPayload_matchIdIsNil`
- `sessionStartMessage_roundTrip_preservesMatchId`

### 실기기 검증 (자동화 불가)

1. 워크아웃 1개에서 경기 3판 저장 → History에 **3건**이 남는지
2. Summary "운동 시간"이 워크아웃 실제 경과 시간과 일치하는지 (경기 수만큼 부풀지 않는지)
3. Summary "총 칼로리"가 애플 피트니스 앱의 같은 워크아웃 값과 근사한지
4. 경기 상세 시트의 시간이 해당 경기 길이인지 (워크아웃 전체가 아닌지)
5. 폰 driver로 1경기 → 워치에서 2경기 시작 → 두 경기가 한 워크아웃으로 집계되는지 (1-4)

---

## 4. Non-goals

이번 스펙에서 **다루지 않는다.** 별도 작업으로 분리한다.

| 항목 | 위치 | 이유 |
|---|---|---|
| 평균 심박 시간 가중 평균 | `SummaryViewModel.swift:79` | 표현 정확도 문제. 데이터 손실 아님 |
| 폰 단독 저장 시 심박 nil (1-5) | `WorkoutSessionViewModel.swift:344` | 워치 왕복 프로토콜 추가가 필요해 범위 초과 |
| 최근 경기 목록이 기간 필터 무시 | `SummaryView.swift:27` | 표시 동작 |
| 캘린더 하루 다중 경기 접근 불가 | `CalendarGrid.swift:19` | 화면 상호작용 |
| History 갱신 시점 (`onAppear` 수동 fetch) | `HistoryView.swift:47` | 화면 동작 |
| `MatchPersistenceService`의 별도 `ModelContext` | `iOSApp.swift:14` | 구조 개선 |
| offset 페이징 중 데이터 변경 시 중복·누락 | `HistoryViewModel.swift:43` | 실사용 영향 작음 |
| `isCompleted`·`opponentName`·`resultRaw` dead field | `Match.swift` | 정리 작업 |
| 1세트 경기 스코어 미표시 | `MatchCard.swift:22` | 제품 결정 필요 |
| 캘린더 로케일 `firstWeekday` 미반영 | `CalendarGrid.swift:34` | 라벨과 그리드가 일치하므로 정합성 문제 아님 |

---

## 5. Accepted limitations

**구버전 워치 호환은 best-effort다.** 세 가지가 함께 걸린다.

1. `MatchEndMessage.matchId`가 없는 페이로드는 중복 제거를 하지 않으므로, 구버전 워치의 저장 재시도가 중복 레코드를 만들 수 있다.
2. `SessionStartMessage.matchId`가 없으면 mirror가 로컬에서 새 `matchId`를 발급하므로, mirror 화면에서 저장하면 driver와 다른 키가 되어 같은 경기가 두 건 남는다.
3. `MatchEndMessage.durationSeconds`의 의미가 "워크아웃 누적"에서 "경기 구간"으로 바뀌므로, 구버전 워치가 보낸 값은 경기 구간으로 해석돼 경기 시간이 과대 기록된다.

셋 다 기존 `totalCalories` optional 처리와 같은 정책이며, 폰·워치를 함께 업데이트하면 해소된다.

**칼로리 폴백은 과소 집계다.** 구버전 레코드의 `workoutCaloriesBurned`가 nil일 때 `caloriesBurned`(경기 구간)로 폴백하므로 워크아웃 전체 칼로리보다 작다. 현재 표시값과 동일해 회귀는 없다.

**누적값의 관측 시점은 마지막 경기 종료 시점이다.** 워크아웃의 마지막 경기가 끝난 뒤의 칼로리·시간은 어느 레코드에도 기록되지 않는다. 시간과 칼로리가 같은 시점을 기준으로 하므로 두 지표는 서로 일관된다.
