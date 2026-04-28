# MVVM 전환 후 중첩 ObservableObject 버그 수정

## 작업일: 2026-02-13

## 문제

MVVM 패턴으로 리팩토링 후, 워치앱에서 Undo 버튼이 표시되지 않는 현상 발생.

### 원인

SwiftUI의 **중첩 ObservableObject 변경 전파 미지원** 문제.

- `MatchViewModel`이 `@Published var score = Score()`로 `Score` 객체를 소유
- `Score`는 class(참조 타입)이므로, 내부 프로퍼티(`lastAction`, `myScore`, `yourScore`)가 변해도 `MatchViewModel.objectWillChange`가 발행되지 않음
- View에서 `viewModel.score.lastAction != .none` 조건으로 Undo 버튼을 표시하지만, 변경이 감지되지 않아 항상 숨겨진 상태

## 수정 내용

### 수정 파일
- `WatchApp/Screens/Match/MatchViewModel.swift`
- `iOSApp/Screens/Match/MatchViewModel.swift`

### 변경 내용

양쪽 ViewModel에 Combine을 사용한 변경 전파 로직 추가:

```swift
import Combine

class MatchViewModel: ObservableObject {
    @Published var score = Score()

    private var cancellable: AnyCancellable?

    init() {
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
```

`score.objectWillChange` → `self.objectWillChange`로 전파하여, `Score` 내부 프로퍼티 변경 시 View가 정상적으로 업데이트되도록 수정.

## 검증

- Watch 앱 빌드: BUILD SUCCEEDED
- iOS 앱 빌드: BUILD SUCCEEDED
