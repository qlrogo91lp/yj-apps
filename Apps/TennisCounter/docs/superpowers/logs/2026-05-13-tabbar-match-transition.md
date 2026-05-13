# iOS 탭바 매치 화면 전환 개선

## 작업일: 2026-05-13

## 문제

`HomeView`에서 "운동 시작" 버튼을 눌러 `MatchSessionView`로 이동할 때 하단 탭바가 사라지면서 레이아웃이 부자연스럽게 재조정되는 현상.

### 원인

기존 구조는 `NavigationLink`로 `MatchSessionView`를 push하면서 `.toolbar(.hidden, for: .tabBar)`로 탭바를 숨겼다.

```swift
// HomeView.swift (기존)
NavigationLink {
    MatchSessionView()
        .toolbar(.hidden, for: .tabBar)
} label: { ... }
```

SwiftUI의 preference 시스템으로 자식 뷰가 부모 `TabView`의 탭바를 숨기는 방식인데, 이 숨김 애니메이션이 NavigationLink push 애니메이션과 따로 동작하면서 콘텐츠 영역이 갑자기 확장되는 레이아웃 점프가 발생했다.

### 시도한 해결 방법들

1. **bottom padding 조정** (`32pt` → `81pt`): 탭바 높이(49pt) 만큼 버튼 위치를 미리 올려 점프폭을 줄이는 근사치 방식. 디바이스별 편차 문제로 완벽하지 않음.

2. **ZStack으로 버튼 고정**: 컨테이너 크기 자체가 바뀌므로 근본 해결 안 됨.

3. **`fullScreenCover`**: 탭바를 덮어 레이아웃 변화 없이 모달로 표시. 구현은 간단하지만 슬라이드업/다운 제스처가 기존 push 방식과 달라 어색한 느낌.

## 최종 해결 방법

`MainTabView`에 `isMatchActive` 상태를 두고, 매치 진입 시 탭바를 숨기는 대신 **탭 구성을 전환**하는 방식으로 변경.

- `TabView`는 ZStack에서 항상 렌더링 상태 유지 (숨기기/보이기 없음)
- 매치 활성 시 `NavigationStack { MatchSessionView }` 가 TabView 위에 오버레이
- 매치 종료 시 NavigationStack이 fade out되면서 이미 렌더링된 TabView가 드러남

```
[평상시]  ZStack: TabView(Summary | Match | History)
[매치중]  ZStack: TabView(hidden 상태) + NavigationStack{ MatchSessionView(Workout | Match) }
```

### 수정 파일

**`iOSApp/iOSApp.swift`** — `MainTabView` 재구성

```swift
struct MainTabView: View {
    @State private var isMatchActive = false
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) { ... }  // 항상 렌더링

            if isMatchActive {
                NavigationStack {
                    MatchSessionView(onExit: {
                        selectedTab = 1           // Match 탭으로 복귀
                        withAnimation { isMatchActive = false }
                    })
                }
                .transition(.opacity)
            }
        }
    }
}
```

**`iOSApp/Features/Match/Home/HomeView.swift`** — NavigationLink 제거, 콜백 방식으로 전환

```swift
struct HomeView: View {
    let onMatchStart: () -> Void
    // NavigationLink → Button + onMatchStart() 호출
}
```

**`iOSApp/Features/Match/Session/MatchSessionView.swift`** — dismiss 대신 onExit 콜백

```swift
struct MatchSessionView: View {
    let onExit: () -> Void
    // @Environment(\.dismiss) 제거
    // dismiss() → onExit() 로 교체
    // modeSelection phase 뒤로가기도 onExit() 호출
}
```

### 추가로 발견한 문제들

1. **탭 복귀 버그**: `isMatchActive = false` 시 TabView가 항상 첫 번째 탭(Summary)으로 돌아가는 문제  
   → `TabView(selection: $selectedTab)`에 tag 추가, onExit에서 `selectedTab = 1` 먼저 세팅

2. **흰 화면 깜빡임**: `if/else`로 TabView를 조건부 렌더링했을 때 TabView 재초기화 시 잠깐 흰 화면이 보이는 문제  
   → TabView를 항상 렌더링하고 NavigationStack만 조건부로 올리는 구조로 변경해 해결

## 핵심 교훈

탭바를 숨기는 방식보다 탭 구성 자체를 전환하는 방식이 더 자연스럽다. 특히 `MatchSessionView`처럼 자체 TabView를 가진 경우, 기존 TabView를 살려둔 채 오버레이하면 재초기화 없이 부드러운 전환이 가능하다.
