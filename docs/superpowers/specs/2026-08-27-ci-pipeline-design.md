# CI 파이프라인 설계 — yj-apps

작성일: 2026-08-27
상태: 설계 완료, 실행 대기
선행 조건: `2026-08-27-monorepo-migration-design.md` 전환 완료

---

## 1. 배경

현재 `golf_counter`, `tennis_counter`, `ralli-kit` 세 레포 모두 **CI가 없다.** `.github/workflows`,
fastlane, Gemfile 어느 것도 존재하지 않는다. 빌드·테스트·린트는 전부 로컬 수동 실행이다.

전환으로 깨질 파이프라인이 없다는 뜻이므로, **전환 직후가 CI를 새로 붙이기 가장 좋은 시점**이다.

### 모노레포에서 CI가 특히 중요한 이유

전환 후 `Packages/YJKit`은 로컬 패키지가 되어, 코어를 수정하면 두 앱(그리고 앞으로 추가될 앱들)에
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

---

## 3. 비용

**GitHub Actions의 macOS 러너는 public 레포에서 무료·무제한이다.** 현재 `golf_counter`,
`tennis_counter`는 public이며, `yj-apps`도 public을 유지한다 (전환 문서 D5).

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
        ├─→ lint         (변경된 앱 대상 swiftlint + swiftformat --lint)
        ├─→ kit-test     (swift test — Packages/YJKit)
        ├─→ golf         (iOS 빌드+테스트, watchOS 빌드+테스트)
        └─→ tennis       (iOS 빌드+테스트, watchOS 빌드+테스트)
```

`changes` job이 핵심이다. `Apps/GolfCounter/`만 수정된 PR에서 tennis 빌드를 돌리지 않는다.
반대로 `Packages/YJKit/`이 수정되면 **전 앱을 빌드한다** — 코어 변경의 파급을 잡는 것이 목적이므로
여기서 좁히면 안 된다.

### 예상 소요

| Job | 소요 |
|---|---|
| lint | ~1분 |
| kit-test | ~2분 |
| golf (iOS + watchOS) | ~10분 |
| tennis (iOS + watchOS) | ~10분 |

앱 job들은 병렬 실행된다. 코어 변경 PR의 최악 소요는 약 12분, 단일 앱 변경은 약 10분.

---

## 5. 안정성 설계 — 깨지기 쉬운 지점

CI 세팅 공수의 대부분이 여기에 들어간다. 세 가지가 핵심이다.

### 5.1 시뮬레이터 이름 하드코딩

현재 각 앱의 `CLAUDE.md`에는 이렇게 적혀 있다.

```
xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
# watch 빌드 (기기명은 xcrun simctl list devices available로 확인)
```

기기명을 직접 적으면 **러너의 Xcode 버전이 올라가 해당 기기가 사라지는 순간 CI가 깨진다.** 로컬에서는
`simctl list`로 확인하면 되지만 CI에서는 그럴 수 없다.

대응: 기기 이름 대신 OS 기준으로 지정하거나, 워크플로 내에서 `simctl list --json`으로 사용 가능한
기기를 조회해 동적으로 선택한다. 후자가 더 견고하다.

### 5.2 Xcode 버전 고정

러너의 기본 Xcode가 바뀌면 빌드 결과가 흔들린다. `xcode-select`로 사용할 버전을 명시하고, 그 값을
워크플로 상단 한 곳에서 관리한다.

현재 로컬 환경은 **Xcode 26.6 / Swift 6.3.3**이다. 로컬과 CI의 버전을 맞춰두면 "로컬은 되는데 CI는
안 되는" 상황을 줄일 수 있다.

### 5.3 코드 서명

**빌드·테스트만 하므로 서명이 필요 없다.** `CODE_SIGNING_ALLOWED=NO`로 끄면 인증서·프로비저닝
프로파일을 CI에 올릴 필요가 없다. 이것이 비목표에서 배포 자동화를 뺀 이유이기도 하다 — 배포를 넣는
순간 시크릿 관리라는 완전히 다른 문제가 따라온다.

---

## 6. 전환 문서와의 연결

CI가 제대로 동작하려면 전환 문서의 다음 항목이 선행되어야 한다.

| 전환 문서 항목 | CI에서 필요한 이유 |
|---|---|
| 3단계 — 스킴 공유 전환 | user-level 스킴은 커밋되지 않아 CI에서 보이지 않는다 |
| 4단계 — 타깃·스킴 이름 정리 | `ComplicationAppExtension`이 양쪽에 있으면 `-scheme` 인자가 모호해진다 |
| 5단계 — Makefile 앱 순회 | CI 스크립트가 Makefile 타깃을 재사용할 수 있다 |

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
