# GolfCounter iOS 온보딩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 폰 앱 첫 실행(기존 사용자는 업데이트 후 첫 실행)에 워치 사용법 4장을 보여 준다 — 퍼팅 모드 전환 영상 · 크라운 스코어카드 영상 · 컴플리케이션 · 건강 앱.

**Architecture:** Ralli 온보딩(`Apps/TennisCounter/iOSApp/Features/Onboarding/`)을 **구조를 바꾸지 않고** 골프 iOS 앱으로 복사한다
(나중에 YJKit 으로 공통화할 때 옮기기 쉽게 — 루트 `TODO.md` YJKit 절). 영상은 `tools/store-assets/` 도구로 만든다.
`GolfCounterApp` 이 `LaunchScreenView` 와 `MainTabView` 사이에서 `OnboardingGate` 로 분기한다.

**Tech Stack:** SwiftUI · AVFoundation(`AVPlayerLooper`) · Swift Testing · `.strings` 로컬라이즈 · store-assets(HTML 캔버스 + 헤드리스 크롬 + `encode.swift`)

**Spec:** `Apps/GolfCounter/docs/specs/ios/2026/2026-10-26-onboarding-design.md`

## Global Constraints

- 2.1.2 에 싣는다. `MARKETING_VERSION` 은 바꾸지 않는다. **4장이 다 찬 상태로만 출시한다** — Task 4~6 이 끝나기 전에는 출시 빌드를 올리지 않는다
- `OnboardingGate.version = 1`, `UserDefaults` 키 `"onboardingSeenVersion"`(기본 0), 표시 조건 `seenVersion < version`
- 시트가 아니라 루트 교체로 띄운다. 건너뛰기·시작하기 모두 `seenVersion = version` 저장
- 그림 박스 4:5(0.80), 영상·정지 이미지 **1200×1500**, 앱 안 영상은 **`no-audio`** 인코딩, 30fps
- 워치 렌더링은 `tools/store-assets/inputs/golf-watch.png`(원본 비율·외곽·스트랩 그대로, 검은 배경)
- 골프 iOS 는 다크 고정이 아니다 → **온보딩 루트에만** `.preferredColorScheme(.dark)`
- 문자열은 `iOSApp/{ko,en}.lproj/Localizable.strings` (xcstrings 아님). 키는 두 언어에 모두 있어야 한다 (`StringsParityTests`)
- 빌드·테스트는 워크스페이스 + UDID: `IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')`
- 작업 위치는 **메인 체크아웃의 브랜치** `feat/golf-onboarding` — `inputs/`·`out/` 이 gitignore 라 메인 체크아웃에만 있다.
  메인에 하루치·Ralli `project.pbxproj` 의 무관한 변경이 남아 있으므로 **`git add` 는 항상 경로를 적어서**
- 커밋 메시지 gitmoji, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

1. **라이트 모드 기기** — 온보딩이 검정 배경 + 흰 제목으로 보이고, 끝난 뒤 `MainTabView` 는 원래(시스템) 모드로 돌아온다 → Task 2 Step 6
2. **동작 줄이기 켬** — 영상 대신 정지 이미지, 컴플리케이션 링이 숨 쉬지 않는다 → Task 2 Step 6 · Task 5 Step 4
3. **기존 사용자 업데이트** — 키가 없는 상태에서 뜨고, 건너뛰기로 닫은 뒤 재실행하면 안 뜬다 → Task 1 테스트 + Task 2 Step 6
4. **영상 페이지를 넘겼다 돌아오기** — 화면 밖 영상은 멈추고, 돌아오면 다시 돈다. 사용자의 음악이 끊기지 않는다(`ambient`) → Task 3 Step 6
5. **작은 화면 + 영어** — 가장 긴 영어 본문(1페이지)이 3줄 안에 들어가고 그림이 버튼과 겹치지 않는다 → Task 2 Step 6

---

### Task 1: 노출 규칙 `OnboardingGate`

**Files:**
- Create: `Apps/GolfCounter/iOSApp/Features/Onboarding/OnboardingGate.swift`
- Test: `Apps/GolfCounter/iosTests/Features/Onboarding/OnboardingGateTests.swift`

**Interfaces:**
- Produces: `enum OnboardingGate { static let version: Int /* = 1 */; static func shouldShow(seenVersion: Int) -> Bool }`

- [ ] **Step 0: 브랜치**

```bash
git checkout main && git pull --ff-only && git checkout -b feat/golf-onboarding
```

- [ ] **Step 1: 실패하는 테스트** — Ralli `Apps/TennisCounter/iosTests/Onboarding/OnboardingGateTests.swift` 를 그대로 옮기고 `@testable import GolfCounter` 로 바꾼다.
  4개: `freshInstallShows`(0 → true) · `seenCurrentVersionHides`(version → false) · `seenOlderVersionShowsAgain`(version-1 → true) · `seenNewerVersionHides`(version+1 → false)

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild -workspace YJApps.xcworkspace -scheme GolfCounter -destination "id=$IOS" test -only-testing:GolfCounterTests/OnboardingGateTests`
Expected: `OnboardingGate` 없음으로 컴파일 실패

- [ ] **Step 3: 구현** — Ralli `OnboardingGate.swift` 복사. 주석의 "1 = …" 만 `1 = 2.1.2 (모드 전환·스코어카드·컴플리케이션·건강 4장)` 으로

- [ ] **Step 4: 통과 확인** — 같은 명령, 4개 PASS

- [ ] **Step 5: 커밋**

```bash
git add Apps/GolfCounter/iOSApp/Features/Onboarding/OnboardingGate.swift Apps/GolfCounter/iosTests/Features/Onboarding/OnboardingGateTests.swift
git commit -m "✨ feat: 골프 온보딩 노출 규칙을 더한다"
```

### Task 2: 온보딩 화면 틀 + 앱 진입

**Files:**
- Create: `Apps/GolfCounter/iOSApp/Features/Onboarding/OnboardingView.swift`
- Create: `Apps/GolfCounter/iOSApp/Features/Onboarding/Components/LoopingVideo.swift` — Ralli 그대로
- Create: `Apps/GolfCounter/iOSApp/Features/Onboarding/Components/OnboardingScreenshotPage.swift` — Ralli 그대로 (프리뷰 문구만 골프로)
- Create: `Apps/GolfCounter/iOSApp/Features/Onboarding/Components/OnboardingComplicationRing.swift` — Ralli 그대로. `center`·`diameter` 는 Task 5 에서 맞춘다
- Modify: `Apps/GolfCounter/iOSApp/iOSApp.swift` (`body` 분기 + `@AppStorage`)
- Modify: `Apps/GolfCounter/iOSApp/ko.lproj/Localizable.strings`, `.../en.lproj/Localizable.strings`

**Interfaces:**
- Consumes: Task 1 `OnboardingGate`
- Produces: `struct OnboardingView: View { let onFinished: () -> Void }` · `OnboardingScreenshotPage(imageName:videoName:isActive:title:message:overlay:)` ·
  번들 영상 이름 규칙 `<videoName>-<ko|en>.mp4` → 없으면 `<videoName>.mp4` · 이미지 에셋 이름 `OnboardingMode` / `OnboardingCrown` / `OnboardingComplication` / `OnboardingHealth`

- [ ] **Step 1: 문자열** — 두 파일에 `/* Onboarding */` 절을 더한다. 값은 스펙 "문구 초안" 표 그대로, 버튼은 Ralli 값을 그대로.

| 키 | ko | en |
|---|---|---|
| `onboarding_skip` / `_next` / `_start` | 건너뛰기 / 다음 / 시작하기 | Skip / Next / Get Started |
| `onboarding_mode_title` / `_body` | 스펙 1행 | 스펙 1행 |
| `onboarding_crown_title` / `_body` | 스펙 2행 | 스펙 2행 |
| `onboarding_complication_title` / `_body` | 스펙 3행 | 스펙 3행 |
| `onboarding_health_title` / `_body` | 스펙 4행 | 스펙 4행 |

`.strings` 값 안의 `"` 는 이스케이프한다.

- [ ] **Step 2: 컴포넌트 3개 복사** (위 Files)

- [ ] **Step 3: `OnboardingView`** — Ralli 파일을 기준으로 바꾸는 것만:
  `lastPage = 3` · 페이지 4장(아래) · 공유 페이지 삭제 · 루트 `ZStack` 에 `.preferredColorScheme(.dark)` · 버튼 색 `Color.brand` 배경 + **`Color.brandForeground` 글자**(Ralli 는 `.black`)

| tag | imageName | videoName | 그 밖 |
|---|---|---|---|
| 0 | `OnboardingMode` | `onboarding-mode` | `isActive: page == 0` |
| 1 | `OnboardingCrown` | `onboarding-crown` | `isActive: page == 1` |
| 2 | `OnboardingComplication` | — | overlay `OnboardingComplicationRing()` |
| 3 | `OnboardingHealth` | — | |

- [ ] **Step 4: 앱 진입** — `iOSApp.swift` 에 `@AppStorage("onboardingSeenVersion") private var onboardingSeenVersion = 0` 과
  Ralli `TennisCounterApp.body` 와 같은 `else if OnboardingGate.shouldShow(...)` 분기. `onFinished` 는 `withAnimation { onboardingSeenVersion = OnboardingGate.version }`

- [ ] **Step 5: 빌드 · 테스트 · 린트**

Run: `xcodebuild -workspace YJApps.xcworkspace -scheme GolfCounter -destination "id=$IOS" test` → 전체 PASS (`StringsParityTests` 포함)
Run: `make lint && make format` → 골프 위반 0

- [ ] **Step 6: 시뮬레이터 확인** (그림이 아직 없어 빈 박스가 정상)
  - 새 설치 → 런치 화면 뒤 온보딩. **시스템 라이트 모드에서도** 검정 배경 + 흰 제목, 끝나면 탭 화면은 라이트로 돌아온다
  - 1페이지에서 **건너뛰기** → 앱 종료 후 재실행 → 안 뜬다
  - `xcrun simctl spawn $IOS defaults delete com.yj.GolfCounter onboardingSeenVersion` → 재실행 → 뜬다 (업데이트 사용자와 같은 상태). 4페이지까지 **시작하기** → 재실행 → 안 뜬다
  - 설치된 가장 작은 iPhone 시뮬레이터(`xcrun simctl list devices available | grep -E 'SE|mini'`) + 앱 언어 English → 1페이지 영어 본문이 3줄 안, 버튼과 겹치지 않음
  - 손쉬운 사용 › 동작 줄이기 켬 → 영상 자리에 정지 이미지 이름으로 뜬다(그림이 없으니 빈 박스)

- [ ] **Step 7: 커밋**

```bash
git add Apps/GolfCounter/iOSApp/Features/Onboarding Apps/GolfCounter/iOSApp/iOSApp.swift Apps/GolfCounter/iOSApp/ko.lproj/Localizable.strings Apps/GolfCounter/iOSApp/en.lproj/Localizable.strings
git commit -m "✨ feat: 골프 첫 실행에 온보딩 4장을 띄운다"
```

### Task 3: 1페이지 — 퍼팅 모드 전환 영상

**Files:**
- Create: `tools/store-assets/mockups/golf-onboarding.html` — 장면 `golfOnboardingMode` (Task 4 가 같은 파일에 `golfOnboardingCrown` 을 더한다)
- Create: `Apps/GolfCounter/iOSApp/Resources/Onboarding/onboarding-mode.mp4`
- Create: `Apps/GolfCounter/iOSApp/Assets.xcassets/OnboardingMode.imageset/{Contents.json, mode.png}` — 로컬라이즈 없음
- Modify: `tools/store-assets/README.md` (시안 표 + "앱 안에서 재생할 영상" 절에 골프 명령)
- 같이 커밋: 아직 추적되지 않은 `tools/store-assets/mockups/golf-header.html` · `golf-search.html` 과 README 의 기존 골프 변경 (이 시안이 그 렌더링을 가져온다)

**Interfaces:**
- Consumes: Task 2 의 영상 이름 규칙 — 언어 공통이므로 `onboarding-mode.mp4` 한 개
- Produces: `golf-onboarding.html` 의 `IMG` · 워치 그리기 함수 (Task 4·5 가 재사용)

- [ ] **Step 1: 시안** — `golf-search.html` 의 워치·탭 표시 코드를 가져와 **왼쪽 문구(`label`) 없이** 워치만 1200×1500 가운데에 그린다.
  `golfOnboardingMode(ctx, W, H, t, lang)` · 주기 10초(검색 장면과 같다) · 입력 `../inputs/golf-watch.png`, `../inputs/golf-swing-icon.png`.
  **오른쪽 위 모드 버튼을 누르는 순간의 탭 표시가 이 크기에서 분명히 보여야 한다** — 브라우저로 열어 확인하고, 약하면 그 탭만 키운다

- [ ] **Step 2: 출력** (`tools/store-assets/` 에서)

```bash
python3 video/build-render.py mockups/golf-onboarding.html out/onb-golf-mode --scene golfOnboardingMode --size 1200x1500 --seconds 10 --images inputs/golf-watch.png inputs/golf-swing-icon.png
python3 video/capture.py out/onb-golf-mode
swift -swift-version 5 video/encode.swift out/onb-golf-mode/frames out/onboarding-mode.mp4 30 no-audio
swift -swift-version 5 video/grab.swift out/onboarding-mode.mp4 out/onb-golf-mode
```
Expected: `길이 10.000 초 · 프레임 300`, 트랙 `vide 1200x1500` 하나 (soun 없음)

- [ ] **Step 3: 확인** — grab 프레임 4장을 열어 이음매(0초 ≈ 마지막)와 모드 버튼 탭 표시를 본다. 사용자에게 보이고 승인받는다

- [ ] **Step 4: 앱에 넣기** — mp4 를 `Resources/Onboarding/` 로 복사. 정지 이미지는 **퍼팅 모드로 바뀐 직후**(주황 버튼 + 초록 링이 보이는) 프레임을 `out/onb-golf-mode/frames/` 에서 골라 `mode.png` 로

- [ ] **Step 5: README** — 시안 표에 `golf-onboarding.html` 행, "앱 안에서 재생할 영상" 절에 Step 2 명령과 복사 위치

- [ ] **Step 6: 시뮬레이터 확인** — 1페이지에서 영상이 반복 재생, 2페이지로 넘기면 멈추고 돌아오면 다시 돈다. 음악 앱 재생 중 온보딩을 열어도 음악이 계속된다. 동작 줄이기 켬 → `mode.png`

- [ ] **Step 7: 커밋**

```bash
git add tools/store-assets/mockups/golf-onboarding.html tools/store-assets/mockups/golf-header.html tools/store-assets/mockups/golf-search.html tools/store-assets/README.md Apps/GolfCounter/iOSApp/Resources/Onboarding/onboarding-mode.mp4 Apps/GolfCounter/iOSApp/Assets.xcassets/OnboardingMode.imageset
git commit -m "✨ feat: 골프 온보딩 1페이지에 퍼팅 모드 전환 영상을 넣는다"
```

---

**Task 4~6 은 사용자 스크린샷이 와야 시작한다.** 받을 것은 스펙 "사용자에게 받을 것" 표. 받은 파일은 `tools/store-assets/inputs/` 에 둔다
(`golf-scorecard*.png` · `golf-face-complication.png` · `golf-health-{ko,en}.png` — 이름은 받을 때 정한다).

### Task 4: 2페이지 — 크라운 → 스코어카드 영상

**Files:**
- Modify: `tools/store-assets/mockups/golf-onboarding.html` — 장면 `golfOnboardingCrown`
- Create: `Apps/GolfCounter/iOSApp/Resources/Onboarding/onboarding-crown.mp4` (스코어카드에 한국어 글자가 있으면 `onboarding-crown-ko.mp4` · `-en.mp4`)
- Create: `Apps/GolfCounter/iOSApp/Assets.xcassets/OnboardingCrown.imageset/` (두 벌이면 Ralli `OnboardingHealth` 처럼 `"localizable": true` + `locale` ko/en)
- Modify: `tools/store-assets/README.md`

- [ ] **Step 1: 언어 판정** — 받은 스코어카드 스크린샷에 한국어가 있으면 두 벌(`--lang ko|en`), 없으면 한 벌
- [ ] **Step 2: 시안** — 1200×1500. 카운터 화면이 위로 밀려나고 스코어카드가 올라오는 세로 페이지 전환 + 크라운 옆 회전 표시(Ralli `crownTurn` 과 같은 언어). 반복 주기는 시안에서 정하고 `--seconds` 를 같게
- [ ] **Step 3: 출력 · 확인** — Task 3 Step 2~3 과 같은 명령, 장면·파일명만 바꿔서. 사용자 승인
- [ ] **Step 4: 앱에 넣기** — mp4 복사, 정지 이미지는 스코어카드가 다 올라온 프레임
- [ ] **Step 5: 시뮬레이터 확인** — 2페이지 재생, ko/en 이면 앱 언어를 바꿔 각각
- [ ] **Step 6: 커밋** — `✨ feat: 골프 온보딩 2페이지에 크라운 스코어카드 영상을 넣는다`

### Task 5: 3페이지 — 컴플리케이션

**Files:**
- Modify: `tools/store-assets/mockups/golf-onboarding.html` — 정지 장면 `golfOnboardingFace` (워치 렌더링에 문자판 스크린샷을 끼운다)
- Create: `Apps/GolfCounter/iOSApp/Assets.xcassets/OnboardingComplication.imageset/`
- Modify: `Apps/GolfCounter/iOSApp/Features/Onboarding/Components/OnboardingComplicationRing.swift` — `center` · `diameter`

- [ ] **Step 1: 이미지** — 1200×1500 한 프레임 PNG (`capture.py` 로 0초 프레임 하나, 또는 `--seconds` 를 1/30 로). 링은 굽지 않는다
- [ ] **Step 2: 언어** — 문자판에 다른 컴플리케이션의 한국어가 섞여도 한 장으로 간다(Ralli 와 같은 판단). 사용자에게 보일 때 그 사실을 같이 알린다
- [ ] **Step 3: 링 위치** — 이미지 안 GolfCounter 아이콘의 중심·지름을 이미지 폭 비율로 재서 `center` · `diameter` 에 (`watch-images/measure.py` 를 써도 된다)
- [ ] **Step 4: 시뮬레이터 확인** — 링이 아이콘을 정확히 두르고 숨 쉰다. 동작 줄이기 켬 → 링은 멈춘 채 보인다
- [ ] **Step 5: 커밋** — `✨ feat: 골프 온보딩 3페이지에 컴플리케이션 그림을 넣는다`

### Task 6: 4페이지 — 건강 앱

**Files:**
- Create: `Apps/GolfCounter/iOSApp/Assets.xcassets/OnboardingHealth.imageset/{Contents.json, health-ko.png, health-en.png}` — Ralli `OnboardingHealth.imageset/Contents.json` 과 같은 로컬라이즈 구성

- [ ] **Step 1: 넣기** — 받은 폰 스크린샷 두 장 그대로 (목업 없음). 폭 570px 이상인지 확인(스펙·Ralli 규격)
- [ ] **Step 2: 시뮬레이터 확인** — 앱 언어 한국어 / English 로 각각 4페이지 그림이 바뀐다
- [ ] **Step 3: 커밋** — `✨ feat: 골프 온보딩 4페이지에 건강 앱 그림을 넣는다`

### Task 7: 마무리 — 전체 확인 · TODO · PR

**Files:**
- Modify: `TODO.md` (GolfCounter 절의 온보딩 행 상태)

- [ ] **Step 1: 전체 테스트 · 린트** — Task 2 Step 5 명령. 전부 PASS / 위반 0
- [ ] **Step 2: 시뮬레이터 4장 통과** — Review Focus 5개를 그림이 다 찬 상태로 한 번 더
- [ ] **Step 3: TODO** — 온보딩 행을 "구현 완료 (PR #n) · 실기기 확인 대기 · 2.1.2 에 실림" 으로
- [ ] **Step 4: PR** — `gh pr create` (본문: 스펙 · 플랜 링크, 4장 스크린샷, 실기기 확인 목록). 머지는 사용자가 확인한 뒤 `gh pr merge <n> --merge --delete-branch`

실기기 확인 목록(PR 본문): 영상이 끊김 없이 반복 · 1페이지 문구대로 워치에서 퍼팅 모드가 바뀐다 · 업데이트 설치(App Store 2.1.1 위에 Xcode 설치)에서 온보딩이 뜬다.
출시 노트(`APPSTORE.md`)의 온보딩 한 줄은 2.1.2 출시 커밋에서 쓴다 (스펙 "출시").
