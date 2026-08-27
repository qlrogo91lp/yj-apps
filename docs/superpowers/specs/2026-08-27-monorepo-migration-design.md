# 모노레포 전환 설계 — yj-apps

작성일: 2026-08-27
상태: 승인됨, 실행 대기

---

## 1. 배경

현재 3개 레포가 분리되어 있다.

| 레포 | 성격 | Swift LOC | 커밋 | git 크기 |
|---|---|---|---|---|
| `golf_counter` | iOS + Watch + Complication 앱 | 6,576 | 228 | 948 KiB |
| `tennis_counter` | iOS + Watch + Complication + LiveActivity 앱 | 7,631 | 309 | 1.13 MiB |
| `ralli-kit` | SPM 공용 라이브러리 | ~1,000 | 18 | 55 KiB |

두 앱은 `ralli-kit`을 **원격 SPM `branch: main`** 으로 참조하며 `WorkoutCore` / `WorkoutUI` /
`ConnectivityCore` / `PersistenceCore` 4개 프로덕트를 사용한다. 즉 공용 코어 계층은 이미 분리되어
있고, 구조상 모노레포 직전 상태다.

### 현재 구조의 문제

1. **버전 핀이 없다.** `branch = main` 참조라 `ralli-kit`에 커밋하는 순간 두 앱이 동시에 영향받는다.
   실제로 로컬 `ralli-kit`이 `origin/main`보다 15커밋 뒤처져 있고, 로컬 `Package.swift`에는
   `WorkoutUI`가 없는데 두 앱 pbxproj는 이미 `WorkoutUI`를 참조한다. 로컬만으로는 빌드되지 않는 상태다.

2. **로컬 override 수작업.** `golf_counter/CLAUDE.md`에 "ralli-kit을 고칠 땐 로컬 폴더를 Xcode
   워크스페이스에 끌어다 놓고, 끝나면 제거하라"는 절차가 문서화되어 있다. 이 절차 자체가 마찰의 증거다.

3. **앱 간 복붙 중복.** `Makefile`(두 파일 완전 동일), `.swiftlint.yml`, `.swiftformat`,
   `BrandColor.swift`, `StatCard`, `LaunchScreenView`, `UndoButton`, `ComplicationApp` 스캐폴딩,
   `CLAUDE.md` 작업 규약. 앱이 늘어날수록 배수로 증가한다.

4. **코어 변경의 원자성이 없다.** 코어와 앱을 같이 고치려면 레포 2개에 PR 2개를 순서 지켜 머지해야 한다.

### 전환 시점의 근거

앞으로 앱 1~2개가 추가될 예정이다. 현재 방식으로 새 앱을 추가하면 스캐폴딩·툴링 복붙에 앱당 0.5~1일이
들고, 전환 후에는 0.5일 이하로 떨어진다. 4번째 앱부터 누적 이득이 전환 공수를 넘는다.

또한 **CI가 아직 없어 전환으로 깨질 파이프라인이 없다.** 리스크가 가장 낮은 시점이다.

---

## 2. 목표와 비목표

### 목표

- 3개 레포를 `yj-apps` 단일 저장소로 통합하고 **555개 커밋 히스토리를 전부 보존**한다.
- `ralli-kit`을 로컬 SPM 패키지 `Packages/YJKit`으로 전환해 **코어와 앱의 변경을 원자화**한다.
- Xcode 워크스페이스 하나로 전 앱을 열고 빌드할 수 있게 한다.
- 이름 충돌(타깃·스킴·테스트 번들 ID)을 제거해 CLI 빌드가 모호하지 않게 한다.
- **앱의 동작·번들 ID·버전·사용자 데이터는 일절 변경하지 않는다.**

### 비목표 (이번 전환 스코프 밖)

- 중복 UI의 `DesignKit` 타깃 추출 → 별도 후속 작업
- CI 구축 → `2026-08-27-ci-pipeline-design.md`
- 코드 스타일 규칙 통일 (swiftversion 5.0/6.0 등) → `2026-08-27-code-style-tooling-design.md`
- fastlane 배포 자동화
- 배포 타깃 `17.0` / `26.4` 혼재 정리
- 앱 기능 변경

---

## 3. 목표 구조

```
yj-apps/
├─ Packages/
│  └─ YJKit/                        # ralli-kit → 로컬 패키지
│     ├─ Package.swift              # name: "YJKit" (products 이름은 불변)
│     ├─ Sources/{WorkoutCore, WorkoutUI, ConnectivityCore, PersistenceCore}/
│     └─ Tests/
├─ Apps/
│  ├─ GolfCounter/                  # 기존 golf_counter 내용 그대로
│  │  ├─ GolfCounter.xcodeproj
│  │  ├─ iOSApp/ WatchApp/ ComplicationApp/ Shared/
│  │  ├─ .swiftlint.yml  .swiftformat        # 앱별 설정 유지
│  │  ├─ CLAUDE.md                           # 앱별 아키텍처
│  │  └─ docs/
│  └─ TennisCounter/                # 기존 tennis_counter 내용 그대로
├─ YJApps.xcworkspace               # Packages/YJKit + Apps/*
├─ Makefile                         # 앱별 build/test/lint 타깃
├─ .swiftlint.yml                   # 공통 규칙 (앱이 parent_config로 상속)
├─ .gitignore
├─ CLAUDE.md                        # 공통 작업 규약
└─ docs/superpowers/specs/
```

### 이름 결정

| 층위 | 이름 | 근거 |
|---|---|---|
| 레포 | `yj-apps` | 번들 ID 네임스페이스가 이미 `com.yj.*`. 종목에 묶이지 않아 비스포츠 앱도 수용 |
| 패키지 | `YJKit` | `RalliKit`은 **테니스 앱의 브랜드 이름**이었다. 골프 앱이 남의 브랜드를 import하는 구조를 해소 |
| 앱 브랜드 | 각자 유지 | 테니스의 `Ralli` 리브랜딩 계획(`tennis_counter/docs/brainstorming-roadmap.md`)은 그대로 진행 |

> 패키지 이름 변경 비용은 사실상 0이다. 앱 코드는 `import WorkoutCore` 등 **프로덕트 이름**만 쓰므로
> `RalliKit` 문자열은 `Package.swift`의 `name:` 한 줄과 pbxproj 참조에만 존재한다. import 문은
> 한 줄도 바뀌지 않는다.

---

## 4. 결정 사항

| # | 결정 | 내용 | 근거 |
|---|---|---|---|
| D1 | swiftformat 버전 | **이번 전환에서는 손대지 않는다.** 각 앱 현재 값 유지 (golf `5.0` / tennis `6.0`) | 5 vs 6 판단은 문서 [3]으로 분리. 전환은 코드 diff 0을 유지 |
| D2 | swiftlint 설정 | 루트 공통 + 앱별 `parent_config` 상속 | 두 앱의 규칙이 실제로 다르다(golf `force_unwrapping` opt-in, tennis `type_name` 예외). 단일 설정은 서로에게 무관한 경고를 강제한다 |
| D3 | 타깃 이름 | 확장·테스트 타깃만 개명. **메인 앱·워치 앱 타깃은 건드리지 않는다** | `PRODUCT_NAME = "$(TARGET_NAME)"` 이므로 타깃 개명이 산출물 파일명을 바꾼다 |
| D4 | 기존 3개 레포 | Archive(읽기 전용). 삭제는 전환 완료 + 릴리즈 1회 통과 후 재판단 | Issues·PR 토론은 git이 아니라 GitHub DB에 있어 삭제 시 영구 소실 |
| D5 | 공개 범위 | public 유지 | private 전환 시 GitHub Actions macOS 러너가 분당 10배 차감 |

### D2 검증 결과

SwiftLint 0.64.1에서 `parent_config` 상속이 정상 동작함을 실측 확인했다.

```
/tmp/sltest/.swiftlint.yml       → disabled_rules: [todo]
/tmp/sltest/app/.swiftlint.yml   → parent_config: ../.swiftlint.yml + type_name excluded
결과: Found 0 violations   (부모 규칙 상속 + 자식 예외 둘 다 적용됨)
```

앱별 `.swiftlint.yml`의 `included:` 상대 경로(`iOSApp`, `WatchApp`, `Shared` 등)를 그대로 둘 수 있어,
각 앱 폴더에서 실행하면 전환 전과 동일하게 동작한다. 새 앱 추가 시 루트 파일을 수정할 필요도 없다.

### D3 개명 대상

| 타깃 | 현재 | 변경 후 |
|---|---|---|
| golf 컴플리케이션 | `ComplicationAppExtension` | `GolfComplicationExtension` |
| tennis 컴플리케이션 | `ComplicationAppExtension` | `TennisComplicationExtension` |
| golf iOS 테스트 | `iosTests` | `GolfCounterTests` |
| golf watch 테스트 | `watchosTests` | `GolfCounterWatchTests` |
| tennis iOS 테스트 | `iosTests` | `TennisCounterTests` |
| tennis watch 테스트 | `watchosTests` | `TennisCounterWatchTests` |

테스트 번들 ID도 함께 분리한다 (현재 양쪽 모두 `com.yj.iosTests` / `com.yj.watchosTests`로 동일).

**사용자에게 보이는 것은 변하지 않는다.** 앱 번들 ID
(`com.yj.GolfCounter.watchkitapp.ComplicationApp` 등)는 별개 설정이며, 컴플리케이션 표시 이름은
코드의 `.configurationDisplayName(...)`에서 온다.

---

## 5. 실행 계획

각 단계는 **완료 조건을 만족해야 다음으로 넘어간다.** 실패 시 해당 단계만 롤백한다.

### 0단계 — 선행 조건

- [ ] 로컬 `ralli-kit`을 `origin/main`으로 동기화한다. **현재 15커밋 뒤처져 있어, 이 상태로 subtree하면 낡은 트리(WorkoutUI 없음)가 들어간다.**
- [ ] `golf_counter`, `tennis_counter`의 워킹 트리가 깨끗하고 `origin/main`과 동기화되어 있는지 확인한다.
- [ ] 세 레포 각각에서 현재 빌드·테스트가 통과함을 확인하고 결과를 기록한다. **이것이 전환 후 비교 기준선이다.**

완료 조건: 세 레포 모두 `origin/main`과 일치하고, 전 타깃 빌드·테스트 통과 기록이 있다.

### 1단계 — 레포 골격 + 히스토리 이관

- [ ] `yj-apps` 로컬 레포 생성 (완료)
- [ ] `git subtree add --prefix=Packages/YJKit <ralli-kit> main`
- [ ] `git subtree add --prefix=Apps/GolfCounter <golf_counter> main`
- [ ] `git subtree add --prefix=Apps/TennisCounter <tennis_counter> main`

완료 조건:
- `git log --oneline Apps/GolfCounter | wc -l` → 228 이상
- `git log --oneline Apps/TennisCounter | wc -l` → 309 이상
- `git log --oneline Packages/YJKit | wc -l` → 18 이상
- `git log --follow` 로 임의 파일의 과거 이력이 추적된다

> 커밋 메시지 안의 `#30` 같은 PR 참조는 텍스트로 남지만 링크는 새 레포를 가리키게 된다. 기존 레포를
> archive로 유지하면 원본 PR은 그대로 열람 가능하다.

### 2단계 — 패키지 로컬화 (가장 위험한 구간)

- [ ] `Packages/YJKit/Package.swift`의 `name: "RalliKit"` → `"YJKit"`. products/targets 이름은 불변
- [ ] `Apps/GolfCounter/GolfCounter.xcodeproj`: 원격 패키지 참조 제거 → 로컬 참조(`../../Packages/YJKit`) 추가
- [ ] `Apps/TennisCounter/TennisCounter.xcodeproj`: 동일
- [ ] 각 타깃의 `packageProductDependencies`가 기존과 동일한 프로덕트를 가리키는지 확인

**Xcode UI로 진행한다.** pbxproj 직접 편집은 하지 않는다. 원격 참조는
`XCRemoteSwiftPackageReference`, 로컬 참조는 `XCLocalSwiftPackageReference`로 구조가 다르고,
프로덕트 의존성 연결까지 함께 갱신되어야 한다.

완료 조건:
- 두 앱의 전 타깃이 빌드된다
- `Packages/YJKit`의 소스를 수정하면 재빌드 시 **즉시 반영된다** (푸시 없이)
- pbxproj에 `XCRemoteSwiftPackageReference`가 남아있지 않다
- `Package.resolved`에 ralli-kit 항목이 남아있지 않다

> `Package.resolved` 현황이 두 앱에서 다르다. golf는 커밋되어 있고
> (`GolfCounter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
> tennis는 파일은 있으나 git에 추가되어 있지 않다. 로컬 패키지로 전환하면 외부 의존성이 사라지므로
> 이 파일 자체가 불필요해진다. 전환 시 두 앱의 처리를 일치시킨다.

### 3단계 — 워크스페이스 + 스킴 공유

- [ ] `YJApps.xcworkspace` 생성. `Packages/YJKit`, `Apps/GolfCounter/*.xcodeproj`, `Apps/TennisCounter/*.xcodeproj` 추가
- [ ] 현재 user-level로만 존재하는 스킴(`ComplicationAppExtension`, `iosTests`, `watchosTests`)을 **공유(shared)로 전환**하여 커밋되게 한다

완료 조건: 워크스페이스를 열었을 때 스킴 선택기에 전 타깃이 나타나고, 각각 빌드된다.

### 4단계 — 이름 정리

- [ ] D3 표에 따라 확장·테스트 타깃 개명
- [ ] 테스트 번들 ID 분리
- [ ] 개명에 따라 스킴 이름과 `Embed Foundation Extensions` 빌드 페이즈가 정상 갱신되었는지 확인
- [ ] 일부 타깃에 남아있는 `MARKETING_VERSION = 1.0` 정리

완료 조건:
- `xcodebuild -workspace YJApps.xcworkspace -list`에 중복 이름이 없다
- 전 타깃 빌드·테스트 통과
- 앱 타깃의 `MARKETING_VERSION`(golf `2.1.1` / tennis `1.1.6`)과 `CURRENT_PROJECT_VERSION`(6 / 25)이 **변하지 않았다**

### 5단계 — 툴링 구조화

- [ ] 루트 `.gitignore` 통합 (golf의 것이 가장 완전하며 ralli-kit의 `.build/` 누락 시 165MB가 커밋될 수 있다)
- [ ] 루트 `.swiftlint.yml` 신설(공통 규칙) + 앱별 `.swiftlint.yml`에 `parent_config` 추가
- [ ] 앱별 `.swiftformat`은 **현재 값 그대로 유지** (D1)
- [ ] 루트 `Makefile` — 앱 순회 방식
- [ ] `CLAUDE.md` 분리: 공통 작업 규약은 루트로, 앱별 아키텍처·명령어는 각 앱 폴더로

완료 조건: **린트 결과가 전환 전과 동일하다.** 0단계에서 기록한 기준선과 비교해 새로 발생하거나
사라진 위반이 없어야 한다. (기존에 존재하던 `trailingCommas` 실패 1건은 그대로 남아 있어야 정상이다.)

### 6단계 — 최종 검증

- [ ] 전 타깃 클린 빌드 (`DerivedData` 삭제 후)
- [ ] 전 테스트 타깃 실행
- [ ] `swift test` (Packages/YJKit 단독)
- [ ] 시뮬레이터에서 두 앱 실행 — 워치↔iOS 연동 동작 확인
- [ ] 0단계 기준선과 결과 대조

### 7단계 — 마무리

- [ ] GitHub에 `yj-apps` 생성(public) 후 푸시
- [ ] 기존 3개 레포 archive
- [ ] 후속 문서 [2] CI, [3] 코드 스타일 진행 여부 판단

---

## 6. 검증 전략

전환의 성공 기준은 **"구조만 바뀌고 동작은 그대로"** 이다. 따라서 모든 검증은 0단계 기준선과의
비교로 이루어진다.

| 항목 | 기준선 | 전환 후 기대값 |
|---|---|---|
| 빌드 | 전 타깃 성공 | 동일 |
| 테스트 | 전 타깃 통과 | 동일 |
| 린트 위반 | 기록된 목록 | **동일** (증가·감소 모두 이상 신호) |
| 소스 코드 diff | — | **0** (파일 이동 외 내용 변경 없음) |
| 버전 | golf 2.1.1(6) / tennis 1.1.6(25) | 동일 |
| 번들 ID | `com.yj.*` | 앱·확장 모두 동일. 테스트 번들만 분리 |

소스 diff가 0이어야 한다는 점이 중요하다. 전환 중 코드 내용이 바뀌면 이후 문제 발생 시
"구조 이동 탓인지 코드 변경 탓인지" 가릴 수 없게 된다.

---

## 7. 롤백

각 단계는 독립 커밋으로 남기며, 실패 시 해당 커밋만 되돌린다.

전면 롤백은 **기존 3개 레포를 그대로 두는 것**으로 성립한다. 전환이 완료되고 릴리즈 1회가 정상
통과할 때까지 기존 레포는 archive 상태로 유지하며 삭제하지 않는다 (D4).

---

## 8. 리스크

| 리스크 | 영향 | 완화 |
|---|---|---|
| 2단계 패키지 참조 교체 실패 | 빌드 불가 | Xcode UI 사용, 단계 독립 커밋, 즉시 롤백 |
| `ralli-kit` 동기화 누락 | 낡은 트리 이관(WorkoutUI 없음) | 0단계 필수 확인 |
| 타깃 개명 시 `PRODUCT_NAME` 연쇄 변경 | 산출물 파일명 변경 | 메인 앱·워치 앱 타깃은 개명하지 않음 |
| `.build/` 커밋 | 레포 비대(165MB) | 1단계 이전에 루트 `.gitignore` 확인 |
| 전환 중 앱 기능 작업 병행 | 머지 충돌 | 전환 기간 동안 기능 작업 중단 |
| 릴리즈 시점 충돌 | 배포 지연 | golf 2.1.1 / tennis 1.1.6이 배포 상태. 릴리즈 사이 빈 구간에 진행 |

### 리스크가 아닌 것 (확인 완료)

- **git 태그 충돌** — 두 레포 모두 태그가 0개다. 이관 시 충돌 요인이 아니다.
- **App Store 영향** — App Store Connect는 번들 ID와 빌드 번호만 본다. 소스 저장소 위치를 알지 못한다. 리뷰·별점·다운로드 수 모두 유지된다.
- **사용자 데이터** — 번들 ID, App Group(`group.com.yj.GolfCounter` 등), SwiftData 스키마, CloudKit 컨테이너를 건드리지 않으므로 마이그레이션이 발생하지 않는다.
- **CI 중단** — 현재 CI가 없다.

---

## 9. 공수

| 단계 | 공수 |
|---|---|
| 0. 선행 조건 + 기준선 기록 | 0.25일 |
| 1. 골격 + subtree | 0.25일 |
| 2. 패키지 로컬화 | 1일 |
| 3. 워크스페이스 + 스킴 공유 | 0.25일 |
| 4. 이름 정리 | 0.25일 |
| 5. 툴링 구조화 | 0.5일 |
| 6~7. 최종 검증 + 마무리 | 0.25일 |
| **합계** | **2.75일** |

---

## 10. 후속 문서

| 문서 | 내용 | 의존성 |
|---|---|---|
| `2026-08-27-ci-pipeline-design.md` | GitHub Actions 기반 CI. path 필터로 변경된 앱만 빌드 | 이 전환 완료 후 독립 진행 |
| `2026-08-27-code-style-tooling-design.md` | SwiftFormat/SwiftLint 개념 정리 + 미결 논의 항목 (5.0 vs 6.0 등) | 순서 무관. 논의 문서 |
