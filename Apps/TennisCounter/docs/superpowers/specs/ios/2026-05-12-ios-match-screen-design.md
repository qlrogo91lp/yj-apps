# iOS 경기 화면 디자인 스펙

## 개요

iPhone 경기 탭의 매치 진행 화면. 표준 iOS UI를 최대한 활용하며, Watch 앱 구조를 iOS에 맞게 재해석한다.

## 진입 플로우

```
경기 탭 (앱 하단 TabView)
  └─ ModeSelectionView  (포맷 선택: One Set / Best of 3)
       └─ NavigationLink → MatchContainerView  (전체화면)
```

`MatchContainerView` 진입 시 `.toolbar(.hidden, for: .tabBar)` 로 앱 하단 탭바를 숨긴다. 표준 iOS NavigationBar 백버튼을 그대로 사용한다 (커스텀 없음).

## MatchContainerView 구조

표준 `TabView` (`.tabViewStyle(.automatic)`) 로 두 탭을 구성한다. Liquid Glass 탭바는 iOS 기본 동작으로 자동 적용된다.

```
MatchContainerView
  ├─ Tab 1: WorkoutTab  (🏃 운동)   — Watch 연동 시에만 표시
  └─ Tab 2: ScoreTab   (🎾 경기)   — 항상 표시, 기본 선택
```

Watch 미연동 시 운동 탭 자체를 숨겨 경기 탭 하나만 표시한다.

## Tab 1: 운동 탭

Watch 앱 `WorkoutMetricsView` 와 동일한 색상 및 레이아웃을 따른다.

**메트릭 (한 줄씩, 왼쪽 정렬):**
- 운동 시간 — `#FFD60A` (노랑)
- kcal — `#FF6B35` (주황)
- bpm — `#FF3B30` (빨강)

폰트: `.system(size: ~44, weight: .bold, design: .rounded)`, tabular-nums

**하단 버튼 (가로 2개):**
- 일시정지 / 재개 — `#FFD60A` tint, 배경 `rgba(255,214,10,0.10)`
- 운동 종료 — `#FF3B30` tint, 배경 `rgba(255,59,48,0.10)`

Watch 미연동 시 운동 탭 자체가 숨겨지므로 이 뷰는 항상 유효한 메트릭 값을 받은 상태에서만 표시된다.

## Tab 2: 경기 탭

Watch 앱 `MatchView` 의 ZStack 레이아웃을 iOS 화면 크기에 맞게 확대한다.

**배경 레이어 (HStack, ignoresSafeArea):**
- 좌: 나 — `rgba(52,199,89,0.11)` 배경, 탭 시 포인트 추가
- 우: 상대 — `rgba(255,149,0,0.11)` 배경, 탭 시 포인트 추가
- 포인트 점수 (40 / 15): 각 반쪽 중앙, `.system(size: ~70, weight: .heavy)`

**오버레이 레이어 (ZStack, 포인터 이벤트 없음):**
- 상단 중앙:
  - Best of 3: 세트 스코어 (1–0) → 게임 스코어 (3–2) 순으로 세로 배치
  - One Set: 게임 스코어만 표시
- 하단 중앙: Undo 버튼 (마지막 1포인트 취소, Watch와 동일)

**Long press → 점수 수정 시트:**
- 어느 쪽 반쪽이든 길게 누르면 `.sheet` 등장
- 시트 내용: 나 / 상대 각각 `[−] 점수 [+]` stepper
- 현재 포인트를 직접 조정 후 확인
- 표준 iOS `.presentationDetents([.height(200)])` 사용

## 데이터 흐름

```
MatchContainerViewModel
  ├─ phase: MatchPhase  (.modeSelection / .playing / .finished)
  ├─ watchConnected: Bool  (WatchConnectivityService 구독)
  ├─ metrics: WorkoutMetrics  (시간·kcal·bpm, Watch에서 수신)
  └─ MatchViewModel  (포인트·게임·세트 로직, Shared 공유)
```

`WatchConnectivityService` 가 Watch로부터 메트릭을 수신하면 `MatchContainerViewModel` 이 `watchConnected` 와 `metrics` 를 업데이트한다.

## 컴포넌트 파일 구조

```
iOSApp/Features/Match/
  ├─ Mode/
  │   ├─ ModeSelectionView.swift       (기존 유지)
  │   └─ ModeSelectionViewModel.swift  (기존 유지)
  └─ Session/
      ├─ MatchContainerView.swift       (신규 — TabView 컨테이너)
      ├─ MatchContainerViewModel.swift  (신규 — 플로우 + Watch 연동)
      ├─ Workout/
      │   └─ WorkoutTabView.swift       (신규 — 메트릭 + 버튼)
      └─ Score/
          ├─ ScoreTabView.swift         (신규 — ZStack 스코어 레이아웃)
          │                              기존 iOSApp MatchViewModel 을 @StateObject 로 소유
          └─ Components/
              ├─ PlayerScoreZone.swift  (신규 — 탭 가능한 반쪽 영역)
              ├─ ScoreOverlay.swift     (신규 — 세트·게임 오버레이)
              └─ ScoreEditSheet.swift   (신규 — long press 수정 시트)
```

`Shared/Models/` 변경 없음 — `Score`, `MatchPhase`, `MatchOptions`, `SetScore` 그대로 재사용.
기존 `iOSApp/Features/Match/Score/MatchViewModel.swift` 를 `ScoreTabView` 에서 그대로 사용한다.

## 범위 밖

- 결과 화면(`MatchResultView`) — 별도 스펙으로 분리
- WatchConnectivity 메트릭 송신 프로토콜 — Watch 쪽 별도 작업
