# iOS Feature 구조 리팩토링 설계

## 배경

현재 iOSApp의 Feature 구조가 CLAUDE.md 규칙과 크게 어긋나 있음.

- `iOSApp.swift` 한 파일에 Summary·History 전체 (God file)
- `ModeSelectionView`가 `Match/Score/`에 잘못 배치
- `MatchView.swift`, `CounterButtonView.swift` 레거시 코드 방치
- `matchOverView`가 `ScoreTabView` 인라인 (Watch는 `Result/`로 분리)
- `Session/` 레이어가 Watch 구조와 불일치

## 목표

Watch 앱과 대칭 구조를 맞추고, CLAUDE.md 폴더 규칙(한 파일 = 한 타입, 계층적 컴포넌트 분리)을 준수한다.

## 최종 폴더 구조

```
iOSApp/
├── iOSApp.swift                    # App entry point + MainTabView만 유지
├── Components/                     # 앱 루트 공유 컴포넌트
│   └── MatchDetailSheet.swift      # Summary·History 양쪽 사용 → 승격
├── Features/
│   ├── Summary/
│   │   ├── SummaryView.swift
│   │   ├── SummaryViewModel.swift  # SummaryPeriod, SummaryStats 포함
│   │   └── Components/
│   │       ├── StatCard.swift          # SummaryStatCard 추출
│   │       └── RecentMatchCard.swift   # SummaryRecentMatchCard 추출
│   ├── Match/
│   │   ├── Mode/                       # Watch 대칭 (현재 Score/에 오배치)
│   │   │   ├── ModeView.swift          # ModeSelectionView → 이름 변경
│   │   │   └── Components/             # ModeSelectionViewModel은 삭제 (selectedFormat 미사용)
│   │   │       └── ModeCard.swift      # private ModeCardView → 추출
│   │   ├── Tab/                        # iOS 전용 탭 컨테이너 (Watch의 WorkoutSession/ 대응)
│   │   │   ├── MatchTabView.swift      # MatchContainerView → 이름 변경
│   │   │   └── MatchTabViewModel.swift # MatchContainerViewModel → 이름 변경
│   │   ├── Score/                      # Session/Score/ → 위로 승격
│   │   │   ├── ScoreView.swift         # ScoreTabView → 이름 변경
│   │   │   ├── MatchViewModel.swift    # 현행 유지, 위치 이동
│   │   │   └── Components/
│   │   │       ├── PlayerScoreZone.swift
│   │   │       ├── ScoreOverlay.swift
│   │   │       └── ScoreEditSheet.swift
│   │   ├── Result/                     # Watch 대칭, ScoreTabView.matchOverView → 분리
│   │   │   └── MatchResultView.swift
│   │   └── Workout/                    # Session/Workout/ → 위로 승격
│   │       └── WorkoutTabView.swift
│   └── History/
│       ├── HistoryView.swift
│       ├── HistoryViewModel.swift      # HistoryViewMode 포함
│       └── Components/
│           ├── MatchRow.swift          # MatchRowView → 추출
│           ├── CalendarHistoryView.swift
│           └── DayCell.swift           # DayCellView → 추출
```

## Watch 대칭 비교

| Watch | iOS | 비고 |
|-------|-----|------|
| `Match/Mode/` | `Match/Mode/` | ✓ 대칭 |
| `Match/Score/` | `Match/Score/` | ✓ 대칭 |
| `Match/Result/` | `Match/Result/` | ✓ 대칭 (신규) |
| `WorkoutSession/` | `Match/Tab/` | iOS 전용 탭 컨테이너 |
| — | `Match/Workout/` | iOS 전용 탭 콘텐츠 |

## 삭제 대상

| 파일 | 이유 |
|------|------|
| `Match/Score/MatchView.swift` | 레거시. 네비게이션 흐름에서 미사용 |
| `Match/Score/Components/CounterButtonView.swift` | MatchView에서만 사용, 함께 삭제 |
| `Match/Score/ModeSelectionViewModel.swift` | `selectedFormat` 미사용, 실질적 빈 ViewModel |
| `Match/Session/` 폴더 | Score·Workout 이동 후 빈 폴더 제거 |

## 이름 변경 규칙

- `ModeSelectionView` → `ModeView` (Watch의 `ModeView`와 대칭)
- `ModeCardView` → `ModeCard` (Components 폴더 규칙: suffix 없음)
- `MatchContainerView` → `MatchTabView`
- `MatchContainerViewModel` → `MatchTabViewModel`
- `ScoreTabView` → `ScoreView`
- `SummaryStatCard` → `StatCard`
- `SummaryRecentMatchCard` → `RecentMatchCard`
- `MatchRowView` → `MatchRow`
- `DayCellView` → `DayCell`

## 컴포넌트 분리 원칙

- `iOSApp.swift`에서 Summary·History 전체를 각 Feature 파일로 분리
- `MatchDetailSheet`는 Summary·History 두 Feature가 공유 → `Components/` 루트로 승격
- `matchOverView` (현재 `ScoreTabView` 인라인) → `Match/Result/MatchResultView.swift`로 분리
- `ModeCardView` (현재 `ModeSelectionView` 내 private) → `Mode/Components/ModeCard.swift`로 추출

## 버그 수정 (선행 완료)

아래 항목은 브레인스토밍 중 발견하여 선행 수정됨:

- `ModeSelectionView.navigationDestination`에서 `.toolbar(.hidden, for: .tabBar)` 적용 (외부 탭바 미숨김 버그)
- `ScoreTabView.scoreView`에 `Color.black.ignoresSafeArea()` 추가
- `matchOverView`에 검은 배경 및 수직 중앙 정렬 적용
- `MatchContainerView`에 `.preferredColorScheme(.dark)` 적용 (상태바 흰색 텍스트)
