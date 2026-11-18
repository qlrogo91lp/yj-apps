# yj-apps

[![CI](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml/badge.svg)](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml)

iOS + watchOS 앱 모노레포. 공용 인프라는 `Packages/YJKit`으로 두고 앱이 이를 로컬 SPM 패키지로 참조한다.

```
yj-apps/
├─ Packages/YJKit/          공용 라이브러리 (WorkoutCore / WorkoutUI / WorkoutShareUI / ConnectivityCore / PersistenceCore / MonitoringCore)
├─ Apps/GolfCounter/        GolfCounter — iOS + Watch + Complication
├─ Apps/TennisCounter/      Ralli(TennisCounter) — iOS + Watch + Complication + LiveActivity
├─ Apps/HaruchiFit/         하루치 핏(HaruchiFit) — iOS + Watch + Complication
├─ .github/workflows/       CI — 변경된 앱만 빌드·테스트
└─ docs/                   모노레포 공통 문서 (specs/ideas/plans/logs)
```

---

## 앱별 안내

각 앱의 README는 기능, 데이터 흐름, 권한, 패키지와 Xcode 설정을 다시 찾아보기 위한 안내다.

| 앱 | 안내 |
|---|---|
| GolfCounter | [골프 라운드 기록과 설정](Apps/GolfCounter/README.md) |
| Ralli | [테니스 점수·운동 기록과 설정](Apps/TennisCounter/ReadMe.md) |
| 하루치 핏 | [운동 구간·활동 격자와 설정](Apps/HaruchiFit/README.md) |

## 설정을 다시 찾을 때

Swift 코드만으로 앱의 모든 기능이 켜지는 것은 아니다. 프로젝트 설정, 사용자 동의, 패키지 연결을 함께 확인한다.

| 무엇을 설정하는가 | 어디서 확인하는가 | 역할 |
|---|---|---|
| 앱 식별자·최소 OS·버전 | 타깃 General / Build Settings | Bundle Identifier, Deployment Target, Version·Build |
| 언어·동시성 설정 | 타깃 Build Settings | Swift Language Version, Default Actor Isolation 등 |
| HealthKit·iCloud·App Groups 사용 자격 | 타깃 Signing & Capabilities, `*.entitlements` | 서명된 앱이 사용할 시스템 기능과 컨테이너 선언 |
| 권한 요청에 표시할 설명 | 타깃 Info / `INFOPLIST_KEY_*`, `InfoPlist.xcstrings` | `NSHealthShareUsageDescription` 같은 사용자 안내 문구 |
| 실제 권한 요청 | 앱·YJKit의 서비스 코드 | `requestAuthorization`으로 필요한 데이터 종류에 대한 동의 요청 |
| 패키지 의존성 | 프로젝트 Package Dependencies, `Packages/YJKit/Package.swift` | 패키지 위치와 버전 조건 |
| 타깃에서 쓸 패키지 프로덕트 | 타깃 General의 Frameworks, Libraries, and Embedded Content / Build Phases | `WorkoutCore` 등 실제로 연결할 라이브러리 선택 |
| 개인정보·API 사용 선언 | 각 타깃의 `PrivacyInfo.xcprivacy` | 데이터 수집·추적 및 신고 대상 API의 사용 사유 |

권한 설명 문구, capability, 실제 요청 코드는 서로 다른 역할이다. 하나만 추가했다고 나머지가 자동으로 채워지지 않는다.
`Info.plist` 원본이 비어 있어도 Build Settings의 `INFOPLIST_KEY_*` 값으로 최종 앱의 Info.plist가 생성될 수 있다.
번역한 문구는 앱의 `InfoPlist.xcstrings`도 함께 확인한다. Developer Portal·App Store Connect의 상태는 별도 확인 대상이다.

### UserDefaults와 프라이버시 매니페스트

`UserDefaults`는 Foundation의 작은 설정·상태 저장소다. 이름(key)과 값(value)을 기기에 저장해 앱을 다시 열어도 기억한다.
SwiftUI의 `@AppStorage`도 이를 사용한다. 웹의 `localStorage`와 비슷하며 저장 자체가 서버 전송을 뜻하지 않는다.
운동 기록 전체를 관리하는 SwiftData, 건강 기록을 관리하는 HealthKit과 용도가 다르다.

`UserDefaults.standard`는 앱 전용 저장소다. iPhone 앱과 Watch 앱은 각각 독립된 저장소를 갖고,
Watch 앱과 같은 기기의 컴플리케이션은 App Group 저장소를 통해 데이터를 공유할 수 있다.
App Group은 iPhone↔Watch 전송 수단이 아니며, 그 통신에는 WatchConnectivity를 쓴다.

`PrivacyInfo.xcprivacy`는 실제 데이터 수집·추적·API 사용 목적을 선언하는 파일이다.
UserDefaults 자체 저장은 `CA92.1`, 같은 App Group 안의 공유는 `1C8F.1`을 해당 사용처에 선언한다.
파일은 해당 실행 파일의 번들에 포함되어야 하며, 별도 권한 팝업을 만드는 기능은 아니다.
Ralli·HaruchiFit에는 iOS·Watch·컴플리케이션별 파일이 있다. GolfCounter는 아직 추가되지 않았다.

Xcode에서 파일을 선택하면 Property List 표 편집기로 볼 수 있다. 생성 템플릿은 Resource의 App Privacy다.
매니페스트 내용은 타깃 Build Settings의 설정 항목으로 나타나지 않는다.
Organizer의 Generate Privacy Report는 수집 데이터 요약용이며 API 사용 사유 코드를 확인하는 화면은 아니다.

- [Apple: UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
- [Apple: 프라이버시 매니페스트](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: API 사용 사유](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Apple: Xcode 표 편집기](https://developer.apple.com/documentation/xcode/editing-property-list-files)

### 패키지를 추가하거나 연결할 때

공용 인프라는 로컬 SPM 패키지 [YJKit](Packages/YJKit/README.md)에 둔다. 각 앱은 `../../Packages/YJKit`을 참조한다.
공용 외부 라이브러리를 추가한다면 `Package.swift`의 `dependencies`와 이를 소비할 타깃의 `dependencies`를 함께 확인한다.
새 프로덕트를 앱에서 쓰려면 앱 타깃에도 연결해야 한다. 코드에서는 패키지 이름 `YJKit` 대신 `WorkoutCore` 같은 모듈을 import한다.
앱 전용 외부 패키지는 프로젝트 Package Dependencies와 소비할 앱 타깃의 연결을 함께 관리한다.
시스템 프레임워크(HealthKit·SwiftData·WatchConnectivity)는 외부 SPM 패키지와 구분한다.
현재 외부 의존성 Firebase는 YJKit의 `MonitoringCore`를 통해 Ralli에 연결된다. 패키지 버전 조건의 원본은
[Package.swift](Packages/YJKit/Package.swift)이며, 앱별 실제 링크 목록은 각 README를 본다.

## 모노레포 전환

세 개의 개별 레포(`golf_counter`, `tennis_counter`, `ralli-kit`)를 이 레포로 통합했다. 히스토리는 경로를
다시 써서 가져왔으므로 `git log Apps/GolfCounter/` 처럼 앱별 이력을 그대로 볼 수 있다.
단계별 기록은 [모노레포 전환 설계](docs/specs/2026/2026-08-27-monorepo-migration-design.md)에 있다.

---

## 명령

```bash
make lint            # 앱별 swiftlint (검사만)
make format          # 앱별 swiftformat --lint (검사만)
make fix             # 앱별 swiftformat + swiftlint --fix (실제로 고침)
make kit-test        # Packages/YJKit 단독 테스트 (iOS 시뮬레이터)
make dd-prune        # 고아 DerivedData 목록 (검사만)
make dd-prune-apply  # 고아 DerivedData 삭제 (실제로 지움)
```

> `make dd-prune` 은 **가리키던 워크트리가 사라진 DerivedData** 를 찾는다. DerivedData 폴더 이름은
> 워크스페이스 **경로 해시**라 워크트리를 지워도 산출물은 남아 수백 MB 를 차지한다. 워크트리를
> 제거할 때 같이 돌린다. 실제 삭제는 `dd-prune-apply` 에서만 일어난다.

## 빌드

**최상위 `YJApps.xcworkspace` 하나만 연다.** 앱별 `.xcodeproj`를 따로 열 필요가 없다.

공유 스킴 11개:

| 앱 | 스킴 |
|---|---|
| GolfCounter | `GolfCounter` / `GolfCounter Watch App` / `GolfComplicationExtension` |
| Ralli | `TennisCounter` / `TennisCounter Watch App` / `RalliComplicationExtension` / `TennisLiveActivityExtension` |
| 하루치 핏 | `HaruchiFit` / `HaruchiFit Watch App` / `HaruchiComplicationExtension` / `HaruchiFitWatchTests` |

```bash
# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination "id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')" test

# watchOS — 이름 대신 UDID로 지정할 것 (아래 참고)
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')" \
  -only-testing:GolfCounterWatchTests test

# 하루치 핏 워치만 워치 테스트 전용 스킴을 갖는다 (-only-testing 불필요)
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" \
  -destination "id=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')" test

# 패키지 단독 (swift build 는 동작하지 않는다 — 아래 참고)
make kit-test KIT_DESTINATION="id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')"
```

> **워치 테스트는 앱마다 거는 방식이 다르다.** GolfCounter·Ralli 의 워치 스킴에는 iOS 테스트 타깃까지
> 들어 있어 `-only-testing` 으로 워치 테스트만 골라야 한다. 하루치 핏만 워치 전용 스킴
> (`HaruchiFitWatchTests`)이 따로 있다.

> **워치 시뮬레이터를 이름으로 지정하면 실패한다.** `Apple Watch Series 11 (46mm)` 같은 이름이
> OS 26.4·26.5 두 기기와 겹쳐 매칭되지 않는다. `-destination "id=<UDID>"`를 쓴다.
> `.github/scripts/pick-simulator.sh <iOS|watchOS> <이름 정규식>`이 최신 런타임에서 기기를
> 하나 골라 UDID를 출력한다. CI와 로컬이 같은 스크립트를 쓴다.

> `swift build` / `swift test`는 이 패키지에서 실패한다. `Package.swift`가 macOS 플랫폼을
> 선언하지 않아 호스트 빌드 시 SwiftData API가 macOS 14 미만으로 판정되기 때문이다.
> 검증에는 반드시 iOS 시뮬레이터 destination을 쓴다.

## CI

PR을 열면 **변경된 앱만** 빌드·테스트한다. `Packages/YJKit`이 바뀌면 코어 변경의 파급을 잡기 위해
전 앱을 돌린다. `docs/`나 `README.md`만 바뀌면 아무 job도 돌지 않는다.

러너는 `macos-26`(Xcode 26.6 — 로컬과 동일)이고, 린트 도구는 로컬과 같은 버전으로 고정한다.
서명은 하지 않는다(`CODE_SIGNING_ALLOWED=NO`).

## 문서

- [모노레포 전환 설계](docs/specs/2026/2026-08-27-monorepo-migration-design.md) — 실행 스펙, 단계별 완료 조건
- [CI 파이프라인 설계](docs/specs/2026/2026-08-27-ci-pipeline-design.md) — 워크플로 구성, 러너·도구 버전 고정 근거
- [코드 스타일 툴링](docs/specs/2026/2026-08-27-code-style-tooling-design.md) — 개념 정리 + 미결 논의
