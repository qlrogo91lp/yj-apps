# RalliKit 원격 채택 + 카운터 크라운 페이징 설계

작성일: 2026-08-09
참조 스펙: `2026-07-31-golfcounter-rebuild-design.md` (이 문서가 §2·§4를 개정한다)
영향받는 플랜: `2026-08-05-watch-round-transmission.md` (④, 미구현 — 갱신 필요)

## 1. 목표

두 가지를 한 번에 처리한다.

1. **RalliKit 의존을 로컬 경로에서 원격 저장소로 바꾸고, 워치 워크아웃 화면을 공유 패키지(`WorkoutUI`)의 것으로 교체한다.** 테니스가 이미 같은 길을 갔고(PR #21·#22), 골프가 자체 구현을 유지할 이유가 없어졌다.
2. **카운터 화면의 스코어카드 노출을 크라운 스냅 페이징으로 고친다.** 이건 새 기능이 아니라 기존 스펙 §4의 의도를 구현이 못 살린 것을 바로잡는 일이다.

## 2. 배경 — 왜 지금인가

RalliKit에는 이미 세 앱이 공유할 워크아웃 화면(`WorkoutUI`)이 있다. 테니스는 두 차례 플랜으로 이 화면을 채택하고 앵커 기반 경과시간·pause 왕복까지 마쳤지만, 골프는 `WorkoutCore`(값·서비스)만 쓰고 화면은 자체 구현으로 남아 있다. 즉 골프는 공유 자산을 절반만 쓰고 있다.

동시에 카운터 화면에 문제가 있다. 스펙 §4는 이렇게 적고 있다:

> 아래로 스크롤(crown) 시 전체 스코어카드 표시 — 모달 아님

현재 구현(`CounterView`)은 `ScrollView` 하나에 카운터 5블록 + `Divider()` + `Scorecard`를 통째로 쌓아둔 형태다. 문자 그대로는 "스크롤하면 스코어카드가 나온다"를 만족하지만, **페이지 경계라는 개념이 코드에 존재하지 않아** 크라운을 돌리면 내용이 죽 밀려 올라가는 한 덩어리로 느껴진다. 의도했던 "화면이 넘어가는" 감각이 아니다.

두 작업 모두 미구현 플랜 ④가 건드릴 파일(`RoundSessionView`, `CounterView`, `HoleNavigation`, `pbxproj`)을 손댄다. 플랜 ④가 아직 "확인필요" 상태이므로, 바닥을 먼저 정리하고 ④가 그 위에 얹히는 순서로 간다.

## 3. 확정한 설계 결정 (brainstorming 결과)

1. **패키지 참조는 원격(branch `main`)으로 간다.** 테니스와 동일한 방식이고, 앱스토어 릴리즈 시점에 semver 태그로 옮기는 것도 같이 따라간다.
2. **RalliKit 패키지 코드는 이번에 한 줄도 바꾸지 않는다.** 골프가 패키지에 맞추고, 그 반대가 아니다.
3. **진행 중 실시간 거리(km) 표시를 포기한다.** 스펙 §4가 메트릭 페이지에 거리를 명시하고 있었으나 뒤집는다. 자세한 근거는 §5.
4. **잠금(water lock)을 스펙에서 삭제한다.** 플랜 ①~④ 어디에도 들어가 있지 않은 미구현 항목이고, 손목을 내리면 화면이 꺼지는 watchOS 기본 동작이 오터치를 상당히 막아준다. YAGNI.
5. **카운터는 크라운 스냅 페이징으로 간다.** 세로 `TabView` 중첩이나 가로 4번째 탭 분리가 아니라 `ScrollView` + `.scrollTargetBehavior(.paging)`.
6. **작은 워치 대응은 필수 요건이다.** 기기 분기 하드코딩 없이 `ViewThatFits`로 처리한다.
7. **이 작업을 플랜 ④보다 먼저 하고, ④ 문서를 갱신한다.**

## 4. 파트 A — 패키지 참조를 원격으로

### 전환 내용

`XCLocalSwiftPackageReference "../ralli-kit"` → `XCRemoteSwiftPackageReference`

| 항목 | 값 |
|---|---|
| URL | `https://github.com/qlrogo91lp/ralli-kit.git` |
| 요구사항 | branch `main` |

전환 시점의 ralli-kit `main`은 `bb084ee`이고 `origin/main`과 동일하다 (푸시 완료 확인).

### 타깃별 링크

| 타깃 | 전환 후 링크 | 변화 |
|---|---|---|
| `GolfCounter` (iOS) | ConnectivityCore, PersistenceCore | 없음 |
| `GolfCounter Watch App` | ConnectivityCore, WorkoutCore, **WorkoutUI** | WorkoutUI 추가 |
| `ComplicationAppExtension` | 없음 | 없음 |

`Shared/`가 세 타깃 모두에 동기화되므로, `Shared/`에 `import WorkoutCore`나 `import WorkoutUI`를 하는 파일을 두면 iOS·컴플리케이션 빌드가 깨진다. 이 작업의 신규 코드는 전부 `WatchApp/` 아래에만 둔다. (플랜 ④가 이 제약을 `PBXFileSystemSynchronizedBuildFileExceptionSet`으로 다루므로 그쪽과 충돌하지 않는다.)

### pbxproj는 Xcode GUI로

패키지 참조를 전환하면 product 참조 UUID가 전부 재발급된다. 손편집은 위험하므로 Xcode GUI에서 수행하고, 구현 플랜에 **사용자 수동 스텝**으로 명시한다. 테니스도 같은 방식이었다 (`e041683`, pbxproj 한 파일에 44 insertions / 33 deletions).

### 원격 전환의 대가와 탈출구

앞으로 ralli-kit을 고치면 push → Xcode 패키지 업데이트를 거쳐야 골프에 반영된다. 로컬 참조 때의 즉시 반영은 사라진다.

탈출구: **로컬 패키지 폴더를 Xcode 워크스페이스에 끌어다 놓으면 같은 이름의 원격 패키지보다 우선 적용된다** (Xcode 기본 동작). 패키지를 활발히 고치는 동안만 그렇게 쓰고, 끝나면 제거하면 된다. 커밋되는 pbxproj는 원격 참조를 유지한다.

## 5. 파트 B — 워크아웃 화면을 WorkoutUI로

### 삭제

`WatchApp/Features/Round/Metrics/`, `WatchApp/Features/Round/Controls/` 두 폴더를 통째로 (4개 파일):

- `Metrics/MetricsView.swift`
- `Controls/ControlsView.swift`
- `Controls/Components/RoundPauseButton.swift`
- `Controls/Components/RoundEndButton.swift`

### 교체

`RoundSessionView`의 TabView:

```swift
WorkoutControlsView(isPaused: healthKit.isPaused,
                    onPauseResume: togglePause,
                    onEnd: endRound)
    .toolbar { ToolbarItem(placement: .topBarLeading) { Color.clear.frame(width: 36, height: 36) } }
    .tag(0)
centerPage.tag(1)
WorkoutMetricsView(metrics: currentMetrics, isPaused: healthKit.isPaused).tag(2)
```

`currentMetrics`는 `RoundSessionView`의 computed property로 둔다:

```swift
private var currentMetrics: WorkoutMetrics {
    WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                   activeCalories: healthKit.currentCalories,
                   totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                   heartRate: healthKit.currentHeartRate)
}
```

테니스는 이 매핑을 ViewModel의 `@Published`로 뺐다. 그 이유는 테니스 View가 서비스를 소유하지 않아 `init`에서 매번 새 인스턴스가 만들어지는 함정이 있었기 때문이다. 골프는 `RoundSessionView`가 `@StateObject private var healthKit`으로 직접 소유하므로 그 함정이 없고, computed property로 충분하다.

`togglePause`는 `healthKit.isPaused ? resumeWorkout() : pauseWorkout()` 한 줄짜리 private 메서드다.

### toolbar 자리채움은 호출부에 남긴다

기존 `ControlsView`가 갖고 있던 `ToolbarItem(placement: .topBarLeading) { Color.clear.frame(width: 36, height: 36) }`는 패키지로 옮기지 않는다. 워치 내비게이션 사정이지 워크아웃의 관심사가 아니다. 테니스도 같은 판단을 했다.

### 표시 항목 변화

| | 현재 (골프 자체 구현) | 전환 후 (`WorkoutMetricsView`) |
|---|---|---|
| 1 | 경과시간 | 경과시간 |
| 2 | BPM | 활동 kcal |
| 3 | 활동 kcal | 총 kcal |
| 4 | **거리 (km)** | BPM |

항목 수는 4개 그대로이고, **거리가 빠지는 대신 총 kcal이 들어온다.**

### 거리를 포기해도 되는 근거

`WorkoutMetrics`(진행 중 스냅샷 값 타입)에는 거리·걸음수 필드가 없다. 이는 실수가 아니라 테니스 기준으로 내려진 의도적 결정이었다("표시 항목 4개 고정… 걸음수·거리는 표시하지 않는다").

중요한 건 **거리 수집과 기록은 이 결정과 무관하다는 점**이다. 두 경로가 완전히 분리되어 있다.

```
[기록 경로 — 영향 없음]
WorkoutConfiguration.golf (additionalReadTypes: distanceWalkingRunning, stepCount)
  → WorkoutSessionService.stopWorkout()
  → WorkoutResult.distanceMeters / .steps
  → RoundMetrics (플랜 ④)
  → GolfRound.distanceMeters / .steps

[진행 중 표시 경로 — 여기만 끊긴다]
WorkoutSessionService.currentDistanceMeters
  → (WorkoutMetrics에 필드 없음)
  → WorkoutUI.WorkoutMetricsView
```

즉 잃는 것은 "라운드를 도는 중에 실시간으로 걸은 거리를 보는 것" 하나뿐이다. 종료 요약, iOS 기록·통계, 애플 건강 앱의 워크아웃 기록에는 거리가 전부 그대로 남는다. `GolfRound`에도 `distanceMeters`·`steps` 필드가 이미 있다.

이 손실을 감수하는 대가로 패키지를 한 줄도 고치지 않고, 세 앱의 워크아웃 화면이 하나로 수렴한다. 나중에 실시간 거리가 정말 필요해지면 그때 `WorkoutMetrics`에 필드를 additive로 추가하면 된다 — 이 결정은 되돌릴 수 있다.

### 부수 효과 — 문자열 로컬라이즈

`WorkoutUI`는 en/ko `Localizable.strings`를 패키지 리소스로 갖고 있다. 따라서 "일시정지"/"계속하기"/"운동 종료" 세 문자열만 골프에서 먼저 로컬라이즈된다. 골프의 나머지 문자열은 아직 한국어 하드코딩 단계(플랜 ⑦에서 처리 예정)라 일관성이 잠시 어긋나지만, 해로울 것은 없고 오히려 앞서가는 방향이다.

## 6. 파트 C — 카운터 크라운 스냅 페이징

### 구조

```swift
// CounterView.swift — 컨테이너 역할만 남는다
ScrollView {
    VStack(spacing: 0) {
        ViewThatFits(in: .vertical) {
            CounterPage(viewModel: viewModel, sizing: .regular)
            CounterPage(viewModel: viewModel, sizing: .compact)
            CounterPage(viewModel: viewModel, sizing: .tight)
        }
        .containerRelativeFrame(.vertical)

        Scorecard(snapshot: viewModel.snapshot)
    }
}
.scrollTargetBehavior(.paging)
```

> **용어**: 이 절에서 "세로 페이지"는 크라운으로 넘기는 스크롤 페이지를 뜻한다. 스펙 §4가 말하는 "페이지 1/3 / 2/3 / 3/3"은 가로 스와이프로 넘기는 `TabView` 탭이며, 카운터는 그중 **가로 2/3 탭 안에서** 세로로 페이징된다.

- 세로 1페이지(카운터)는 컨테이너 높이에 정확히 고정된다.
- 스코어카드는 자연 높이로 흐른다. 18홀이면 한 화면을 넘어가는데, `.paging`이 컨테이너 높이 단위로 나누므로 세로 2·3페이지로 자동 분할된다.
- 크라운은 watchOS `ScrollView`를 기본 구동하므로 별도 배선이 없다.
- 기존 `Divider()`는 삭제한다 — 페이지 경계가 그 역할을 대신한다.

### 가로 TabView와의 관계

이 화면은 `RoundSessionView`의 가로 `TabView(.page)`(Controls / Counter / Metrics) 안에 들어 있다. 크라운(세로)과 스와이프(가로)는 입력 채널이 달라 충돌하지 않는다. 세로 `TabView` 중첩을 택하지 않은 이유가 이것이다 — 중첩은 크라운 소유권 다툼을 만든다.

### 작은 화면 대응

`ViewThatFits`가 세 크기 세트 중 실제로 들어가는 첫 번째를 고른다.

| 요소 | regular | compact | tight |
|---|---|---|---|
| 헤더 폰트 | 15 | 14 | 13 |
| 홀 스코어 폰트 | 22 | 20 | 18 |
| 스트로크 버튼 | 62 | 54 | 46 |
| 스트로크 아이콘 | 26 | 23 | 20 |
| 모드·Par 높이 | 28 | 26 | 24 |
| 홀 이동 높이 | 30 | 28 | 26 |
| 세로 간격 | 8 | 6 | 4 |
| **합계 높이** | **196pt** | **173pt** | **149pt** |

합계는 폰트 크기가 아니라 **렌더 높이** 기준이다 (헤더 15pt 폰트 ≈ 18pt 줄높이, 홀 스코어 22pt 폰트 ≈ 26pt). 세로 간격 4회분도 포함한다. 어디까지나 세 세트의 간격이 충분히 벌어졌는지 확인하기 위한 산출이며, 실제 선택은 `ViewThatFits`가 한다.

참고용 추정치 (상단 시계 영역 제외):

| 모델 | 사용 가능 높이(추정) | 예상 선택 |
|---|---|---|
| 40mm (Series 4~SE) | ~167pt | tight |
| 41mm (Series 7~9) | ~183pt | compact |
| 44mm | ~192pt | compact |
| 45/46mm | ~210pt | regular |
| 49mm Ultra | ~213pt | regular |

**이 추정치는 설계 근거일 뿐 코드에 들어가지 않는다.** `ViewThatFits`는 실제 레이아웃 측정으로 고르므로 추정이 틀려도 결과는 맞는다. 기기 분기 하드코딩이 한 줄도 없다는 것이 이 방식을 택한 이유다.

### 파일 배치

CLAUDE.md의 계층 규칙(`ScreenName/Components/`는 그 화면 전용 순수 컴포넌트)에 따라:

| 파일 | 상태 | 책임 |
|---|---|---|
| `Counter/CounterView.swift` | 수정 | ScrollView 컨테이너 + 페이징 설정만 |
| `Counter/Components/CounterPage.swift` | **신규** | 1페이지 내용 (헤더·점수·버튼·모드/Par·홀이동) |
| `Counter/Components/CounterSizing.swift` | **신규** | 크기 세트 값 타입 + `.regular`/`.compact`/`.tight` |
| `Counter/Components/StrokeButton.swift` | 수정 | 버튼·아이콘 크기 파라미터 추가 |
| `Counter/Components/ModeToggle.swift` | 수정 | 높이 파라미터 추가 |
| `Counter/Components/HoleNavigation.swift` | 수정 | 높이 파라미터 추가 |
| `Counter/Components/Scorecard.swift` | 그대로 | 변경 없음 |

## 7. 기존 문서 개정

### 스펙 `2026-07-31-golfcounter-rebuild-design.md`

| 위치 | 개정 |
|---|---|
| §2 의존성 | "로컬 SPM 패키지 (`../ralli-kit`)" → 원격(branch `main`). product 목록에 `WorkoutUI` 추가 |
| §4 페이지 1/3 | "잠금(오터치 방지, water lock 방식)" **삭제**. 일시정지 / 라운드 종료 두 가지로 |
| §4 페이지 2/3 | "아래로 스크롤(crown) 시 전체 스코어카드 표시" → 크라운 **스냅 페이징**임을 명시 |
| §4 페이지 3/3 | "심박수 · 칼로리 · 거리 · 경과 시간" → "경과시간 · 활동 kcal · 총 kcal · 심박수". `WorkoutUI` 공유 화면 사용 명시, 실시간 거리 제외 근거 한 줄 |

### 플랜 ④ `2026-08-05-watch-round-transmission.md` (미구현, "확인필요")

| 위치 | 갱신 |
|---|---|
| Tech Stack | "로컬 SPM `../ralli-kit`" → 원격 |
| 타깃 링크 제약 표 | Watch App에 `WorkoutUI` 추가 |
| Task 3 | `HoleNavigation` 시그니처를 크기 파라미터 포함 형태로 조정 (`canGoToNext` 추가와 병합) |
| `RoundSessionView` 관련 서술 | 3페이지 TabView 구성을 `WorkoutUI` 뷰 기준으로 |
| `CounterView` 관련 서술 | 2페이지 스냅 구조 반영 |

## 8. 검증

이 작업은 거의 전부 View이고, CLAUDE.md가 "View는 테스트하지 않는다"를 규정한다. 따라서 **자동화 테스트로 잡을 수 있는 것이 사실상 없다. 안전망이 얇다는 점을 명시해 둔다.**

| 항목 | 방법 |
|---|---|
| 빌드 | 3개 타깃 전부 (`GolfCounter` / `GolfCounter Watch App` / `ComplicationAppExtension`). 패키지 참조가 통째로 바뀌므로 컴플리케이션이 안 깨지는지가 특히 중요 |
| 회귀 | 기존 `watchosTests` 전원 통과. `RoundViewModel` 로직은 건드리지 않으므로 그대로여야 한다 |
| 레이아웃 | 워치 시뮬레이터 **40mm · 41mm · 46mm** 세 사이즈 육안 확인. 작은 화면이 요건이므로 필수 |
| 페이징 | 크라운 회전 시 카운터↔스코어카드가 스냅되는지, 18홀에서 스코어카드가 여러 페이지로 잘 나뉘는지 |
| 스타일 | `make lint` / `make format` 위반 0 |

## 9. 리스크

| 리스크 | 대응 |
|---|---|
| `ViewThatFits`와 `.containerRelativeFrame`의 modifier 순서가 측정 결과에 민감하다 | 시뮬레이터 실측으로 확정. 순서가 문제면 `GeometryReader` 기반으로 대체 |
| tight(149pt)조차 안 들어가는 기기가 있으면 마지막 변형이 그대로 잘린다 | 40mm 실측으로 확인. 필요하면 네 번째 단계 추가 |
| watchOS에서 크라운 + `.paging` 조합의 감촉이 어색할 수 있다 | 실측 후 어색하면 `.viewAligned`로 대체 검토 |
| 원격 참조 전환 후 ralli-kit 수정 반영이 느려진다 | §4의 로컬 패키지 override 탈출구 |
| 세로 1페이지만 보면 아래에 스코어카드가 있는지 모를 수 있다 | 실측 후 스크롤 힌트 필요 여부 판단. 기본 스크롤 인디케이터로 충분한지 먼저 확인 |

## 10. 범위 밖

- **RalliKit 패키지 코드 변경** — 이번엔 0. 골프가 패키지에 맞춘다
- **실시간 거리 표시** — §5의 결정. 되돌릴 수 있는 결정으로 남겨둔다
- **잠금(water lock)** — 스펙에서 삭제
- **semver 태그 전환** — 앱스토어 릴리즈 시점
- **iOS 앱 화면** — 아직 `iOSApp.swift` 하나뿐이고 플랜 ⑤ 소관
- **플랜 ④의 구현** — 문서 갱신까지만. 홀 수 선택·종료 요약·전송은 ④가 담당
- **문자열 로컬라이즈** — 플랜 ⑦ (패키지가 제공하는 세 문자열은 자동으로 딸려 온다)
