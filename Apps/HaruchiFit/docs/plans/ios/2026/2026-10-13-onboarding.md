# 01 온보딩 구현 계획

상태: 머지 완료 (2026-10-19, PR #53). 사용자가 시뮬레이터에서 확인했다.
스펙: [제품 스펙 01절](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md#01-온보딩-3장) (2026-10-13 개정)
선례: Ralli `Apps/TennisCounter/iOSApp/Features/Onboarding/` — 루트 교체 · 버전 번호 판정 · 현지화 이미지 세트

## 목표와 결정

- 첫 실행에 3장(컨셉 · 워치 · 권한)이 **탭 화면 대신** 뜬다. 문구와 규칙은 스펙 01절이 원본이다.
- **온보딩을 마치기 전에는 HealthKit 동기화를 돌리지 않는다.** 지금은 `iOSApp.swift` 가 활성화될 때마다 `sync.sync()` 를 부르고
  그 안에서 권한을 요청해, 첫 실행에 설명 없이 시스템 시트가 뜬다. 권한 요청 코드는 옮기지 않는다 —
  **동기화를 부르는 쪽만 막는다.** `WorkoutSyncCoordinator` 는 고치지 않는다.
- 3장의 `계속` 이 본 버전을 기록하고 첫 동기화를 돌린다. 루트가 탭 화면으로 바뀌고 그 위에 시스템 권한 시트가 뜬다.
- 노출 판정은 Ralli 와 같은 "몇 번째 버전까지 봤나"다. 판정 규칙은 `Shared/Models/` 에 둔다 —
  하루치는 테스트 타깃이 워치 쪽 하나라 iOS 폴더의 코드는 단위 테스트가 닿지 않는다.
- 건너뛰기 버튼 · `나중에` 버튼 · 앱 소개 다시 보기는 만들지 않는다 (스펙 01절 규칙).
- 워치 앱 · 컴플리케이션 · `Packages/YJKit` 은 건드리지 않는다.

## Task 1 — 노출 판정과 테스트

**Files:**
- Create: `Shared/Models/OnboardingGate.swift` — `version = 1`, `shouldShow(seenVersion:)`. Ralli 것과 같은 6줄.
- Create: `watchosTests/Models/OnboardingGateTests.swift` — 첫 설치는 뜬다 · 지금 버전을 봤으면 안 뜬다 ·
  이전 버전을 봤으면 다시 뜬다 · 더 높은 버전을 본 기록이면 안 뜬다.

**순서:** 테스트를 먼저 써서 실패를 확인하고 구현한다. `HaruchiFitWatchTests` 스킴으로 돌린다.

## Task 2 — 문자열과 이미지

**Files:**
- Modify: `iOSApp/Localizable.xcstrings` — 키 9개를 ko · en 둘 다 `translated`, `extractionState: manual` 로 넣는다.

  | 키 | 쓰는 곳 |
  |---|---|
  | `onboarding_concept_title` · `onboarding_concept_body` | 1장 |
  | `onboarding_watch_title` · `onboarding_watch_body` · `onboarding_watch_note` | 2장 (`note` = 부위 · 메모 작은 글씨) |
  | `onboarding_health_title` · `onboarding_health_body` | 3장 |
  | `btn_next` · `btn_continue` | 아래 버튼 |

  제목의 줄바꿈은 값에 `\n` 으로 넣는다.
- Create: `iOSApp/Assets.xcassets/OnboardingWatch.imageset/` — `Contents.json` + `watch.png` 한 장 (10-17 변경: 영어 화면 하나를 두 언어에 쓴다. 원래는 ko · en 두 장).

**이미지 규격 (피그마에서 뽑을 때):** 세로 **4:5**, 1200 × 1500 px PNG. 배경은 앱 배경색 `#1C1C18` 로 채운다.
워치 프레임 안에 W1a 지표 화면(근력 모드)을 합성하고, 왼쪽 위 모드 아이콘이 프레임에 가려지지 않게 한다.
강조 표시는 그리지 않는다 — 코드가 얹는다.

**임시 이미지:** 정식 이미지가 오기 전까지는 워치 시뮬레이터의 지표 화면 캡처를 같은 규격으로 넣는다.
시뮬레이터에서 운동을 시작하려면 건강 권한 시트를 사람이 한 번 눌러 줘야 해서 자동 캡처가 막힐 수 있다.
막히면 단색 자리 표시 이미지를 넣고 PR 본문에 적는다.

## Task 3 — 온보딩 화면

**Files:**
- Create: `iOSApp/Features/Onboarding/OnboardingView.swift` — 3장 가로 페이징(`TabView` + `.page`), 페이지 점, 아래 버튼 하나.
  1 · 2장은 `btn_next` 로 다음 장, 3장은 `btn_continue` 로 `onFinished()`. 건너뛰기 없음. ViewModel 없음 — 상태가 페이지 번호 하나다.
- Create: `iOSApp/Features/Onboarding/Components/OnboardingPage.swift` — 한 장의 공통 배치. 그림 자리(`@ViewBuilder`) + 제목 + 본문 +
  선택적 작은 글씨. 그림 자리는 4:5, 본문 영역 높이를 고정해 장마다 그림 위치가 흔들리지 않게 한다 (Ralli `OnboardingScreenshotPage` 와 같은 계산).
- Create: `iOSApp/Features/Onboarding/Components/OnboardingGrassPicture.swift` — 1장 그림. 7행 잔디 격자가 왼쪽부터 차례로 채워진다.
  칸 크기 · 모서리 · 색은 홈 `GrassHero` 와 같고(`HaruchiPalette.grass`), 채움 무늬는 고정 배열이다(난수 없음).
  **동작 줄이기**가 켜져 있으면 채워진 상태로 고정한다.
- Create: `iOSApp/Features/Onboarding/Components/OnboardingWatchPicture.swift` — 2장 그림. `Image("OnboardingWatch")` 위에 왼쪽 위 아이콘
  자리에 강조 고리를 얹는다. 고리 위치는 이미지 기준 **비율 상수** 하나로 둔다 — 정식 이미지로 바꿀 때 이 값만 맞춘다.
- Create: `iOSApp/Features/Onboarding/Components/OnboardingHealthPicture.swift` — 3장 그림. 하트 심볼(SF Symbols)에서 잔디 칸으로 이어지는
  정적 그림. 이미지 에셋 없음.

**모양:** 배경 `HaruchiPalette.bg`, 제목 `text`, 본문 `dim`, 버튼은 `accent` 채움에 검은 글자. 앱 전체와 같은 다크 고정.

## Task 4 — 루트 연결

**Files:**
- Modify: `iOSApp/iOSApp.swift`
  - `@AppStorage("onboardingSeenVersion")` 를 둔다. 키 이름은 Ralli 와 같다 (앱마다 저장소가 달라 겹치지 않는다).
  - `WindowGroup` 안에서 `OnboardingGate.shouldShow` 면 `OnboardingView`, 아니면 `ContentView` 를 그린다.
    `.modelContainer` · `.environmentObject` · `.onReceive`(워치 기록 저장) · `.onChange(scenePhase)` 는 **둘을 감싼 바깥에** 그대로 둔다 —
    온보딩 중에 워치 기록이 도착해도 저장된다.
  - `scenePhase` 동기화에 조건을 건다: 온보딩을 봐야 하는 동안은 `sync.sync()` 를 부르지 않는다.
  - `onFinished`: 본 버전을 기록하고 `Task { await sync.sync() }` 를 돌린다.

**확인할 것:** 권한 시트가 떠 있는 동안 앱이 꺼져도 다음 실행에는 홈이 뜨고 동기화가 권한을 다시 묻는다
(본 버전은 `계속` 을 누른 순간 기록된다). 시트가 닫히며 `scenePhase` 가 다시 활성화돼도 `isSyncing` 가드가 중복 실행을 막는다.

## Task 5 — 검증과 문서

**Files:**
- Modify: `Apps/HaruchiFit/CLAUDE.md` — iOS 폴더 트리에 `Features/Onboarding/` 한 줄.
- Modify: 이 플랜 문서 — 상태 줄과 구현 중 판단.
- Modify: 루트 `TODO.md` — 출시 준비 4번과 3차 표의 온보딩 행.

**자동 검증:**
- `HaruchiFitWatchTests` 스킴 테스트 전체 (UDID 지정)
- `HaruchiFit` 스킴 빌드
- `make lint` · `make format`
- 카탈로그 대조 — 새 키 9개가 코드에서 불리고, ko · en 값이 모두 있다

**시뮬레이터 수동 확인 (구현 뒤 사용자와 함께):**
- 앱을 지우고 새로 설치하면 온보딩이 뜨고, 3장의 `계속` 을 누르기 전에는 시스템 권한 시트가 뜨지 않는다
- `계속` → 권한 시트 → 닫으면 홈. 앱을 다시 켜면 온보딩이 뜨지 않는다
- 권한을 전부 거부해도 홈 · 수동 기록이 동작한다
- 한국어 · 영어에서 세 장의 제목 · 본문 · 작은 글씨가 잘리지 않는다 — 특히 영어 2장, 화면이 작은 기기, 큰 글자 크기
- 동작 줄이기를 켜면 1장 잔디가 채워진 채로 서 있다
- 2장 강조 고리가 왼쪽 위 아이콘 위에 놓인다

## 브랜치 · 커밋 · PR

- 이 플랜 문서와 `TODO.md` 는 검토 뒤 `main` 에 직접 커밋한다.
- 구현은 `feat/haruchi-onboarding` 브랜치. 커밋은 Task 단위로 나눈다 —
  ① 판정 규칙과 테스트 ② 문자열 · 이미지 · 화면 ③ 루트 연결 ④ 문서.
- PR 을 올리고, 머지는 사용자 확인 뒤 `gh pr merge <n> --merge --delete-branch`.

## 구현 중 판단과 확인 상태

- 2장 이미지(`watch.png`)는 **실제 워치 시뮬레이터 캡처(영어)** 를 워치 프레임에 합성한 것이다 (10-17). 한국어 · 영어 모두 같은 이미지를 쓴다 — 사용자 결정. 강조 고리 위치(`ringCenter`)는 이 이미지에 맞춰 있다.
- 확인함: 새로 설치하면 1장이 뜨고 권한 시트는 뜨지 않는다 (한국어).
- **남음:** (2장 이미지는 위 항목으로 해결됨) 2·3장 화면, `계속` → 권한 시트 → 홈, 재실행 시 온보딩 미표시, 영어, 동작 줄이기.
