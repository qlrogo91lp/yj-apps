# GolfCounter

Apple Watch로 골프 타수를 입력하고 iPhone에서 라운드 기록과 통계를 확인하는 앱이다.
Watch가 라운드 진행·운동 측정을 담당하고, iPhone은 받은 라운드를 저장한다.

## 주요 기능과 구성

- Watch에서 홀별 타수 기록과 라운드 진행
- HealthKit 운동 시간·에너지·심박, 추가 거리·걸음 수 읽기
- Watch 문자판에 라운드 스냅샷 표시
- iPhone의 라운드 기록·통계와 온보딩

| 폴더 | 역할 |
|---|---|
| `WatchApp/` | 라운드 화면·운동 세션·폰 전송 |
| `iOSApp/` | 라운드 기록·통계, 수신·저장 서비스 |
| `Shared/` | 골프 모델·SwiftData 모델·메시지·App Group 스냅샷 |
| `ComplicationApp/` | Watch 문자판 위젯 |
| `iosTests/`, `watchosTests/` | 플랫폼별 테스트 |

## 데이터는 어디에 저장되는가

| 저장소 | 실제 용도 |
|---|---|
| iOS SwiftData | `GolfRound` 라운드 기록. [iOS 진입점](iOSApp/iOSApp.swift), [수신 서비스](iOSApp/Services/RoundReceiveService.swift) |
| CloudKit | iOS의 `iCloud.com.yj.GolfCounter`. 컨테이너 생성 실패 시 로컬 저장으로 폴백 |
| HealthKit | Watch에서 기록하는 골프 운동 |
| UserDefaults | iOS 온보딩 확인 여부 |
| App Group UserDefaults | Watch→컴플리케이션의 [라운드 스냅샷](Shared/Services/RoundSnapshotStore.swift). `group.com.yj.GolfCounter` |

Watch→iPhone 라운드 전송은 [RoundTransmitter](WatchApp/Services/RoundTransmitter.swift)와 WatchConnectivity가 담당한다.
App Group은 같은 기기의 Watch 앱·컴플리케이션 사이 공유이며, iPhone과 Watch의 저장소를 연결하지 않는다.
저장소별 차이는 [루트 설명](../../README.md#userdefaults와-프라이버시-매니페스트)을 본다.

## 권한과 Xcode 설정

| 설정 | 대상·목적 | 확인할 곳 |
|---|---|---|
| HealthKit | Watch의 골프 운동 측정·저장 | [Watch entitlements](GolfCounter%20Watch%20App.entitlements), Signing & Capabilities |
| 건강 권한 문구 | Watch 사용자에게 측정·저장 이유 설명 | Watch Info / Build Settings의 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` |
| 실제 권한 요청 | 운동 쓰기, 활동·기초 에너지·심박 및 거리·걸음 수 읽기 | [WorkoutConfiguration+Golf](WatchApp/Services/WorkoutConfiguration+Golf.swift), [WorkoutSessionService](../../Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift) |
| App Groups | Watch 앱·컴플리케이션의 `group.com.yj.GolfCounter` | Watch entitlements, [컴플리케이션 entitlements](ComplicationAppExtension.entitlements) |
| iCloud / CloudKit | iOS 라운드 기록 동기화 | [iOS entitlements](GolfCounter.entitlements) |
| 수출 규정 | iOS·Watch `ITSAppUsesNonExemptEncryption = NO` | 타깃 Build Settings |

현재 iOS entitlement는 CloudKit이며 HealthKit capability는 없다. 운동 세션과 건강 권한은 Watch에서 다룬다.
골프 운동 설정은 GPS를 사용하지 않는 `.indoor`이며 추가 읽기 항목은 `.distanceWalkingRunning`, `.stepCount`다.
거리·걸음 수를 읽는 설정을 GPS 위치 권한과 혼동하지 않는다.
실제 요청 진입점은 [RoundSessionView](WatchApp/Features/Round/RoundSessionView.swift)다.
문구·capability·런타임 동의의 차이는 [루트 설정 안내](../../README.md#설정을-다시-찾을-때)를 본다.
개발자 계정의 컨테이너·서명 상태는 저장소 파일만으로 확인되지 않는다.

### 타깃 식별자와 언어 설정

| 스킴 | Bundle ID | 최소 OS |
|---|---|---|
| `GolfCounter` | `com.yj.GolfCounter` | iOS 17 |
| `GolfCounter Watch App` | `com.yj.GolfCounter.watchkitapp` | watchOS 10 |
| `GolfComplicationExtension` | `com.yj.GolfCounter.watchkitapp.ComplicationApp` | watchOS 10 |

컴플리케이션의 실제 타깃명은 `ComplicationAppExtension`이다.
앱·확장의 Swift Language Version은 현재 `5.0`이다. Swift 컴파일러 버전이나 테스트 타깃 최소 OS와 구분한다.
General / Build Settings의 원본은 [GolfCounter.xcodeproj/project.pbxproj](GolfCounter.xcodeproj/project.pbxproj)다.

## 패키지 의존성

[로컬 YJKit](../../Packages/YJKit/README.md)을 사용한다.

| 타깃 | 연결한 프로덕트 |
|---|---|
| iOS | ConnectivityCore, PersistenceCore |
| Watch | ConnectivityCore, WorkoutCore, WorkoutUI |
| 컴플리케이션 | 없음 |

Firebase/MonitoringCore는 앱 타깃에 연결돼 있지 않다. HealthKit·SwiftData·WatchConnectivity는 시스템 프레임워크다.
패키지를 추가할 때는 [공용 Package.swift와 앱 타깃 연결](../../README.md#패키지를-추가하거나-연결할-때)을 함께 확인한다.

## 프라이버시 매니페스트 현재 상태

**현재 GolfCounter에는 `PrivacyInfo.xcprivacy`가 없다.** Ralli·HaruchiFit에 추가한 선언이 GolfCounter까지 적용되지는 않는다.
이 앱도 UserDefaults와 App Group을 사용하므로 [YJ-2](https://linear.app/yj-workpace/issue/YJ-2)의 후속 작업이 남아 있다.
추가할 때는 실제 타깃별 사용처에 맞춰 자체 저장 `CA92.1`과 App Group 공유 `1C8F.1`을 선언하고,
각 번들에 파일이 포함되는지 확인한다. [공통 매니페스트 안내](../../README.md#userdefaults와-프라이버시-매니페스트)를 참고한다.

## 빌드와 테스트

저장소 루트의 `YJApps.xcworkspace`를 연다. 아래 명령도 루트에서 실행한다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme GolfCounter -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme 'GolfCounter Watch App' -destination "id=$WATCH" -only-testing:GolfCounterWatchTests test
xcodebuild -workspace YJApps.xcworkspace -scheme GolfComplicationExtension -destination "id=$WATCH" build
```

## 더 읽을 문서

- [리빌드 설계](docs/specs/shared/2026/2026-07-31-golfcounter-rebuild-design.md)
- [온보딩 설계](docs/specs/ios/2026/2026-10-26-onboarding-design.md)
- [App Store 문구](APPSTORE.md), [공통 개발·CI 안내](../../README.md), [작업 규약](CLAUDE.md)

설정 변경 시 값·목적·소스 링크를 함께 갱신한다. 이전 설계의 진행 상태보다 현재 소스와 Xcode 설정을 우선해 확인한다.
