# iOS 기록 탭 · 통계 탭 설계

작성일: 2026-08-13
참조 스펙: `2026-07-31-golfcounter-rebuild-design.md` (§6 iOS 화면 흐름을 상세화·개정)
선행 plan: `2026-08-05-watch-round-transmission.md` (plan ④, 미구현) — 워치 발신이 없으면 이 화면에 표시할 데이터가 없다
대응 plan: ⑤ `ios-` (수신 + 기록 탭), ⑥ `ios-` (통계 탭)

## 0. 실행 순서 (확정)

**plan ④(워치 발신)를 먼저 구현하고, 그다음 이 문서의 ⑤ → ⑥으로 간다.**

| 순서 | plan | 상태 |
|------|------|------|
| 1 | ④ watch — 9/18홀 선택 + 종료 요약 + `.reliable` 발신 | 문서만 있음, 코드 미구현 |
| 2 | ⑤ ios — 수신 + 기록 탭 | 이 문서 §4·§6 |
| 3 | ⑥ ios — 통계 탭 | 이 문서 §5 |

발신을 먼저 두는 이유는 두 가지다. 첫째, ⑤의 수신부는 실제로 도착하는 `RoundCompletedMessage` 없이는 통합 검증이 불가능하고 목 데이터로만 확인하게 된다. 둘째, ④가 `RoundCompletedMessage`의 필드와 미기록 홀 트림 규칙을 확정하는데, ⑤가 그 결과를 그대로 `GolfRound`로 옮겨 담으므로 순서가 뒤집히면 계약을 두 번 정하게 된다.

**주의**: plan ④ 문서는 2026-08-05에 작성되었고 그 뒤 카운터 재설계(`2026-08-12-watch-counter-redesign.md`)가 머지되어 `RoundSessionView`·`CounterPage` 구조가 바뀌었다. plan ④의 설계 판단(홀 수 상한, 트림, 요약을 phase 전환으로 처리)은 그대로 유효하지만 **Step 단위의 코드 스니펫은 현재 파일과 어긋날 수 있으므로, 실행 전에 현재 코드 기준으로 한 번 훑어 갱신한다.**

## 1. 목표·범위

리빌드 스펙 §6은 iOS 두 탭의 골격만 정해 두었다. 이 문서는 그 골격을 **구현 가능한 수준까지 확정**한다 — 화면 계층, 컴포넌트 배치, 지표의 정확한 계산식, 9홀/18홀 혼재 처리, 편집 불변식.

iOS는 **입력 디바이스가 아니다**. 워치가 만든 라운드를 열람·정정하고 추이를 보는 것이 전부이며, iOS에서 라운드를 새로 만드는 경로는 없다.

### 이 문서가 다루는 것

- 탭 구조와 `iOSApp.swift` 진입점 교체
- 기록 탭: 리스트 · 상세 · 홀 편집 시트 · 삭제
- 통계 탭: 추이 차트 · 요약 카드 · 스코어 분포 · 파별 성적
- 워치 → iOS 수신·저장 서비스의 배치 (프로토콜·페이로드 정의는 §5에서 이미 확정, 여기서는 재정의하지 않는다)

### 범위 밖

- **로컬라이즈** — 이 화면들도 한국어 하드코딩으로 둔다. `.xcstrings` ko/en은 세 타깃 일괄로 plan ⑦에서 처리한다 (String Catalog는 타깃별로 분리되어 iOS만 먼저 해도 되지만, 이중 작업을 피해 워치와 한 번에 하기로 결정)
- **MapKit 골프장 자동 감지** — plan ⑧(워치 단독)로 이 작업 다음에 진행한다. 그때까지 `courseName`은 워치에서 항상 nil로 오고, **iOS 상세 화면의 수동 입력이 골프장명을 채우는 유일한 경로**다. MapKit이 붙어도 그 입력 필드는 자동 감지값의 수정 지점으로 그대로 재사용되므로 버릴 코드가 없다
- **GPS 경로 토글** — v1.1 유지 (`.indoor` → `.outdoor` 전환 + 경로 저장 + 지도 표시가 얽혀 MapKit과 성격이 다르다)
- 워치 발신(plan ④), 화면 비주얼 디자인(본인 작업 — 이 문서는 레이아웃 구조까지)

## 2. 화면 구조

### 진입점

`iOSApp/iOSApp.swift`의 placeholder `Text("GolfCounter")`를 `MainTabView`로 교체한다. 컨테이너는 기존 `PersistenceContainerFactory.make(for: [GolfRound.self])`를 유지하고, 앱 시작 시 수신 서비스를 활성화한다(§5).

tennis_counter의 `LaunchScreenView`는 이식하지 않는다 (YAGNI).

### 탭

| 순서 | 탭 | 심볼 | 역할 |
|------|-----|------|------|
| 0 | 통계 | `chart.bar.fill` | 추이·요약 (앱을 열면 먼저 보이는 화면) |
| 1 | 기록 | `clock.fill` | 라운드 리스트 → 상세 → 편집 |

`MainTabView`는 `iOSApp/MainTabView.swift`에 별도 타입으로 둔다 (tennis는 `iOSApp.swift`에 함께 두었으나 "한 파일 = 한 타입" 규칙을 따른다).

**비주얼 톤**: 시스템 라이트/다크를 따른다 (tennis의 `.colorScheme(.dark)` 고정은 이식하지 않는다 — 골프는 야외 주간 사용이 많다). 색은 시맨틱 컬러 위주로 쓰고, 오버파 표시에만 포인트 컬러를 둔다: 언더파(음수) · 이븐(0) · 오버파(양수) 세 가지. 구체 색값은 디자인 작업에서 확정하며, 이 문서는 "세 상태를 색으로 구분한다"까지만 정한다.

### 화면 계층

```
MainTabView
├── StatsView            (탭 0)
└── HistoryView          (탭 1, NavigationStack)
    └── RoundDetailView  (push)
        └── HoleEditSheet (sheet)
```

## 3. 용어와 공통 계산 규칙

이후 모든 지표는 아래 정의를 따른다. `GolfRound`는 `holeScores` / `holePars` / `puttCounts` 세 병렬 배열을 가진다(스펙 §3).

- **유효 홀**: `holePars[i] > 0` 인 홀. 워치에서 파를 고르지 않은 홀(`par == 0`)은 배열 중간에 남아 있을 수 있다 — 사용자가 의도적으로 건너뛴 홀이며 카운터에 접근한 적이 없으므로 `score`·`putts`도 0이다(스펙 §3).
- **집계 대상 홀**: 유효 홀 중 `holeScores[i] > 0` 인 홀. 파는 골랐지만 한 타도 치지 않고 넘어간 홀을 제외한다 — 이 홀을 넣으면 `score − par`가 음수가 되어 버디로 잘못 집계된다.
- **기록 홀 수**: 유효 홀의 개수. 리스트 뱃지에 `N홀`로 그대로 표시한다. `GolfRound.recordedHoleCount`로 파생한다.
- **18홀 라운드**: 기록 홀 수가 정확히 18인 라운드(`GolfRound.isFullRound`). 9홀을 골랐거나 18홀을 고르고 중단한 라운드는 여기 포함되지 않는다.
- **오버파(`relativeToPar`)**: `GolfRound`의 기존 계산 프로퍼티(`totalStrokes − totalPar`). `par == 0` 홀은 양쪽 합에 0으로 기여하므로 값이 왜곡되지 않는다.
- **오버파 표기**: 양수 `+3`, 0 `E`, 음수 `-2`. 기존 `Shared/Models/ScoreFormat.swift`의 `relativeToPar(_:)`를 재사용한다.

## 4. 기록 탭 (`iOSApp/Features/History/`)

### 리스트 (`HistoryView`)

- `@Query(sort: \GolfRound.startedAt, order: .reverse)`로 **전체 라운드를 한 번에 로드**한다. 페이징은 두지 않는다 — 골프는 연 수십 라운드 규모라 tennis의 페이징 구조가 불필요하다.
- 행은 `RoundCard` (History/Components/):
  - 상단: 날짜·시각 / 골프장명 (nil이면 행 자체를 생략, "미입력" 같은 placeholder를 두지 않는다)
  - 하단 좌측: `N홀` 캡슐 뱃지
  - 우측: **오버파를 크게**, 그 아래 총타수를 작게 (`+3` / `75타`)
- **빈 상태** (`EmptyRounds`): "기록된 라운드가 없습니다" + "Apple Watch에서 라운드를 시작하세요" 안내. 통계 탭도 같은 화면을 쓰므로 앱 루트 `Components/`에 둔다.
- **삭제**: 행 스와이프 → `confirmationDialog`로 확인 후 삭제. 되돌릴 수 없는 동작이므로 확인 단계를 생략하지 않는다. 삭제 진입점은 **리스트 한 곳뿐**이며, 상세 화면에는 두지 않는다.

### 상세 (`RoundDetailView`, push)

시트가 아니라 **push 네비게이션**을 쓴다. 스코어카드가 최대 18행이고 그 위에 편집 시트를 또 올려야 해서, 시트 위 시트 구조를 피한다.

`List` 4개 섹션:

1. **요약 헤더** — 오버파(가장 크게) · 총타수 · 총퍼트 · 날짜
2. **골프장** — `TextField`(placeholder "골프장명 입력"). 편집 종료 시 즉시 저장한다. 공백만 입력하면 `nil`로 되돌린다
3. **스코어카드** — 홀 행 + 합계 행
   - 홀 행(`HoleRow`): `H1 · Par 4` / `5타 · 2퍼트` / `+1`
   - `par == 0` 홀: `H3 · Par –` / `기록 없음` 으로 표시하고 오버파 칸은 비운다. 탭해서 파를 넣으면 정상 홀이 된다
   - 합계 행: `합계 75타 · 31퍼트 · +3`
   - **행 탭 → `HoleEditSheet`**
4. **워크아웃** — `StatCard` 그리드(2열): 칼로리 · 평균 심박 · 거리 · 걸음수 · 소요 시간. 소요 시간은 `endedAt − startedAt`으로 파생하고, `endedAt`이 nil이면 `–`

### 홀 편집 시트 (`HoleEditSheet`)

워치 오입력의 최종 구제 지점이다.

- **Par**: 세그먼트 3 / 4 / 5
- **타수**: `Stepper`
- **퍼팅**: `Stepper`
- 저장 / 취소

**불변식** (워치 카운터와 동일, 스펙 §3):

| 규칙 | 시트에서의 강제 방식 |
|------|---------------------|
| 타수 ≥ 퍼팅 | 타수 스테퍼의 하한이 현재 퍼팅 값 |
| 퍼팅 ≥ 0, 타수 ≥ 0 | 스테퍼 하한 0 |
| 상한 없음 | 스테퍼 상한을 두지 않는다 (par×2 제한은 폐기됨) |

UI에서 위반 입력 자체가 불가능하지만, 편집 로직을 담은 `RoundEditViewModel`에도 같은 가드를 두고 테스트한다. ViewModel은 UI 프레임워크를 import하지 않는 순수 로직이다.

퍼팅을 올릴 때 타수가 그보다 작으면 **타수를 함께 올린다** (워치 퍼팅 모드 `+`와 같은 동작). 반대로 타수를 내려 퍼팅과 같아지면 거기서 멈춘다.

## 5. 통계 탭 (`iOSApp/Features/Stats/`)

`@Query`로 전체 라운드를 받아 **순수 계산 ViewModel**(`StatsViewModel`)이 `StatsSummary`를 만든다. ViewModel은 SwiftUI·Charts를 import하지 않으며, 계산 전체가 테스트 대상이다.

기간 필터는 두지 않는다. 골프는 라운드 빈도가 낮아 주/월 세그먼트가 빈 화면을 만든다.

화면 순서: 추이 차트 → 요약 카드 → 스코어 분포 → 파별 성적.

### 9홀/18홀 혼재 처리 (핵심 결정)

총타수 기반 지표는 9홀 라운드가 섞이면 무의미해진다. 그래서 지표를 두 부류로 나눈다:

- **라운드 단위 지표**(평균 타수, 평균 오버파) → **18홀 라운드만** 집계하고, 카드에 `18홀 라운드 N개 기준` 캡션을 단다. 18홀 라운드가 하나도 없으면 값 대신 `–`
- **홀 단위 지표**(홀당 퍼트, 스코어 분포, 파별 성적) → 홀 수에 영향받지 않으므로 **모든 라운드의 집계 대상 홀**을 쓴다

추이 차트는 9홀 라운드도 함께 그리되 **심볼로 구분**한다.

### ① 오버파 추이 차트 (`OverParTrendChart`, Swift Charts)

- 최근 **10라운드**(`startedAt` 최신 10개를 뽑아 오름차순으로 배치), x축 = 날짜 축약 표기, y축 = 오버파
- `LineMark` + `PointMark`, `E`(0) 위치에 `RuleMark` 기준선
- 18홀 라운드는 원, 그 외(9홀·중단 라운드)는 마름모 심볼 (Swift Charts의 `BasicChartSymbolShape`에 속이 빈 원이 없어 형태로 구분한다)
- 섹션 헤더에 `총 N라운드` 표기 (라운드 수를 카드 자리에 두지 않는다)
- 라운드가 1개여도 점 하나를 그대로 그린다. 0개일 때만 빈 상태

### ② 요약 카드 (`StatCard` 2×2)

| 카드 | 계산 | 표기 예 | 대상 없을 때 |
|------|------|---------|-------------|
| 평균 타수 | 18홀 라운드의 `totalStrokes` 평균 | `92.4` | `–` |
| 베스트 스코어 | 전체 라운드 중 최소 `relativeToPar`, 동률이면 최신 | `+2 · 18홀` | `–` |
| 평균 오버파 | 18홀 라운드의 `relativeToPar` 평균 (소수 1자리) | `+18.6` | `–` |
| 홀당 평균 퍼트 | 전체 집계 대상 홀의 `putts` 합 ÷ 홀 수 (소수 1자리) | `1.9` | `–` |

베스트만 전체 라운드를 대상으로 한다 — 9홀 라운드가 유리하게 잡힐 수 있어 **홀 수를 함께 표기**해 오해를 막는다.

### ③ 스코어 분포 (`ScoreDistributionChart`)

집계 대상 홀 전체를 `score − par` 값으로 4구간에 넣고 가로 `BarMark`로 그린다. 각 구간에 개수와 비율을 함께 표시한다.

| 구간 | 조건 |
|------|------|
| 버디 이상 | `score − par ≤ −1` |
| 파 | `= 0` |
| 보기 | `= +1` |
| 더블보기+ | `≥ +2` |

### ④ 파별 성적 (`ParPerformanceRow`)

Par 3 / Par 4 / Par 5 각각 **홀당 평균 오버파**를 3열 미니 카드로 보여준다 (`Par 4 · +1.2`). 해당 파의 집계 대상 홀이 없으면 그 칸만 `–`. 어느 파에서 타수를 잃는지 드러내는 지표다.

### 빈 상태

라운드가 0개면 차트·카드 대신 기록 탭과 같은 안내 문구를 보여준다.

## 6. 데이터 흐름 (수신)

전송 규약은 리빌드 스펙 §5에서 확정되었다 (`RoundCompletedMessage`, `.reliable`, id 중복 검사). 이 문서는 **iOS 쪽 배치**만 정한다.

- 수신은 두 겹으로 나눈다. `iOSApp/Services/RoundReceiveService.swift`가 `ConnectivityService` 생성과 `onReceive` 등록만 맡고, 실제 적재·중복 검사는 WatchConnectivity를 모르는 `iOSApp/Services/RoundImporter.swift`가 한다 — 후자는 인메모리 컨테이너로 테스트할 수 있다
- 등록은 **`ConnectivityService`를 만든 그 main-queue turn 안에서** 끝내야 한다. 활성화 콜백(콜드런치 컨텍스트 배달)이 다음 turn에 들어오므로, 늦게 등록하면 앱이 꺼져 있던 동안 도착한 라운드를 놓친다
- **중복 검사**: 같은 `id`의 라운드가 이미 있으면 저장하지 않고 무시한다 (`transferUserInfo` 재배달, 워치 복구 후 재전송 대비)
- 앱이 꺼져 있던 동안의 전송은 다음 실행 시 시스템 큐에서 배달된다. 수신 서비스는 콜드 런치 시점에 활성화되어야 한다
- 저장 후 별도 알림·배지는 두지 않는다 (v1). `@Query`가 자동으로 리스트를 갱신한다
- **편집·삭제·골프장명 수정은 iOS 로컬 SwiftData 변경으로 끝난다.** 워치로 되돌아가는 경로는 없다 (단방향 원칙)

## 7. 파일 구조

```
iOSApp/
├── iOSApp.swift                      # 진입점 (MainTabView로 교체)
├── MainTabView.swift                 # 2탭
├── Components/
│   ├── StatCard.swift                # 통계 탭 + 상세 워크아웃 섹션이 공유
│   ├── EmptyRounds.swift         # 기록 탭 + 통계 탭이 공유하는 빈 상태
│   └── ScorePalette.swift            # 오버파 3상태 색 매핑
├── Services/
│   ├── RoundReceiveService.swift     # ConnectivityService 등록 (얇은 배선)
│   └── RoundImporter.swift           # 적재 + id 중복 검사 (테스트 대상)
└── Features/
    ├── History/
    │   ├── HistoryView.swift
    │   ├── Components/
    │   │   └── RoundCard.swift
    │   └── Detail/
    │       ├── RoundDetailView.swift
    │       ├── RoundEditViewModel.swift
    │       └── Components/
    │           ├── HoleRow.swift
    │           ├── HoleEditSheet.swift
    │           └── WorkoutMetricsGrid.swift
    └── Stats/
        ├── StatsView.swift
        ├── StatsViewModel.swift
        ├── StatsSummary.swift        # 순수 struct (iOS 전용이므로 Shared 아님)
        └── Components/
            ├── OverParTrendChart.swift
            ├── ScoreDistributionChart.swift
            └── ParPerformanceRow.swift
```

`StatCard`가 앱 루트 `Components/`에 있는 이유는 History·Stats 두 Feature가 함께 쓰기 때문이다 (계층화 규칙). 나머지 컴포넌트는 전부 자기 화면 폴더 안에 갇힌다.

`pbxproj`는 `PBXFileSystemSynchronizedRootGroup`이므로 파일 생성만으로 iOS 타깃에 반영된다. `iOSApp/`은 iOS 타깃 전용이라 plan ④에서 문제가 됐던 타깃별 SPM 링크 차이(워치의 `WorkoutCore`, 컴플리케이션의 무링크)에 걸리지 않는다.

## 8. 에러 처리

| 상황 | 처리 |
|------|------|
| 메시지 파싱 실패(`init?(from:)` nil) | 조용히 무시. 워치가 `transferUserInfo` 재배달로 복구 가능한 구조라 iOS 재시도 없음 |
| 동일 라운드 재배달 | `id` 중복 검사로 무시 (§6) |
| iCloud 미로그인 / CloudKit 실패 | `PersistenceContainerFactory`가 로컬 컨테이너로 폴백 (기존 동작) |
| 편집 시트 불변식 위반 시도 | 스테퍼 범위로 애초에 불가능 + ViewModel 가드 |
| 라운드 삭제 | `confirmationDialog` 확인 후 삭제. CloudKit 전파는 SwiftData가 처리 |
| `par == 0` 홀 | 스코어카드에 `Par –`로 표시, 통계에서 제외, 편집으로 정상화 가능 (§3·§4) |
| 통계 대상 라운드 0개 / 18홀 라운드 0개 | 각각 빈 상태 화면 / 해당 카드만 `–` |

## 9. 테스트 (`iosTests/`, Swift Testing)

소스 구조를 미러링하고, ViewModel·Service만 테스트한다. View는 테스트하지 않는다.

**`StatsViewModelTests`**

- 라운드 0개 → 전 지표 빈 값
- 라운드 1개 → 추이 점 1개, 평균 = 그 값
- 9·18홀 혼재 → 평균 타수·평균 오버파는 18홀만, 홀당 퍼트는 전체
- 18홀 라운드 0개(9홀만 있음) → 평균 타수·평균 오버파 `–`, 나머지는 정상
- 베스트 동률 → 최신 라운드 선택
- 추이 차트 → 11라운드 이상일 때 최근 10개만, 오름차순
- 스코어 분포 경계 → `−1` 버디 이상, `0` 파, `+1` 보기, `+2` 더블보기+
- 파별 성적 → 해당 파 홀이 없는 구간은 빈 값
- `par == 0` 홀과 `score == 0` 홀이 모든 집계에서 제외됨

**`RoundEditViewModelTests`**

- 타수를 퍼팅 아래로 내릴 수 없음
- 퍼팅을 올리면 필요한 만큼 타수가 따라 올라감
- 타수·퍼팅 하한 0
- 상한 없음 (par×2를 넘어도 허용)
- 파 변경이 오버파 파생값에 반영됨
- `par == 0` 홀에 파를 넣으면 정상 홀이 됨

**`RoundImporterTests`** (`RoundReceiveService`는 등록만 하는 얇은 배선이라 테스트하지 않는다)

- 정상 메시지 → `GolfRound` 저장, 필드 1:1 일치
- 같은 `id` 재수신 → 저장하지 않음
- 저장된 라운드가 있는 상태에서 다른 `id` 수신 → 정상 추가
