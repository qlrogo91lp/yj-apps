# GolfCounter 리빌드 설계 (v1)

- 작성일: 2026-07-31
- 참조: Notion 기획 문서 「GolfCounter」, `../ralli-kit`, `../tennis_counter` (구조·컨벤션 기준)
- 범위: 워치+iOS 전체 리빌드 — 플랫폼 공통이므로 specs/ 루트에 둔다

## 1. 목표·포지셔닝

- 경쟁 앱이 많은 카테고리이므로 **기본기에 충실한 심플한 카운터 앱**으로 포지셔닝한다.
- **워치가 메인 입력 디바이스**, iOS는 기록 열람·수정·통계 전용.
- 동기화는 **단방향(워치 → 폰) 전송**만 있다. 양방향 동기화 없음.
- 디자인(아이콘/화면)은 별도 진행(본인 작업). 이 문서는 기획·데이터·흐름만 다룬다. 앱 아이콘은 이미 준비되어 있다.
- 앱 이름은 "GolfCounter with Watch"가 유력안. 표시명 교체 작업은 구현 순서 ⑦에 포함하되, 최종 이름 확정은 이 spec 범위 밖.

### v1 범위 (전부 이번 spec에 포함)

1. 앱 아이콘 변경
2. 컴플리케이션 / Smart Stack
3. 글로벌화 (영어, 한글) — String Catalog(`.xcstrings`) 기반
4. SwiftData + CloudKit 경기 기록 저장 (PersistenceCore 재사용)
5. HealthKit 연동 — `.golf` 활동 타입 + `.indoor`(GPS 미사용)
6. 퍼팅 카운트 분리
7. iOS 통계 화면
8. MapKit 골프장 자동 감지 (실패 시 수동 입력 폴백)

v1.1로 미룸: Digital Crown 카운트 조정, GPS 경로 토글.

## 2. 프로젝트 구조

### 저장소·프로젝트 전략

- **기존 golf_counter 저장소에서 리빌드**한다. 번들 ID(`com.yj.GolfCounter`, `.watchkitapp`)와 App Store 앱(MARKETING_VERSION 2.0) 연속성을 유지한다.
- pbxproj는 **Xcode 16의 `PBXFileSystemSynchronizedRootGroup` 방식으로 재구성**한다 (tennis_counter와 동일). 이후 파일 추가/삭제는 파일시스템 조작만으로 빌드에 반영된다. 레거시 PBXGroup 수동 관리 폐기.
- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구사항).
- 기존 소스(Single Game, Score Board, 타깃별 중복 `Model/`·`Views/`)는 **전부 삭제·대체**된다.

### 타깃

| 타깃 | 플랫폼 | 역할 |
|------|--------|------|
| `GolfCounter` | iOS 17+ | 기록·통계 (입력 없음) |
| `GolfCounter Watch App` | watchOS 10+ | 라운드 진행·카운팅 (메인 입력) |
| `ComplicationApp` | watchOS 위젯 익스텐션 (신규) | 컴플리케이션 + Smart Stack |

### 의존성

- **ralli-kit 로컬 SPM 패키지** (`../ralli-kit`): `WorkoutCore` / `ConnectivityCore` / `PersistenceCore`.
- 그 외 외부 의존성 없음.

### 폴더 구조 (tennis_counter 컨벤션 그대로)

```
Shared/
├── Models/            # 플랫폼 독립 순수 모델 (RoundSnapshot 등)
├── Persistence/       # SwiftData @Model (GolfRound)
└── Services/          # ConnectivityMessages, 시스템 API 래퍼
iOSApp/
├── Components/        # 두 Feature 이상 공유 UI
└── Features/
    ├── History/       # 기록 탭
    └── Stats/         # 통계 탭
WatchApp/
├── Components/
└── Features/
    ├── Home/          # 시작 화면
    └── Round/         # 라운드 세션 (파 선택·카운터·컨트롤·메트릭·요약)
ComplicationApp/
iosTests/              # 소스 폴더 구조 미러링
watchosTests/
```

- 계층화 컴포넌트 규칙, import 규칙(순환 의존 금지), MVVM(ViewModel은 UI 프레임워크 import 금지), 파일 네이밍(View suffix는 화면만, 한 파일 = 한 타입) 모두 tennis_counter CLAUDE.md 규칙을 따른다.
- 잔재 정리: 타깃에 속하지 않는 `Widget/`, `GolfCounterWidget/`, `Complications/` 등 leftover 디렉터리는 리빌드 시 삭제한다.

## 3. 데이터 모델

### GolfRound (SwiftData, `Shared/Persistence/GolfRound.swift`)

CloudKit 규칙 준수: 전 프로퍼티 optional 또는 기본값, `.unique` 금지.

```swift
@Model
final class GolfRound {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var courseName: String?          // MapKit 자동 감지 → iOS에서 수정 가능
    var holeScores: [Int] = []       // 인덱스 = 홀 번호 - 1
    var holePars: [Int] = []         // 같은 인덱스, 홀 진입 시 필수 입력 (3/4/5)
    var puttCounts: [Int] = []       // 같은 인덱스, 퍼팅은 타수에 포함되는 개념
    var calories: Double = 0
    var avgHeartRate: Double = 0
    var distanceMeters: Double = 0
    var steps: Int = 0

    var totalStrokes: Int { holeScores.reduce(0, +) }
    var totalPutts: Int { puttCounts.reduce(0, +) }
    var totalPar: Int { holePars.reduce(0, +) }
    var relativeToPar: Int { totalStrokes - totalPar }   // 통계·표시의 핵심 지표
}
```

- 홀 데이터는 별도 `@Model` 관계가 아니라 **병렬 배열**로 처리한다. CloudKit 관계 설정 부담을 피하고, 항상 라운드 단위로 함께 읽고 쓰므로 배열이 적합하다.
- `holeCount`는 저장하지 않고 `holeScores.count`에서 파생한다. **9홀/18홀 선택 UI 자체가 없다** — "라운드 시작" 버튼 하나만 있고, 종료 시점까지 기록된 홀 수가 그 라운드의 길이다. (전반/후반 이어치기 엣지케이스가 자연히 사라짐)
- 파 대비 스코어(`relativeToPar`, 예: +3)가 절대 타수보다 우선하는 핵심 표시값이다.
- 컨테이너는 `PersistenceContainerFactory.make(for: [GolfRound.self], cloudKit: true)` 사용. iCloud 미로그인·엔타이틀먼트 부재 시 로컬 폴백은 PersistenceCore가 이미 처리한다. SwiftData 저장은 **iOS 타깃만** 수행한다 (워치는 저장소 없음).

### 카운터 규칙 (불변식)

| 조작 | 효과 |
|------|------|
| 스윙 모드 `+` | 타수 +1 |
| 스윙 모드 `−` | 타수 −1, 단 **타수 ≥ 퍼팅** 유지 (퍼팅 수 아래로 불가) |
| 퍼팅 모드 `+` | 타수 +1 & 퍼팅 +1 |
| 퍼팅 모드 `−` | 타수 −1 & 퍼팅 −1, 0 미만 불가 |

- 하한 0, **상한 클램프 없음** (기존 앱의 par×2 제한 폐기 — 실제 골프는 초과 가능).
- 홀 이동 시 세그먼트 토글은 **스윙 모드로 리셋**된다.

### RoundSnapshot (`Shared/Models/RoundSnapshot.swift`)

라운드 *진행 중* 상태의 경량 스냅샷 (`Codable` struct):

- 시작 시각, 골프장명, 현재 홀 번호, `holeScores`/`holePars`/`puttCounts` 배열
- 워치가 상태 변경 시마다 **App Group UserDefaults**에 JSON으로 저장한다.
- 용도 2가지: ① 워치 앱 강제종료/크래시 후 라운드 복구, ② 컴플리케이션의 "라운드 중" 표시 데이터원. 저장 한 번으로 두 용도를 겸한다.
- App Group: `group.com.yj.GolfCounter` (워치 앱 + ComplicationApp 공유).

## 4. 워치 화면 흐름

### 시작 화면 (`WatchApp/Features/Home/`)

- 버튼 하나: **"라운드 시작"** (9/18홀 선택 없음) + 최근 라운드 요약 한 줄.
- 탭 시: `requestLocation()` 1회(골프장 자동 감지, 실패해도 무시하고 진행) → 워크아웃 세션 시작(`.golf`, `.indoor`) → 라운드 화면 진입.
- 실행 시 App Group에 진행 중 스냅샷이 있으면 시작 화면 대신 **라운드를 복구**한다 (HKWorkoutSession 복구와 함께).

### 파 선택 화면

- **해당 홀에 파가 아직 설정되지 않았을 때만 등장** (홀 이동 방향과 무관 — "파 존재 여부"가 조건).
  - 새 홀 최초 진입 → 파 선택 화면
  - 이미 파가 설정된 홀로 이동 → 바로 카운터 화면
- Par 3 / 4 / 5 버튼을 **세로로 길게 배치**, 원탭 즉시 선택. (Confirm 2단계 대비 홀당 탭 1회 절약, 오터치 위험 낮음)
- 카운터 화면의 [Par] 버튼으로 현재 홀 파 정정 가능 — 같은 화면을 재사용하되 현재 값을 하이라이트.
- 지난 홀 파 재수정: 이전 홀로 이동해 [Par]로 정정 / 라운드 종료 후엔 iOS 상세 화면에서 일괄 수정.

### 라운드 세션 — 3페이지 TabView (tennis WorkoutSession 패턴)

**페이지 1/3 컨트롤**: 일시정지 / 라운드 종료 / 잠금(오터치 방지, water lock 방식)

**페이지 2/3 메인 카운터 (기본 화면)**:

```
┌─────────────────┐
│ H7 · Par 4   +3  │   ← 홀번호·파 / 누적 오버파
│    5타 · 2퍼트    │   ← 현재 홀 스코어
│  ┌────┐ ┌────┐  │
│  │ ＋ │ │ － │  │   ← 원형 +/- 버튼 나란히 (기존 앱 검증 레이아웃)
│  └────┘ └────┘  │
│ [스윙|퍼팅] [Par]  │   ← 세그먼트 토글 + 파 정정
│ [← 이전]  [다음 →] │   ← 홀 이동 (이동 시 토글 스윙 리셋)
└─────────────────┘
```

- `+`/`−`에 서로 다른 햅틱 패턴 적용 (오조작 인지용).
- 아래로 스크롤(crown) 시 전체 스코어카드 표시 — 모달 아님:

```
H1  Par3  4타(2p)  +1
H2  Par4  3타(1p)  -1
...
합계 41타 · 12퍼트 · +3
```

**페이지 3/3 메트릭**: 심박수 · 칼로리 · 거리 · 경과 시간 실시간 표시 (WorkoutCore 경유).

### 종료 요약

- 총타수 · 총퍼트 · 골프장명 표시 → **"저장 & 전송"** 버튼.
- 워치는 완료 라운드를 로컬 저장하지 않는다. `.reliable`로 즉시 전송하고 iOS가 SwiftData에 저장한다.
- 전송 트리거 후 App Group 스냅샷을 제거하고 시작 화면으로 복귀한다. (미도달 시 배달은 transferUserInfo 큐가 보장 — §5)

## 5. 전송 (워치 → iOS, 단방향)

- `ConnectivityCore`의 `Delivery.reliable` 사용: `sendMessage` 시도 → 미도달 시 `transferUserInfo` 큐잉. 시스템 큐가 iPhone 도달 시점까지 배달을 보장하므로 워치 쪽 재시도 로직은 만들지 않는다.
- **라운드 종료 시 1회 일괄 전송**. 홀 단위 실시간 전송 없음.
- `Shared/Services/ConnectivityMessages.swift`에 `RoundCompletedMessage` 정의 (tennis 패턴: `ConnectivityMessage` 채택, `toDictionary()` / `init?(from:)` 직렬화). 페이로드는 `GolfRound`의 전 필드 + 워크아웃 메트릭.
- iOS 수신 측: `MessageRouter`로 라우팅 → `GolfRound` 생성 → SwiftData 저장. 수신은 앱 실행 중이 아니어도 다음 실행 시 큐에서 배달된다.
- 중복 방지: 수신 시 동일 `id`의 라운드가 이미 있으면 무시한다 (transferUserInfo 재배달 대비).

## 6. iOS 화면 흐름

### 기록 탭 (`iOSApp/Features/History/`)

- 라운드 리스트 (최신순, 날짜·골프장명·총타수·오버파) → 상세 화면.
- **상세 화면**: 읽기 전용 스코어카드 리스트(`H1 Par4 5타 2p +1 …` + 합계 행) + 워크아웃 메트릭 요약 + 골프장명 인라인 수정.
- **홀 행 탭 → 편집 시트**: Par 세그먼트(3/4/5) + 타수/퍼팅 스테퍼. §3의 카운터 불변식(타수 ≥ 퍼팅, 하한 0) 동일 적용. 워치 오입력의 최종 구제 지점.

### 통계 탭 (`iOSApp/Features/Stats/`)

Swift Charts 기반:

- 최근 라운드 **오버파(relativeToPar) 추이** — 주 지표 (골프장 난이도 보정 관점에서 절대 타수보다 우선)
- 베스트 스코어, 평균 타수, 평균 퍼팅

## 7. 컴플리케이션 / Smart Stack (`ComplicationApp/`)

tennis_counter `ComplicationApp` 구조 재활용: App Group UserDefaults 상태 공유, `StaticConfiguration` + `TimelineProvider`, 위젯 익스텐션 타깃.

| 패밀리 | 평상시 | 라운드 중 |
|--------|--------|-----------|
| `accessoryCircular` / `accessoryCorner` | 앱 아이콘 | 배경색 전환으로 진행 중 표시 |
| `accessoryRectangular` (Smart Stack) | 아이콘 + "라운드 시작" | 현재 홀 · 누적 오버파 · 총타수 |

- 데이터원: §3의 `RoundSnapshot` (App Group). 워치 앱이 스냅샷 저장/삭제 시 `WidgetCenter.reloadAllTimelines()` 호출.
- 딥링크: 평상시 탭 → 앱 실행(시작 화면에서 원탭 시작), 라운드 중 탭 → 카운터 화면 복귀. 별도 URL 라우팅 없이 앱 실행 + 스냅샷 존재 여부로 분기한다 (§4 시작 화면 복구 로직과 동일 경로).
- tennis의 회전 애니메이션 등 장식 요소는 아이콘 디자인 확정 후 결정 (spec 범위 밖).

## 8. HealthKit (WorkoutCore)

- `WorkoutConfiguration(activityType: .golf, locationType: .indoor)`.
- GPS 미사용 → 배터리 절약. 거리·걸음수는 가속도계 기반, 심박수는 광학센서 그대로.
- 트레이드오프: HealthKit에 GPS 루트(동선 지도)가 안 남음 → 기본기 우선 포지셔닝상 수용 (v1.1에서 GPS 토글 검토).
- 세션 관리: **1일 1라운드 = 세션 1개**로 단순화. Ralli와 달리 별도 세션 관리 레이어 불필요.
- 라운드 종료 시 `WorkoutResult`의 메트릭(칼로리·평균 심박·거리·걸음수)을 `RoundCompletedMessage`에 담아 전송한다.

## 9. MapKit 골프장 감지

- 라운드 시작 시점 **1회 `requestLocation()`** 만 사용 (연속 추적 없음 → 배터리 영향 최소).
- `MKLocalSearch` + `MKPointOfInterestCategory.golf`로 근처 골프장 검색, 최근접 결과를 `courseName`으로.
- 국내 스크린골프/일부 퍼블릭 골프장은 애플 지도 POI 데이터가 부실할 수 있음 → 감지 실패/미발견/권한 거부 시 `courseName = nil`로 진행하고 **iOS 상세 화면에서 수동 입력 폴백**. 감지 실패가 라운드 시작을 막지 않는다.
- 위치 권한: `whenInUse`, 시작 버튼 탭 시 요청. 거부해도 라운드 진행에 지장 없음.

## 10. 로컬라이즈

- **String Catalog(`.xcstrings`)** 기반 ko/en. tennis의 lproj 방식 대신 신규 표준 채택 (Xcode 15+).
- 세 타깃(iOS/워치/컴플리케이션) 각각의 사용자 노출 문자열 전부 + `InfoPlist.xcstrings`(표시명 등).

## 11. 테스트 (tennis_counter 컨벤션)

- Swift Testing (`@Test`, `#expect`). 테스트 루트: `iosTests/` / `watchosTests/` (소스 구조 미러링).
- 우선순위: ① ViewModel(카운터 불변식, 파 선택 조건, 홀 이동, 복구 로직) ② Service(RoundCompletedMessage 직렬화 왕복, RoundSnapshot 인코딩) ③ Model(GolfRound 파생 프로퍼티) ④ View는 테스트하지 않음.
- ViewModel 테스트 `@MainActor`, 테스트명 `대상_행위_예상결과` 형태, HealthKit/WatchConnectivity는 직접 호출하지 않고 순수 상태 변화만 검증.

## 12. 에러 처리 요약

| 상황 | 처리 |
|------|------|
| iCloud 미로그인/CloudKit 실패 | PersistenceCore가 로컬 컨테이너로 폴백 (기존 동작) |
| 전송 시 iPhone 미도달 | transferUserInfo 큐가 도달 시점까지 보장, 워치 측 재시도 없음 |
| 동일 라운드 재배달 | iOS 수신부가 `id` 중복 검사로 무시 |
| 워치 앱 크래시/강제종료 | App Group 스냅샷 + HKWorkoutSession 복구로 라운드 재개 |
| 위치 실패/권한 거부/POI 미발견 | `courseName = nil` 진행, iOS에서 수동 입력 |

## 13. 구현 순서

**공통 기반 작업을 먼저 묶어 진행**하고, 그 위에서 나머지를 플랫폼별로 나눈다. plan 문서는 `docs/superpowers/plans/`에 flat하게 두고 **파일명에 `common-`/`watch-`/`ios-` prefix**로 구분한다 (서브폴더 분리는 하지 않음). 전송처럼 양쪽에 걸치는 기능 작업은 발신(워치)/수신(iOS)으로 나눠 각 플랫폼 plan에 담는다.

### 공통 파트 (기반 작업, 먼저)

| 순서 | plan | 내용 |
|------|------|------|
| ① | common | **프로젝트 재구성 + 아이콘** — pbxproj 재구성(Xcode 16 방식, 타깃 3개, ralli-kit 연동, 폴더 구조·잔재 정리), `Shared/`의 `GolfRound`/`RoundSnapshot` 정의, App Group 설정, 준비된 아이콘 적용 |
| ② | common | **컴플리케이션 / Smart Stack** — ComplicationApp 3종 패밀리, App Group의 `RoundSnapshot` 읽기 (스냅샷 부재 시 평상시 상태 — 워치 카운터 완성 전에도 동작) |

### 플랫폼 파트 (공통 파트 위에서)

| 순서 | plan | 내용 |
|------|------|------|
| ③ | watch | **워치 카운터 코어** — 홈·파 선택·카운터·세션(WorkoutCore), `RoundSnapshot` 기록·복구 |
| ④ | watch | **라운드 전송 (발신)** — `RoundCompletedMessage` 정의(Shared) + 종료 요약 → `.reliable` 발신, 스냅샷 제거 |
| ⑤ | ios | **수신 + 기록 탭** — MessageRouter 수신·중복 검사·SwiftData 저장, 기록 리스트/상세/편집 시트 |
| ⑥ | ios | **통계 탭** — Swift Charts (오버파 추이, 베스트/평균 타수, 평균 퍼팅) |
| ⑦ | common | **로컬라이즈 + 이름 교체** — `.xcstrings` ko/en, 표시명 반영 |
| ⑧ | watch | **MapKit 골프장 감지 (마지막)** — 위치 1회 조회 + POI 검색 + 수동 입력 폴백. 그 전까지 `courseName`은 항상 nil로 시작하고 iOS에서 수동 입력 |
| — | | *(v1.1)* Digital Crown 조정, GPS 경로 토글 |

## 14. 범위 밖 (명시적 제외)

- 화면 비주얼 디자인 (본인 작업 — 이 문서는 레이아웃 구조까지만)
- 앱 이름 최종 확정, App Store 등록 정보
- 양방향 동기화, 홀 단위 실시간 전송
- GPS 루트 기록, Digital Crown 입력 (v1.1)
- 워치 로컬 완료 기록 보관 (완료본은 iOS만 보관)
