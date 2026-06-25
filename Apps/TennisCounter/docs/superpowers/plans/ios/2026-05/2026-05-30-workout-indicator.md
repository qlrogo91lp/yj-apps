# WorkoutIndicator 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운동 세션이 진행 중임을 iOS 경기 화면 상단 중앙에서 항상 인지할 수 있도록 회전 앱 아이콘 + 경과 시간 인디케이터를 추가한다.

**Architecture:** `WorkoutSessionView` 툴바 `.principal` 위치에 `WorkoutIndicator` 컴포넌트를 조건부로 표시한다. `modeSelection` phase에서는 기존 "새 경기" 제목을 유지하고, `playing` / `finished` phase에서 인디케이터로 교체한다. 기존 View 레이아웃은 전혀 변경하지 않는다.

**Tech Stack:** SwiftUI, `@State` + `withAnimation(.linear.repeatForever())` 회전 애니메이션

---

## 파일 맵

| 작업 | 파일 |
|------|------|
| 신규 생성 | `iOSApp/Features/WorkoutSession/Components/WorkoutIndicator.swift` |
| 수정 | `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` (55-62번째 줄 툴바 principal) |

> `Components/` 폴더는 신규 생성. `PBXFileSystemSynchronizedRootGroup` 방식이므로 파일만 만들면 Xcode가 자동으로 빌드 대상에 포함한다.

---

### Task 1: WorkoutIndicator 컴포넌트 생성

**Files:**
- Create: `iOSApp/Features/WorkoutSession/Components/WorkoutIndicator.swift`

- [ ] **Step 1: 파일 생성**

```swift
import SwiftUI

struct WorkoutIndicator: View {
    let elapsedFormatted: String

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            Image("AppIcon")
                .resizable()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text(elapsedFormatted)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.white)
        }
    }
}

#Preview {
    WorkoutIndicator(elapsedFormatted: "23:45")
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

기대 결과: `BUILD SUCCEEDED` (error 없음)

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/Components/WorkoutIndicator.swift
git commit -m "feat: add WorkoutIndicator component with rotating app icon"
```

---

### Task 2: WorkoutSessionView 툴바 연결

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`

현재 55-62번째 줄:
```swift
ToolbarItem(placement: .principal) {
    if case .modeSelection = viewModel.phase {
        Text(String(localized: "new_match"))
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)
    }
}
```

- [ ] **Step 1: 툴바 principal 수정**

위 코드를 아래로 교체한다:

```swift
ToolbarItem(placement: .principal) {
    switch viewModel.phase {
    case .modeSelection:
        Text(String(localized: "new_match"))
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)
    case .playing, .finished:
        WorkoutIndicator(elapsedFormatted: viewModel.metrics.formattedElapsed)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

기대 결과: `BUILD SUCCEEDED`

- [ ] **Step 3: 동작 수동 확인**

시뮬레이터에서 앱을 실행하고 운동 세션을 시작한 뒤 아래 항목을 확인한다:

1. `modeSelection` 화면 — 상단 중앙에 "새 경기" 제목이 보인다
2. 포맷 선택 후 `playing` 화면 — 앱 아이콘이 회전하며 경과 시간이 표시된다
3. 경기 종료 후 `finished` 화면 — 인디케이터가 계속 표시된다
4. 기존 BackButton, 언두 버튼, 점수 영역 등 레이아웃이 정상이다

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "feat: show WorkoutIndicator in toolbar during playing and finished phases"
```
