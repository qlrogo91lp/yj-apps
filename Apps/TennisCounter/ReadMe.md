# Ralli

Apple Watch와 iPhone에서 테니스 점수를 기록하고, 경기 결과와 운동 지표를 함께 남기는 앱이다.
저장소·프로젝트 이름은 `TennisCounter`, 사용자에게 보이는 이름은 Ralli다.
화면은 SwiftUI, 구성은 Feature 단위 MVVM이며 SwiftLint·SwiftFormat으로 스타일을 검사한다.

## 주요 기능과 구성

- 경기 포맷·룰 선택, 득점·undo, 동점 종료, 3세트 경기의 마지막 세트를 10점 매치 타이브레이크로 대체
- iPhone의 경기 요약·캘린더·기록 상세·공유 카드
- Watch의 운동 시간·심박수·칼로리와 문자판 컴플리케이션
- iPhone 잠금화면·Dynamic Island의 Live Activity

점수 입력을 담당하는 기기와 상대 기기의 표시가 WatchConnectivity로 동기화된다.
HealthKit 운동 세션과 운동시간의 기준은 Watch가 소유한다.

| 폴더 | 역할 |
|---|---|
| `iOSApp/` | 요약·기록·온보딩·경기 화면, 기록 저장·Live Activity 서비스 |
| `WatchApp/` | 운동 세션과 경기 입력, 경기 저장 보관함 |
| `Shared/` | 점수·경기 모델, SwiftData 모델, 통신 메시지 |
| `ComplicationApp/` | Watch 문자판 위젯 |
| `TennisLiveActivity/` | iOS Live Activity 확장 |
| `iosTests/`, `watchosTests/` | 플랫폼별 테스트 |

## 데이터는 어디에 저장되는가

| 저장소 | 실제 용도·코드 |
|---|---|
| SwiftData | 경기·세트·운동 세션 기록. [iOS 진입점](iOSApp/iOSApp.swift)과 [저장 서비스](iOSApp/Services/MatchPersistenceService.swift) |
| CloudKit | iOS의 `iCloud.com.yj.TennisCounter`. 컨테이너 생성 실패 시 로컬 저장으로 폴백 |
| HealthKit | Watch가 저장한 테니스 운동과 심박·에너지 지표 |
| UserDefaults | 폰·워치 각각의 마지막 경기 옵션, iOS 온보딩 확인 여부 |
| Watch의 UserDefaults 보관함 | 폰의 경기별 저장 ACK를 받을 때까지 [MatchSaveOutbox](WatchApp/Services/MatchSaveOutbox.swift)에 보관하고 재전송 |
| App Group UserDefaults | Watch 앱→컴플리케이션의 운동 활성 상태. `group.com.yj.TennisCounter` |

`UserDefaults`·SwiftData·HealthKit의 차이는 [루트 설정 안내](../../README.md#userdefaults와-프라이버시-매니페스트)를 본다.
폰↔워치 설정 동기화는 메시지로 처리하며, App Group이 두 기기의 저장소를 공유하는 것은 아니다.

## 권한과 Xcode 설정

아래는 저장소의 설정 파일 기준이다. 실제 서명·Developer Portal 설정은 사용하는 개발자 계정에서 확인한다.

| 설정 | 대상·목적 | 확인할 곳 |
|---|---|---|
| HealthKit | iOS·Watch. Watch의 운동·심박·에너지 측정과 저장, iOS의 건강 운동 삭제 연동 | [iOS entitlements](TennisCounter.entitlements), [Watch entitlements](TennisCounter%20Watch%20App.entitlements), Signing & Capabilities |
| 건강 읽기·쓰기 설명 | 사용자 동의 화면의 문구 | 타깃 Info / Build Settings의 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`; [iOS 번역](iOSApp/InfoPlist.xcstrings)·[Watch 번역](WatchApp/InfoPlist.xcstrings) |
| 실제 건강 권한 요청 | Watch는 운동 쓰기와 활동·기초 에너지·심박 읽기를 요청. iOS 삭제 서비스는 운동 쓰기 권한을 요청 | [WorkoutSessionService](../../Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift), [WorkoutDeletionService](../../Packages/YJKit/Sources/WorkoutCore/WorkoutDeletionService.swift) |
| App Groups | Watch 앱·컴플리케이션의 `group.com.yj.TennisCounter` | Watch entitlements와 [컴플리케이션 entitlements](ComplicationAppExtension.entitlements) |
| iCloud / CloudKit | iOS 기록 동기화 | iOS entitlements의 컨테이너·서비스 |
| Live Activities | 진행 중 경기 표시. 지원·빈번한 갱신 키가 iOS에 설정됨 | iOS Info의 `NSSupportsLiveActivities`, `NSSupportsLiveActivitiesFrequentUpdates`, [서비스](iOSApp/Services/LiveActivityService.swift) |
| 기존 entitlement | iOS에 HealthKit background-delivery, iOS·Watch·컴플리케이션에 `aps-environment`가 선언됨 | 각 entitlements. 선언만으로 원격 중계나 새 푸시 기능이 구현된 것은 아님 |
| 수출 규정 | iOS·Watch `ITSAppUsesNonExemptEncryption = NO` | 각 타깃 Build Settings |

권한 요청 시점은 [Watch 운동 ViewModel](WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift)과 실제 호출 서비스에서 확인한다.
capability·권한 문구·실제 동의 요청의 역할은 [루트 설정 표](../../README.md#설정을-다시-찾을-때)를 본다.

### 타깃 식별자와 언어 설정

| 스킴 | Bundle ID | 최소 OS |
|---|---|---|
| `TennisCounter` | `com.yj.TennisCounter` | iOS 17 |
| `TennisCounter Watch App` | `com.yj.TennisCounter.watchkitapp` | watchOS 10 |
| `RalliComplicationExtension` | `com.yj.TennisCounter.watchkitapp.widget` | watchOS 10 |
| `TennisLiveActivityExtension` | `com.yj.TennisCounter.TennisLiveActivity` | iOS 17 |

컴플리케이션의 실제 타깃명은 `ComplicationAppExtension`이다.
앱·확장 타깃의 Swift Language Version은 현재 `5.0`이다. 설치된 Swift 컴파일러 버전이나 포매터 설정과 구분한다.
식별자·최소 OS·버전·빌드 번호는 General / Build Settings, 파일 원본은
[TennisCounter.xcodeproj/project.pbxproj](TennisCounter.xcodeproj/project.pbxproj)에 있다.
iOS 화면 방향은 세로, 스타일은 Dark로 설정돼 있다.

## 패키지와 Firebase 초기 설정

[로컬 YJKit](../../Packages/YJKit/README.md)을 사용한다. 실제 연결은 다음과 같다.

| 타깃 | 연결한 프로덕트 |
|---|---|
| iOS | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, WorkoutShareUI, MonitoringCore |
| Watch | ConnectivityCore, WorkoutCore, WorkoutUI, MonitoringCore |
| 컴플리케이션·Live Activity | YJKit 프로덕트 연결 없음 |

Firebase SDK는 [YJKit Package.swift](../../Packages/YJKit/Package.swift)의 `12.0.0` 이상 조건으로 선언돼 있다.
`MonitoringCore`가 `FirebaseCrashlytics`를 사용하며, 앱 진입점은 [AppCrashReporter](Shared/Services/AppCrashReporter.swift)를 초기화한다.

새 체크아웃에서 실제 Crashlytics를 쓰려면 Firebase의 Ralli 프로젝트에서 타깃별 설정을 받아
`iOSApp/GoogleService-Info.plist`, `WatchApp/GoogleService-Info.plist`에 각각 둔다. 이 파일들은 Git에서 제외돼 있다.
설정이 없으면 Debug에서 Noop 리포터로 빌드·테스트할 수 있지만, Release는 dSYM 업로드 스크립트가 누락을 오류로 처리한다.
스크립트는 두 앱 타깃의 Build Phases에 있고 Release에서만 실행된다.
iOS 크래시 수집과 Watch non-fatal·브레드크럼의 확인 범위는 [Crashlytics 연동 기록](docs/plans/shared/2026/2026-09-07-crashlytics-integration.md)을 본다.

## 프라이버시 매니페스트

| 파일 | UserDefaults 사용 사유 |
|---|---|
| [iOS](iOSApp/PrivacyInfo.xcprivacy) | 자체 저장 `CA92.1` |
| [Watch](WatchApp/PrivacyInfo.xcprivacy) | 자체 저장 `CA92.1`, App Group 공유 `1C8F.1` |
| [컴플리케이션](ComplicationApp/PrivacyInfo.xcprivacy) | App Group 공유 `1C8F.1` |

앱 자체 매니페스트에는 추적 없음·별도 수집 항목 없음으로 선언했다. Firebase SDK의 매니페스트는 별도로 포함된다.
App Store Connect의 앱 개인정보 답변에는 SDK까지 포함한 실제 수집 동작을 반영해야 한다.
Live Activity에는 현재 직접 사용하는 UserDefaults가 없어 해당 선언 파일을 추가하지 않았다.
설정을 바꿀 때는 [공통 개념·Xcode 확인 방법](../../README.md#userdefaults와-프라이버시-매니페스트)을 함께 본다.

## 빌드와 테스트

저장소 루트의 `YJApps.xcworkspace`를 연다. 아래 명령도 루트에서 실행한다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme TennisCounter -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme 'TennisCounter Watch App' -destination "id=$WATCH" -only-testing:RalliWatchTests test
xcodebuild -workspace YJApps.xcworkspace -scheme RalliComplicationExtension -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme TennisLiveActivityExtension -destination "id=$IOS" build
```

## 더 읽을 문서

공통 스타일 검사는 루트에서 `make lint`, `make format`으로 실행한다. `make fix`는 실제 파일을 수정한다.

- [공통 개발·CI 안내](../../README.md), [YJKit 사용법](../../Packages/YJKit/README.md)
- [iOS 운동 세션 구조](iOSApp/Features/WorkoutSession/README.md), [Watch 운동 세션 구조](WatchApp/Features/WorkoutSession/README.md)
- [App Store 문구 원본](APPSTORE.md)
- [작업 규약](CLAUDE.md): 에이전트·기여자에게 적용하는 수정·검증 규칙

설정 변경 시 이 문서의 목적·값·원본 링크를 함께 갱신한다. 과거 설계·작업 기록은 당시 상태일 수 있으므로 현재 코드를 확인한다.
