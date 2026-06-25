# Launch Screen (Splash Screen) 구현 계획

**날짜:** 2026-05-13
**대상 타겟:** iOS (`iOSApp`)

---

## 개요

앱 기동 시 `MainTabView` 진입 전에 짧게 표시되는 SwiftUI 기반 Splash Screen을 추가한다. 디자인은 `LaunchScreenView.swift`에서 직접 작성하며, 전환 제어 로직은 `iOSApp.swift`에서 담당한다.

---

## 파일 구조

```
iOSApp/
├── iOSApp.swift                    ← 분기 로직 추가
└── Features/
    └── Launch/
        └── LaunchScreenView.swift  ← 신규 생성 (디자인 파일)
```

---

## 구현 단계

### Step 1. `LaunchScreenView.swift` 생성

`iOSApp/Features/Launch/LaunchScreenView.swift` 파일을 생성한다.

```swift
import SwiftUI

struct LaunchScreenView: View {
    let onFinished: () -> Void

    var body: some View {
        // 디자인 작성 영역
        // 완료 시 onFinished() 호출
    }
}
```

### Step 2. `iOSApp.swift` 분기 로직 추가

`TennisCounterApp`에 `@State private var isLaunching = true`를 추가하고 `WindowGroup` 내부를 분기한다.

**변경 전:**
```swift
var body: some Scene {
    WindowGroup {
        MainTabView()
    }
    .modelContainer(container)
}
```

**변경 후:**
```swift
@State private var isLaunching = true

var body: some Scene {
    WindowGroup {
        if isLaunching {
            LaunchScreenView(onFinished: { isLaunching = false })
        } else {
            MainTabView()
        }
    }
    .modelContainer(container)
}
```

---

## 범위 제외

- System Launch Screen 변경 없음 — 기존 `UILaunchScreen_Generation = YES` 유지
- Watch 앱 변경 없음

---

## 완료 조건

- [ ] `iOSApp/Features/Launch/LaunchScreenView.swift` 생성됨
- [ ] `iOSApp.swift` 분기 로직 추가됨
- [ ] 앱 기동 시 `LaunchScreenView`가 먼저 표시되고, 이후 `MainTabView`로 전환됨
