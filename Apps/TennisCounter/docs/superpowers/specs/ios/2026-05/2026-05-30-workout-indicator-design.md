# WorkoutIndicator 설계 문서

**날짜**: 2026-05-30  
**대상 타겟**: iOS (`TennisCounter`)  
**상태**: 확정

---

## 배경 및 목표

iOS에서 운동 세션을 시작하면 HealthKit 워크아웃이 백그라운드에서 즉시 실행되지만, 사용자는 경기(Match) 탭에 있는 동안 운동이 진행 중인지 인지하기 어렵다. 운동 탭(탭0)으로 직접 이동해야만 세션 상태를 확인할 수 있다.

**목표**: 경기 화면에서 운동 세션이 활성화된 상태임을 최소한의 UI로 항상 인지할 수 있게 한다.

---

## 설계 결정

### 위치
`WorkoutSessionView` 툴바의 `.principal`(center) 위치에 배치한다.

- 기존 레이아웃(ModeView, ScoreView, MatchResultView)을 전혀 건드리지 않음
- 컨테이너에 한 번만 추가하면 모든 phase에서 자동 표시
- 현재 툴바의 leading(BackButton)과 충돌 없음

### 조건부 표시 (phase별)
| Phase | 툴바 center |
|-------|------------|
| `modeSelection` | 기존 "새 경기" 제목 유지 |
| `playing` | WorkoutIndicator |
| `finished` | WorkoutIndicator |

modeSelection은 포맷 선택 단계로 매우 짧은 순간이며, "새 경기" 제목이 사용자 맥락을 제공하므로 유지한다.

### 인디케이터 구성
- **앱 아이콘**: `Image("AppIcon")` + `.clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))` (소형, ~20pt)
- **애니메이션**: 시계 방향 360° 회전, `repeatForever`, `linear` 이징
- **경과 시간**: `metrics.formattedElapsed` 텍스트, `tabular-nums`로 흔들림 방지
- **인터랙션**: 없음 (인디케이터 역할만, 운동 탭은 탭바에서 이동)

---

## 컴포넌트 설계

### `WorkoutIndicator`
```
iOSApp/Features/WorkoutSession/Components/WorkoutIndicator.swift
```

**Props**
- `elapsedFormatted: String` — `metrics.formattedElapsed` 전달

**내부 구조**
```
HStack(spacing: 5)
├── Image("AppIcon")                     // 앱 아이콘 asset
│   .resizable()
│   .frame(width: 20, height: 20)
│   .clipShape(RoundedRectangle(...))
│   .rotationEffect(rotation)            // @State로 관리
│   .onAppear { startRotation() }
└── Text(elapsedFormatted)
    .font(.system(size: 13, weight: .semibold))
    .monospacedDigit()
```

---

## WorkoutSessionView 변경

`WorkoutSessionView` 툴바의 `.principal` ToolbarItem을 수정한다:

```swift
ToolbarItem(placement: .principal) {
    switch viewModel.phase {
    case .modeSelection:
        Text("새 경기").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
    case .playing, .finished:
        WorkoutIndicator(elapsedFormatted: viewModel.metrics.formattedElapsed)
    }
}
```

---

## 데이터 흐름

```
WorkoutSessionViewModel.metrics.formattedElapsed
    → WorkoutSessionView (toolbar .principal)
        → WorkoutIndicator(elapsedFormatted:)
```

`viewModel.metrics`는 이미 `@Published`로 1초마다 업데이트되고 있으므로 추가 데이터 연결 없이 그대로 사용한다.

---

## 범위 밖

- BPM, 칼로리 등 추가 메트릭 표시 — 운동 탭(탭0)에서 확인
- 인디케이터 탭 인터랙션 — 탭바에서 직접 이동 가능
- Watch 앱 — watchOS는 별도 UI 구조로 해당 없음
