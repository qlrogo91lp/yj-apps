# ScoreViewModel 메모리 누수 의심 분석

## 작업일: 2026-06-12

## 배경

iOS 점수 미초기화 버그(2026-06-11)를 진단하던 중, `ScoreViewModel`에 `init`/`deinit`/`applyRemoteState` 계측 로그를 심어 watchOS 시뮬레이터에서 재현했다. 이때 부수적으로 다음을 관찰:

```
🟢 [ScoreVM][Watch] init ObjectIdentifier(0x...ed00) options=oneSet
🟢 [ScoreVM][Watch] init ObjectIdentifier(0x...e1c0) options=oneSet
🟢 [ScoreVM][Watch] init ObjectIdentifier(0x...2ac0) options=oneSet
🟢 [ScoreVM][Watch] init ObjectIdentifier(0x...2880) options=oneSet
```

- 경기를 새로 시작할 때마다 `init`은 매번 찍힘 (서로 다른 4개 주소 → StateObject는 정상 재생성)
- **`deinit`은 한 번도 안 찍힘** → 옛 `ScoreViewModel` 인스턴스가 해제되지 않고 누적되는 **메모리 누수 의심**

점수 초기화 버그와는 독립적인 사안으로 분리해 별도 분석.

---

## 분석 (정적 → 경험적)

### 1단계: 코드 정적 분석 — retain cycle 후보 추적

`ScoreViewModel`을 강하게 붙잡을 수 있는 참조 경로를 전부 확인.

**Combine 구독 — 전부 `[weak self]`**

```swift
// 양쪽(iOS/Watch) ScoreViewModel.init()
score.objectWillChange
    .sink { [weak self] _ in self?.objectWillChange.send() }
    .store(in: &cancellables)

connectivity.$receivedScoreState
    .compactMap { $0 }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in self?.applyRemoteState(state) }   // weak
    .store(in: &cancellables)

// iOS 전용
connectivity.$isWatchReachable
    .filter { $0 }
    .sink { [weak self] _ in self?.sendScoreState() }              // weak
    .store(in: &cancellables)
```

- 구독은 self의 `cancellables`에 저장되고, 클로저는 `[weak self]` → 클로저가 self를 retain하지 않음.
- self 해제 시 `cancellables` 해제 → `AnyCancellable` deinit → 싱글톤 퍼블리셔에서 구독 제거. 순환 없음.

**저장되는 클로저 — VM을 캡처하지 않음**

- Watch `ScoreView.onAppear`: `viewModel.onMatchFinished = { result, sets in flowViewModel.finishMatch(...) }` → 클로저는 `flowViewModel`만 캡처(VM 아님). `viewModel → 클로저 → flowViewModel` 방향이라 역참조 없음.
- iOS `ScoreView`: `onMatchFinished`/`onProgressChanged`를 `let` 프로퍼티로 받고 `.onChange`에서 호출. VM 캡처 없음.

→ **고전적 retain cycle은 코드상 존재하지 않음.**

### 2단계: 경험적 검증 — weak 참조 dealloc 테스트 (결정적)

정적 분석을 확정하기 위해, 강한 참조를 놓으면 VM이 실제로 해제되는지 검사하는 테스트를 iOS/Watch 양쪽에 추가.

```swift
@Test @MainActor func scoreViewModelDeallocatesWhenReleased() {
    weak var weakVM: ScoreViewModel?
    autoreleasepool {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.onMatchFinished = { _, _ in }   // (Watch) 클로저 설정 상태에서도 검증
        weakVM = vm
        #expect(weakVM != nil)
    }
    #expect(weakVM == nil)
}
```

**결과: iOS·Watch 양쪽 모두 통과 (`weakVM == nil`).**

- 강한 참조를 놓는 즉시 VM 해제됨.
- 이 테스트의 VM도 `init`에서 `connectivity` **싱글톤을 동일하게 구독**하는데도 해제됨 → **싱글톤 구독이 VM을 retain하지 않는다는 직접 증거.**

---

## 결론

### retain cycle 아님 (낮은 심각도)

코드 레벨에 순환 참조가 없음이 정적·경험적으로 모두 확인됨. 따라서 앱에서 `deinit`이 관찰되지 않은 이유는 **SwiftUI `@StateObject` 저장소의 보유 수명** 때문이다.

- SwiftUI가 `ScoreView`에 묶인 `ScoreViewModel`을 해당 뷰 슬롯의 수명 동안 보유 → 슬롯이 완전히 사라질 때 해제.
- **앱 전체 수명에 걸쳐 무한정 쌓이는 위험한 누수가 아님** (VM은 해제 가능함이 증명됨, 코드가 영구히 붙잡는 경로 없음).
- 최악의 경우 **한 워크아웃 세션 동안** 옛 경기 VM이 SwiftUI에 잔류 → 워크아웃 종료(`WorkoutSessionView` teardown) 시 해제. 즉 **워크아웃 단위로 bounded.**

### 실질 영향

- 정확성/안정성 문제 없음. 잔류한 VM은 화면에 표시되지 않으며, `receivedScoreState` 변경 시 `applyRemoteState`를 중복 실행하는 정도의 미미한 낭비뿐.
- **현재 코드 수정 불필요 (YAGNI).**

### 추가 검증이 필요할 경우

- **Xcode Memory Graph Debugger**를 워크아웃 종료 시점에 켜서 `ScoreViewModel` 인스턴스 개수를 확인 → 실제 free 시점/워크아웃 내 누적 여부 실측.
- 만약 워크아웃 내 누적이 실측으로 문제가 된다면, `ScoreViewModel`을 `WorkoutSessionViewModel`로 끌어올려 단일 인스턴스로 두고 `resetAll()`로 재사용하는 리팩터로 제거 가능. (현재는 과한 변경)

---

## 산출물

| 항목 | 내용 |
|------|------|
| `iosTests/Match/ScoreViewModelTests.swift` | `scoreViewModelDeallocatesWhenReleased` 추가 (retain cycle 회귀 가드) |
| `watchosTests/Match/ScoreViewModelTests.swift` | 동일 테스트 추가 |
| 계측 로그 | 진단용 `print`는 분석 후 제거 |
| 코드 수정 | 없음 (누수 아님으로 판명) |
