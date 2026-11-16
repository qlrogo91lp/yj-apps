# 하루치 핏 (HaruchiFit)

Apple Watch에서 근력·유산소 구간을 기록하고 iPhone에서 운동한 날의 격자, 기록, 통계를 보는 앱이다.
폰을 열지 않고도 Watch에서 시작·종료·저장을 완료하는 흐름을 중심으로 한다.

## 주요 기능과 구성

- Watch에서 운동 시작·일시정지·재개·종료, 근력↔유산소 구간 전환과 요약
- iPhone의 홈 활동 격자, 달력·목록, 연간 통계
- 기록의 부위 태그·메모, 수동 기록 추가, 건강 앱 운동 가져오기, 기록 카드 공유
- Watch 문자판의 컴플리케이션

| 폴더 | 역할 |
|---|---|
| `WatchApp/` | 운동 세션·구간 추적·요약·폰 전송 |
| `iOSApp/` | 홈·기록·통계·온보딩, HealthKit 가져오기와 저장 서비스 |
| `Shared/` | 운동 모델·SwiftData 모델·통신 메시지·집계 규칙 |
| `Common/` | iOS·Watch·컴플리케이션 모두에 포함되는 외부 패키지 의존 없는 모델·스냅샷 |
| `ComplicationApp/` | Watch 문자판 위젯 |
| `watchosTests/` | Watch ViewModel과 공용 계산 규칙 테스트 |

## 데이터는 어디에 저장되는가

| 저장소 | 실제 용도 |
|---|---|
| HealthKit | 운동 시각·시간·에너지·심박의 원본. Watch는 운동을 쓰고 iOS는 가져옴 |
| SwiftData | 구간·부위 태그·메모·수동 기록, 건강 운동의 앱 표시용 캐시 |
| UserDefaults | iOS 온보딩 확인 여부, Watch의 마지막 시작 유형 `startSegmentKind`, 건강 가져오기 쿼리 앵커 |
| App Group UserDefaults | Watch→컴플리케이션의 운동 스냅샷. `group.com.yj.HaruchiFit` |

[Watch ViewModel](WatchApp/Features/Workout/WorkoutViewModel.swift)은 구간 시간을 관리하고,
[iOS 진입점](iOSApp/iOSApp.swift)은 화면과 무관하게 워치 기록을 받아 저장한다.
운동 타입은 HealthKit에서 근력으로 유지하며 근력·유산소의 구간 구분은 앱이 직접 보관한다.

현재 **CloudKit capability는 없으며 SwiftData는 로컬 폴백으로 동작한다.**
[공용 컨테이너 팩토리](../../Packages/YJKit/Sources/PersistenceCore/PersistenceContainerFactory.swift)가 CloudKit을 시도한 뒤 로컬로 전환한다.
향후 CloudKit 추가 시에는 패키지 import만으로 켜지지 않으며 entitlement·컨테이너·스키마 배포를 별도로 다뤄야 한다.
앱 재설치 후 HealthKit 운동을 다시 가져와도 앱에만 있던 구간·태그·메모·수동 기록까지 복원되는 것은 아니다.

App Group은 같은 기기의 앱·확장 사이 공유다. iPhone↔Watch에는 WatchConnectivity를 쓴다.
저장소 개념은 [공통 설정 안내](../../README.md#userdefaults와-프라이버시-매니페스트)를 본다.

## 권한과 Xcode 설정

| 설정 | 대상·목적 | 확인할 곳 |
|---|---|---|
| HealthKit | iOS·Watch. iOS는 기존 운동을 읽고 Watch는 새 운동을 측정·저장 | [iOS entitlements](HaruchiFit.entitlements), [Watch entitlements](HaruchiFit%20Watch%20App.entitlements), Signing & Capabilities |
| 건강 권한 설명 | 사용자에게 건강 데이터를 왜 쓰는지 설명 | 타깃 Info / Build Settings의 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`; [iOS 번역](iOSApp/InfoPlist.xcstrings)·[Watch 번역](WatchApp/InfoPlist.xcstrings) |
| iOS 실제 동의 요청 | 운동·활동/기초 에너지·심박 읽기. `toShare`는 비어 있음 | [HealthKitWorkoutImporter](iOSApp/Services/HealthKitWorkoutImporter.swift), [WorkoutSyncCoordinator](iOSApp/Services/WorkoutSyncCoordinator.swift) |
| Watch 실제 동의 요청 | 운동 쓰기와 활동/기초 에너지·심박 읽기 | [WorkoutSessionService](../../Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift), [Watch ViewModel](WatchApp/Features/Workout/WorkoutViewModel.swift) |
| App Groups | Watch 앱·컴플리케이션의 `group.com.yj.HaruchiFit` | Watch entitlements와 [컴플리케이션 entitlements](HaruchiComplicationExtension.entitlements) |
| iCloud / CloudKit | 현재 미설정 | iOS entitlements에는 HealthKit만 있음 |
| 수출 규정 | iOS·Watch `ITSAppUsesNonExemptEncryption = NO` | 타깃 Build Settings |

건강 권한 요청 성공이 읽기 허용을 보장하는 것은 아니다. 가져오기 서비스는 읽기 거부 여부를 직접 알 수 없으며 결과가 비어 있을 수 있다.
iOS 건강 가져오기는 앱 활성화 때 실행하고 HealthKit background delivery는 사용하지 않는다.
문구·capability·실제 권한 요청은 [서로 다른 설정](../../README.md#설정을-다시-찾을-때)이다.
개발자 계정의 App ID·프로비저닝 상태는 별도로 확인한다.

### 타깃 식별자와 언어 설정

| 스킴 | Bundle ID | 최소 OS |
|---|---|---|
| `HaruchiFit` | `com.yj.HaruchiFit` | iOS 17 |
| `HaruchiFit Watch App` | `com.yj.HaruchiFit.watchkitapp` | watchOS 10 |
| `HaruchiComplicationExtension` | `com.yj.HaruchiFit.watchkitapp.ComplicationApp` | watchOS 10 |

컴플리케이션의 실제 타깃명은 `ComplicationAppExtension`이다.
앱·확장의 Swift Language Version은 현재 `5.0`, iOS·Watch 앱의 Default Actor Isolation은 `MainActor`다.
Approachable Concurrency도 앱·확장에 설정돼 있다. 이를 변경하면 서비스·콜백의 격리 경계를 함께 확인한다.
원본은 [HaruchiFit.xcodeproj/project.pbxproj](HaruchiFit.xcodeproj/project.pbxproj), GUI는 General / Build Settings다.
표시 문자열은 한국어·영어 String Catalog를 사용한다. 일반 문자열과 건강 권한 문구의 카탈로그는 별개다.

## 패키지 의존성

[로컬 YJKit](../../Packages/YJKit/README.md)의 다음 프로덕트가 연결돼 있다.

| 타깃 | 연결한 프로덕트 |
|---|---|
| iOS | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, WorkoutShareUI |
| Watch | ConnectivityCore, WorkoutCore, WorkoutUI |
| 컴플리케이션 | 없음. `Common/`의 스냅샷만 읽음 |

Firebase/MonitoringCore는 앱 타깃에 연결돼 있지 않다. YJKit이 외부 Firebase 의존성을 선언한다는 사실과
이 앱이 Crashlytics를 연결·초기화한다는 것은 구분한다.
공용 라이브러리 추가 위치와 앱 타깃 연결 방법은 [루트 패키지 안내](../../README.md#패키지를-추가하거나-연결할-때)를 본다.

## 프라이버시 매니페스트

| 파일 | UserDefaults 사용 사유 |
|---|---|
| [iOS](iOSApp/PrivacyInfo.xcprivacy) | 앱 자체 저장 `CA92.1` |
| [Watch](WatchApp/PrivacyInfo.xcprivacy) | 자체 저장 `CA92.1`, App Group 공유 `1C8F.1` |
| [컴플리케이션](ComplicationApp/PrivacyInfo.xcprivacy) | App Group 공유 `1C8F.1` |

앱 자체 매니페스트는 추적 없음·별도 수집 항목 없음으로 선언돼 있다.
건강 데이터를 기기에 저장·표시하는 동작과 개발자에게 데이터를 수집·전송하는 동작은 구분한다.
API나 수집 동작을 추가하면 선언과 App Store Connect의 앱 개인정보 답변도 함께 검토한다.
[공통 개념·Xcode 확인 방법](../../README.md#userdefaults와-프라이버시-매니페스트)을 참고한다.

## 빌드와 테스트

저장소 루트에서 `YJApps.xcworkspace`를 연다. 아래 명령도 루트에서 실행한다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiComplicationExtension -destination "id=$WATCH" build
```

현재 iOS 테스트 타깃은 없고 Watch 전용 테스트 스킴을 사용한다. Watch 테스트가 공용 모델·집계 규칙도 검증한다.

## 더 읽을 문서

- [제품 설계](docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md)
- [아키텍처·데이터 소유권](docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md), [로드맵](docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)
- [건강 운동 가져오기](docs/specs/shared/2026/2026-09-21-healthkit-workout-import.md)
- [App Store 문구](APPSTORE.md), [공통 개발·CI 안내](../../README.md), [작업 규약](CLAUDE.md)

과거 출시 체크리스트는 당시 기록이다. 현재 매니페스트·빌드 설정은 이 문서에서 링크한 소스 파일을 기준으로 확인한다.
