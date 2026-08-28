# CI 파이프라인 설계 — yj-apps

작성일: 2026-08-27
갱신일: 2026-08-28 — 모노레포 전환 실행 결과를 반영해 4·5·6절 정정
상태: 설계 완료, 실행 대기
선행 조건: `2026-08-27-monorepo-migration-design.md` — **충족** (6절 참조)

---

## 1. 배경

모노레포 전환 이전 `golf_counter`, `tennis_counter`, `ralli-kit` 세 레포 모두 **CI가 없었다.**
`.github/workflows`, fastlane, Gemfile 어느 것도 존재하지 않았고, 전환 후 `yj-apps`도 마찬가지다.
빌드·테스트·린트는 전부 로컬 수동 실행이다.

전환으로 깨질 파이프라인이 없다는 뜻이므로, **전환 직후인 지금이 CI를 새로 붙이기 가장 좋은 시점**이다.

### 모노레포에서 CI가 특히 중요한 이유

전환으로 `Packages/YJKit`은 로컬 패키지가 되어, 코어를 수정하면 두 앱(그리고 앞으로 추가될 앱들)에
즉시 반영된다. 이는 전환의 목적이지만 동시에 **코어 한 줄 수정이 전 앱을 깨뜨릴 수 있다**는 뜻이기도
하다. 지금은 앱이 2개라 수동 확인이 가능하지만 4~5개가 되면 불가능하다.

CI는 이 위험에 대한 안전망이며, 앱이 늘어날수록 값어치가 커진다.

---

## 2. 목표와 비목표

### 목표

- PR을 열면 린트·테스트·빌드가 자동 실행되고, 결과가 PR에 표시된다.
- **변경 범위에 따라 실행 대상을 좁힌다.** 한 앱만 바뀌면 그 앱만, 코어가 바뀌면 전부.
- 시뮬레이터 이름이나 Xcode 기본 버전 변경에 쉽게 깨지지 않는다.

### 비목표

- App Store 배포 자동화 (fastlane, 인증서·API 키 관리) — CI가 안정화된 후 별도 검토
- 스크린샷 자동 생성
- 코드 커버리지 리포팅 — 필요해지면 추가
- **워치↔iOS 연동 동작 확인** — 실기기가 필요한 검증이라 CI 스코프 밖이다.
  전환 문서 6단계의 보류 항목이며 TestFlight 배포 시점에 확인한다. CI는 서명 없이
  시뮬레이터에서 빌드·테스트만 하므로 이 항목을 대체하지 못한다.

---

## 3. 비용

**GitHub Actions의 macOS 러너는 public 레포에서 무료·무제한이다.** `yj-apps`는 public이다
(전환 문서 D5).

> **private 전환 시 주의.** private 레포에서 macOS 러너는 **분당 10배**로 차감된다. 무료 한도
> 2,000분이 실질 200분이 되고, iOS 빌드 1회가 5~10분이므로 월 20~40회에 소진된다. private으로
> 바꿀 계획이 생기면 CI 비용을 먼저 재검토해야 한다.

---

## 4. 워크플로 설계

### 파일

```
.github/workflows/ci.yml
```

### 트리거

- `pull_request` — 대상 브랜치 `main`
- `push` — `main` (머지 후 전체 검증)

### Job 구성

```
┌─ changes ──────────────────────────────────────────┐
│  변경 경로 판별 → 이후 job들의 실행 여부를 결정     │
│    Packages/YJKit/**   → kit=true, golf=true,      │
│                          tennis=true (전부)        │
│    Apps/GolfCounter/** → golf=true                 │
│    Apps/TennisCounter/** → tennis=true             │
│    루트 설정 파일       → 전부                      │
└────────────────────────────────────────────────────┘
        │
        ├─→ lint         (make lint + make format)
        ├─→ kit-test     (xcodebuild — Packages/YJKit, 아래 주의)
        ├─→ golf         (iOS 빌드+테스트, watchOS 빌드+테스트)
        └─→ tennis       (iOS 빌드+테스트, watchOS 빌드+테스트)
```

`changes` job이 핵심이다. `Apps/GolfCounter/`만 수정된 PR에서 tennis 빌드를 돌리지 않는다.
반대로 `Packages/YJKit/`이 수정되면 **전 앱을 빌드한다** — 코어 변경의 파급을 잡는 것이 목적이므로
여기서 좁히면 안 된다.

### 사용할 스킴 — 공유 스킴 7개

전환 4단계에서 이름 충돌을 제거하고 공유 처리했다. `-scheme` 인자에 그대로 쓸 수 있다.

| 앱 | 스킴 | 플랫폼 |
|---|---|---|
| golf | `GolfCounter` | iOS |
| golf | `GolfCounter Watch App` | watchOS |
| golf | `GolfComplicationExtension` | watchOS |
| tennis | `TennisCounter` | iOS |
| tennis | `TennisCounter Watch App` | watchOS |
| tennis | `RalliComplicationExtension` | watchOS |
| tennis | `TennisLiveActivityExtension` | iOS |

테스트는 **앱 스킴 4개**로 돌린다. 각 앱 스킴의 `TestAction`이 테스트 타깃을 이미 포함하므로
테스트 전용 스킴은 없다. 확장 스킴 3개는 빌드만 한다.

빌드·테스트는 **워크스페이스 기준**이다. `-project`가 아니라 `-workspace YJApps.xcworkspace`를 쓴다.

### `kit-test`는 `swift test`가 아니다 — 정정

> 초안에서 `kit-test`를 `swift test`로 적었으나 **이 패키지에서는 동작하지 않는다.**

`Packages/YJKit/Package.swift`가 `platforms: [.iOS(.v17), .watchOS(.v10)]`만 선언하고 macOS를
빼놓았다(ralli-kit 시절 `🔧 macOS 플랫폼 지원 제거` 커밋). 호스트 빌드를 시도하면 SwiftData API가
macOS 14 미만으로 판정되어 **51개 컴파일 에러**가 난다. 전환 이전 원본 `ralli-kit`에서도 동일하게
실패하므로 전환과 무관한 기존 특성이다.

따라서 iOS 시뮬레이터 destination으로 `xcodebuild`를 써야 한다. 루트 `Makefile`의 `kit-test`
타깃이 이미 이 형태이며, CI는 이를 재사용한다.

```bash
cd Packages/YJKit && xcodebuild -scheme YJKit-Package -destination '<iOS 시뮬레이터>' test
# 로컬 실측: 51 tests in 6 suites passed
```

### 예상 소요

| Job | 소요 |
|---|---|
| lint | ~1분 |
| kit-test | ~2분 |
| golf (iOS + watchOS) | ~10분 |
| tennis (iOS + watchOS) | ~10분 |

앱 job들은 병렬 실행된다. 코어 변경 PR의 최악 소요는 약 12분, 단일 앱 변경은 약 10분.

> 참고로 로컬 클린 빌드(DerivedData 삭제 후) 실측은 공유 스킴 7개 합계 **106초**였다. CI 러너는
> 캐시가 없고 시뮬레이터 부팅·패키지 해석이 매번 붙으므로 위 추정치가 이보다 훨씬 크다.

---

## 5. 안정성 설계 — 깨지기 쉬운 지점

CI 세팅 공수의 대부분이 여기에 들어간다.

### 5.1 시뮬레이터 이름 하드코딩 — 가정이 아니라 **실제로 재현된 문제**

초안에서는 우려 사항으로 적었으나, 전환 2단계에서 실제로 빌드가 실패했다. 원인은 러너의 Xcode
버전 변경이 아니라 **런타임이 여러 개 설치되면 같은 기기 이름이 중복된다**는 점이다.

2026-08-28 로컬 실측:

```
-- iOS 26.4 --      iPhone 17 Pro (6392DD86-…)
-- iOS 26.5 --      iPhone 17 Pro (CB44AC14-…)
-- watchOS 26.4 --  Apple Watch Series 11 (46mm) (C794C8B4-…)
-- watchOS 26.5 --  Apple Watch Series 11 (46mm) (D7B72A34-…)
```

`-destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`은 두 기기에
동시에 매칭되어 실패한다. iPhone도 동일한 상태다. 기기명 하드코딩은 러너 이미지에 런타임이
둘 이상 들어오는 순간 깨진다.

**대응(필수).** 워크플로 안에서 `xcrun simctl list devices available --json`으로 조회해 UDID를
동적으로 선택하고 `-destination "id=<UDID>"`로 지정한다. 선택 규칙은 다음과 같이 결정적이어야 한다.

- 대상 플랫폼(iOS / watchOS)의 **사용 가능한 런타임 중 최신 하나**를 고른다
- 그 런타임 안에서 기기 이름 패턴(`iPhone 17*`, `Apple Watch*`)으로 후보를 찾는다
- 후보가 0개면 **빌드를 실패시킨다.** 조용히 다른 기기로 대체하지 않는다

각 앱의 `CLAUDE.md`에도 워치 destination은 UDID로 지정하라는 주의가 이미 반영되어 있다.

### 5.2 Xcode 버전 고정

러너의 기본 Xcode가 바뀌면 빌드 결과가 흔들린다. `xcode-select`로 사용할 버전을 명시하고, 그 값을
워크플로 상단 한 곳(`env`)에서 관리한다.

로컬 환경 실측(2026-08-28): **Xcode 26.6 (17F113) / Swift 6.3.3**. 로컬과 CI의 버전을 맞춰두면
"로컬은 되는데 CI는 안 되는" 상황을 줄일 수 있다.

> 러너 이미지에 Xcode 26.6이 실제로 존재하는지는 워크플로 첫 실행 때 확인해야 한다. 없으면
> 사용 가능한 최신 버전으로 내리고 그 값을 이 문서에 기록한다. 두 앱의 `--swiftversion`이
> 5.0/6.0으로 다른 상태이나 이는 swiftformat 설정일 뿐 컴파일러 버전과 무관하다.

### 5.3 코드 서명

**빌드·테스트만 하므로 서명이 필요 없다.** `CODE_SIGNING_ALLOWED=NO`로 끄면 인증서·프로비저닝
프로파일을 CI에 올릴 필요가 없다. 이것이 비목표에서 배포 자동화를 뺀 이유이기도 하다 — 배포를 넣는
순간 시크릿 관리라는 완전히 다른 문제가 따라온다.

### 5.4 lint 기준선은 초록이어야 한다

CI의 lint job은 `make lint`(swiftlint)와 `make format`(swiftformat --lint)을 쓴다. 두 명령 모두
위반이 있으면 `exit 1`이므로, **기준선에 위반이 하나라도 남아 있으면 첫 PR부터 실패한다.**

전환 시점 기준선에는 tennis에 1건이 남아 있었다
(`MatchDetailSheet.swift:16 trailingCommas`). 전환 중에는 "코드 diff 0" 원칙 때문에 의도적으로
남겨둔 것이었고, CI 착수에 앞서 정리했다.

```
make lint    golf 0 violations / tennis 0 violations
make format  golf 0/96          / tennis 0/93
```

앞으로 lint 규칙을 추가할 때도 같은 순서를 지킨다 — **규칙을 켜기 전에 기존 위반을 먼저 정리한다.**

---

## 6. 전환 문서와의 연결 — 선행 조건 충족 확인

CI가 제대로 동작하려면 전환 문서의 다음 항목이 선행되어야 한다. **2026-08-28 기준 전부 충족.**

| 전환 문서 항목 | CI에서 필요한 이유 | 상태 |
|---|---|---|
| 3단계 — 스킴 공유 전환 | user-level 스킴은 커밋되지 않아 CI에서 보이지 않는다 | ✅ 공유 스킴 7개 |
| 4단계 — 타깃·스킴 이름 정리 | `ComplicationAppExtension`이 양쪽에 있으면 `-scheme` 인자가 모호해진다 | ✅ 스킴·번들 ID 중복 0 |
| 5단계 — Makefile 앱 순회 | CI 스크립트가 Makefile 타깃을 재사용할 수 있다 | ✅ lint / format / fix / kit-test |

### 전환의 미완 항목은 CI를 막지 않는다

전환 문서에 남아 있는 두 항목은 CI와 스코프가 겹치지 않는다.

- **6단계 워치↔iOS 연동 실기기 확인** — 서명·실기기가 필요해 CI가 검증할 수 있는 영역이 아니다.
  TestFlight 배포 시점 항목으로 이월되어 있다 (2절 비목표 참조).
- **7단계 원본 3개 레포 archive** — 저장소 정리 작업이며 파이프라인과 무관하다.

---

## 7. 공수

| 항목 | 공수 |
|---|---|
| 워크플로 초안 작성 (changes / lint / kit-test / 앱 job) | 0.25일 |
| 시뮬레이터 동적 선택 + Xcode 버전 고정 검증 | 0.25~0.5일 |
| 실제 PR로 반복 실행하며 안정화 | 0.25일 |
| **합계** | **0.5~1일** |

실행 시간의 상당 부분이 "CI에서만 재현되는 문제"를 잡는 반복 사이클이다. 로컬에서 검증할 수 없어
푸시 → 결과 확인을 반복해야 한다.

---

## 8. 후속 검토 항목

- 브랜치 보호 규칙 — CI 통과를 머지 조건으로 강제할지
- 앱이 3개 이상이 되었을 때 job 매트릭스로 전환할지
- 코드 커버리지 리포팅
- 배포 자동화 (fastlane + App Store Connect API 키)
