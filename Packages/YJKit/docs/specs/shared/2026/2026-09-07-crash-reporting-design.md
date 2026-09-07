# 크래시 리포팅 (MonitoringCore) — 설계

작성일: 2026-09-07

## 목표

출시된 앱이 사용자 기기에서 죽었을 때 **개발자가 알 수 있게** 한다. 지금은 Xcode Organizer 뿐인데, 그건 "앱 개발자와 분석 공유" 를 켠 기기의 표본만 보여주고 켠 비율은 알 수 없다. SDK 를 앱에 넣어 **내 앱 사용자 전원**을 표본으로 만든다.

크래시 외에 **죽진 않았지만 사용자 손실이 생기는 일**(경기 저장 실패)도 같은 채널로 보낸다.

## 결정 사항

| 논점 | 결정 | 이유 |
|---|---|---|
| 도구 | **Firebase Crashlytics** | 무료 구간 사실상 표준. Ralli 로드맵 Phase 2 에 Firebase 가 이미 잡혀 있어 SDK 를 하나로 통일. 대안 Sentry 는 Google 의존을 피하고 싶을 때 — 셋업 구조가 같아 갈아타기 비용은 작다 |
| 위치 | **YJKit `MonitoringCore` 프로덕트** | 3앱이 전부 필요로 하게 되고, 이 저장소 관례가 "시스템/외부 SDK 래퍼는 코어" (`ConnectivityCore`=WCSession, `WorkoutCore`=HealthKit). 앱에만 두면 그게 예외가 된다 |
| 범위 | **iOS 앱 + 워치 앱**. 익스텐션(컴플리케이션·LiveActivity) 제외 | Firebase 가 익스텐션에서 `configure()` 를 권장하지 않고, 익스텐션은 렌더링 코드만이라 크래시 표면이 작다 |
| Firebase 프로덕트 | **`FirebaseCrashlytics` 만** | Analytics·Performance·Remote Config 는 Phase 2. watchOS 는 Crashlytics 만 지원한다 |
| non-fatal 초기 범위 | **경기 저장 실패만** | 사용자 기록이 날아가는 유일한 경로. 연결 실패·권한 거부는 노이즈 가능성이 커 실제 크래시 데이터를 본 뒤 결정 |
| 수집 정책 | **기본 켜짐**, 앱 내 끄기는 설정 페이지(Ralli 작업 #8)에서 | `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)` 한 줄이 진입점 |
| Debug 빌드 | 별도 분기 없음 | 디버거가 붙어 있으면 Crashlytics 가 업로드하지 않는다. 테스트·프리뷰는 `NoopCrashReporter` |

## 구조

```
Packages/YJKit/Sources/MonitoringCore/
├─ CrashReporting.swift        protocol — 앱이 아는 유일한 타입
├─ MonitoringError.swift       non-fatal 용 Error. domain·code 가 안정적이라 Crashlytics 가 같은 이슈로 묶는다
├─ CrashlyticsReporter.swift   Firebase 구현
└─ NoopCrashReporter.swift     테스트·프리뷰
```

```swift
public protocol CrashReporting: Sendable {
    /// 죽지 않은 오류. context 는 Crashlytics 커스텀 키로 붙어 대시보드에서 필터된다.
    func record(_ error: Error, context: [String: String])
    /// 크래시 리포트에 딸려 가는 브레드크럼. 최근 것만 남는다.
    func log(_ message: String)
}
```

메서드 두 개로 시작한다. `setUserID` 등은 계정이 생기면 그때.

`MonitoringError` 는 `CustomNSError` 를 채택해 `domain`·`code` 를 고정한다 — Crashlytics 는 non-fatal 을 NSError 의 domain+code 로 그룹핑하므로, 매번 다른 메시지를 넣어도 "저장 ACK 타임아웃" 이 한 이슈로 모인다.

### 앱이 소유하는 것 (코어가 대신 못 하는 것)

- `FirebaseApp.configure()` 호출 — 앱 진입점 `init` 에서. iOS·워치 각각
- `GoogleService-Info.plist` — Firebase 콘솔에서 앱(번들 ID)마다 받는다. 타깃별로 다르다
- dSYM 업로드 Build Phase — 타깃별
- App Privacy 라벨 (Crash Data · Other Diagnostic Data)
- 리포터 주입 — `CrashlyticsReporter()` 를 만들어 ViewModel 에 넘긴다. 코어는 싱글톤을 두지 않는다

"코어는 도메인을 모른다" — Firebase 프로젝트가 뭔지, 어느 번들인지는 코어가 알 수 없다.

## Firebase 프로젝트

콘솔에 **프로젝트 하나(Ralli)** 에 **Apple 앱 두 개** — `com.yj.TennisCounter`, `com.yj.TennisCounter.watchkitapp`. Crashlytics 대시보드는 앱 단위로 갈린다. 골프·하루치는 각자 프로젝트를 판다 (앱마다 사용자 집단이 다르다).

## dSYM

크래시 스택을 사람이 읽으려면 빌드마다 심볼 파일을 올려야 한다. Firebase 패키지에 딸려오는 `upload-symbols` 를 Build Phase 로 타깃마다 건다.

- `ENABLE_USER_SCRIPT_SANDBOXING = YES` 면 스크립트가 plist·dSYM 을 못 읽고 **조용히 실패**한다. 타깃 설정을 확인한다
- Release(Archive) 에서만 의미가 있다. Debug 는 조건으로 건너뛴다
- CI 는 Archive 를 안 하므로 영향 없음

## 검증 순서

1. **스파이크** — 빈 `MonitoringCore` 에 `FirebaseCrashlytics` 의존만 걸고 `make kit-test` + Ralli iOS·워치 스킴 빌드 + **CI 통과**. 로컬 SPM 패키지가 원격 바이너리(xcframework) 의존을 끄는 첫 사례라 여기서 막히면 구조를 다시 본다
2. 프로토콜·구현 + 테스트
3. Ralli 연동 — 실기기에서 강제 크래시(iOS·워치 각각) → 재실행 → 콘솔에 심볼 붙은 스택. non-fatal 은 폰 앱 종료 후 워치 저장 → 8초 타임아웃 → 콘솔 non-fatal 탭

## 하지 않는 것

- 골프·하루치 연동 — `MonitoringCore` 는 만들지만 링크는 Ralli 만. 두 번째 소비자가 붙을 때 프로토콜이 맞는지 다시 본다
- 크래시 리포팅 on/off UI — 설정 페이지 작업
- Analytics 이벤트 — Phase 2
- 자체 백엔드·MetricKit 수집 — 백엔드가 없다

## 관련 문서

- YJKit 플랜: [2026-09-07-monitoring-core.md](../../../plans/shared/2026/2026-09-07-monitoring-core.md)
- Ralli 연동 플랜: [Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md](../../../../../../Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md)
- Xcode 타깃 규약 (`ENABLE_USER_SCRIPT_SANDBOXING`, `INFOPLIST_KEY_*`): [docs/specs/2026/2026-09-03-xcode-target-conventions.md](../../../../../../docs/specs/2026/2026-09-03-xcode-target-conventions.md)
