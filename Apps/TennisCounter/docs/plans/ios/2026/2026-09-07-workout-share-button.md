# iOS 워크아웃 공유 버튼 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 저장된 경기의 워크아웃 결과를 YJKit `WorkoutShareUI` 로 인스타그램 스토리에 공유하는 버튼을 iOS 기록 상세 시트와 경기 결과 화면에 붙인다.

**Architecture:** `Match`(SwiftData) 에 이미 저장된 **워크아웃 누적값** 3개(`workoutElapsedSeconds`·`workoutCaloriesBurned`·`workoutTotalCaloriesBurned`)와 `averageHeartRate` 를 `WorkoutResult` 로 변환하는 계산 프로퍼티를 하나 두고, 그 값을 앱 전역 컴포넌트 `MatchShareButton` 이 `WorkoutShareButton` 에 넘긴다. 결과 화면은 **저장이 성공한 뒤에만** 버튼을 드러내므로 두 화면이 같은 `Match` 를 같은 경로로 공유한다 — 카드 숫자와 기록 탭 숫자가 갈릴 여지가 없다.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData + CloudKit / Swift Testing / YJKit `WorkoutShareUI` + `WorkoutCore`(로컬 SPM)

**Spec:** 별도 스펙 없음 — 2026-09-07 대화에서 확정한 설계를 이 문서 §결정 사항에 옮겨 적었다. Kit 계약은 [Packages/YJKit/README.md §WorkoutShareUI 사용법](../../../../../../Packages/YJKit/README.md) 을 따른다.

## 결정 사항 (2026-09-07)

| 논점 | 결정 | 이유 |
|---|---|---|
| 버튼 위치 | 기록 상세 `MatchDetailSheet` **와** 결과 `MatchResultView` 둘 다 | 컴포넌트 하나를 재사용하므로 비용 차이 없음. 상세는 진입 폭, 결과는 감정 타이밍 |
| 결과 화면 노출 시점 | **저장 성공 후에만** (B-1) | 카드 숫자 = 기록 탭 숫자. 저장 전 라이브 `metrics` 로 조립하면 저장 시 계산값과 어긋날 수 있다 |
| 카드 숫자 기준 | **워크아웃 누적값** (`workout*` 필드) | 공유 카드는 "오늘 테니스 1시간 20분 500kcal" 라는 **운동 세션 단위** 자랑이다. 경기 구간값이 아니다. Kit 계약(`WorkoutUI` 와 같은 규칙)과도 일치 |
| 누적값이 nil 인 기록 | 버튼 **숨김** | 누적값 도입(1.1.6) 전 기록. `--` 를 찍는 대신 행을 빼는 Kit 철학과 같다 |
| Meta App ID | 상수로 두고 **지금은 빈 문자열** | 빈 문자열이면 Kit 이 딥링크를 만들지 않고 공유 시트로 폴백한다. 발급 후 한 줄만 바꾼다 |

## Global Constraints

- **YJKit 은 수정하지 않는다.** 모든 변경은 `Apps/TennisCounter/` 안에서 끝난다.
- `WorkoutShareUI` 는 소스 전체가 `#if os(iOS)` 다. **워치 타깃에 링크하거나 import 하지 않는다.**
- SwiftData + CloudKit: `@Model` 에 **저장 속성을 추가하지 않는다.** 이 계획은 계산 프로퍼티만 더한다.
- 테스트 프레임워크는 **Swift Testing** (`@Test`, `#expect`). XCTest 금지. ViewModel 테스트는 `@MainActor`.
- SwiftLint: line length 경고 150 / 오류 200. SwiftFormat: 4-space indent, **imports 알파벳순**, trailing comma.
- 한 파일 = 한 타입. Swift 파일 생성은 파일시스템 조작만으로 충분하다 (`PBXFileSystemSynchronizedRootGroup`).
- 커밋 메시지는 gitmoji prefix (`✨` 기능, `✅` 테스트, `🔧` 설정). 브랜치는 **`feat/ralli`**, 메인 체크아웃에서 작업한다 (워크트리 없음).
- 각 태스크는 **실패하는 테스트 → 실패 확인 → 최소 구현 → 통과 확인 → 커밋** 순서다. 뷰만 바뀌는 태스크는 빌드 + 프리뷰로 확인한다.

**빌드·테스트 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')

# iOS 빌드
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build

# iOS 테스트 전체
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test

# 단일 테스트 파일
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:iosTests/MatchWorkoutResultTests test

# 린트·포맷 검사
make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `TennisCounter.xcodeproj/project.pbxproj` | 수정 (Xcode UI) | iOS 앱 타깃에 `WorkoutShareUI` 프로덕트 링크 |
| `TennisCounter-Info.plist` | 수정 | `LSApplicationQueriesSchemes` 배열 키 |
| `Shared/Persistence/Match.swift` | 수정 | `workoutResult: WorkoutResult?` 계산 프로퍼티 |
| `iosTests/Shared/MatchWorkoutResultTests.swift` | 생성 | 변환 규칙 테스트 |
| `iOSApp/Components/MatchShareButton.swift` | 생성 | Ralli 스타일·App ID 를 박은 `WorkoutShareButton` 래퍼. 두 Feature 가 쓰므로 앱 루트 `Components/` |
| `iOSApp/Features/History/Components/MatchDetailSheet.swift` | 수정 | 하단 섹션에 버튼 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | `saveCurrentMatch() -> Bool` → `-> Match?` |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 수정 | 반환 타입 변경에 맞춘 단언 2곳 |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | 수정 | 저장된 `Match` 를 보관, `.saved` 일 때 버튼 |

---

### Task 1: 타깃 설정 — 프로덕트 링크와 URL 스킴 등록

**Files:**
- Modify: `Apps/TennisCounter/TennisCounter.xcodeproj/project.pbxproj` (Xcode UI 로)
- Modify: `Apps/TennisCounter/TennisCounter-Info.plist`

**Interfaces:**
- Produces: iOS 앱 타깃에서 `import WorkoutShareUI` 가 컴파일된다. 앱이 `instagram-stories://` 스킴을 열 수 있는지 조회할 수 있다.

- [ ] **Step 1: Xcode 에서 프로덕트 링크**

`YJApps.xcworkspace` 를 열고 TennisCounter 프로젝트 → **`TennisCounter` 타깃(iOS 앱)** → General → Frameworks, Libraries, and Embedded Content → `+` → `YJKit` 패키지의 **`WorkoutShareUI`** 선택.

워치 타깃(`TennisCounter Watch App`)에는 추가하지 않는다 — `#if os(iOS)` 라 빈 모듈이 되고, 링크만 늘어난다.

- [ ] **Step 2: 링크 결과 확인**

Run:
```bash
grep -c "WorkoutShareUI" Apps/TennisCounter/TennisCounter.xcodeproj/project.pbxproj
```
Expected: `4` 이상 (PBXBuildFile / Frameworks build phase / packageProductDependencies / XCSwiftPackageProductDependency 각 1). HaruchiFit 의 pbxproj 가 같은 모양이니 비교해도 된다.

- [ ] **Step 3: Info.plist 에 스킴 등록**

`Apps/TennisCounter/TennisCounter-Info.plist` 를 아래로 교체한다. 지금 내용은 빈 `<dict/>` 이고, 이 파일은 이미 iOS 앱 타깃의 `INFOPLIST_FILE` 로 연결돼 있다 (`GENERATE_INFOPLIST_FILE = YES` 와 병합됨).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>instagram-stories</string>
	</array>
</dict>
</plist>
```

`INFOPLIST_KEY_LSApplicationQueriesSchemes` 빌드 설정으로는 **안 된다** — Xcode 가 모르는 배열 키는 경고 없이 버려진다 (`docs/superpowers/specs/2026-09-03-xcode-target-conventions.md` §INFOPLIST_KEY 실측).

- [ ] **Step 4: 빌드 + 산출물 plist 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
plutil -p "$(xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')/Info.plist" \
  | grep -A2 LSApplicationQueriesSchemes
```
Expected: `BUILD SUCCEEDED`, 그리고 `"LSApplicationQueriesSchemes" => [ 0 => "instagram-stories" ]`.

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/TennisCounter.xcodeproj/project.pbxproj Apps/TennisCounter/TennisCounter-Info.plist
git commit -m "🔧 iOS 타깃에 WorkoutShareUI 링크 + instagram-stories 스킴 등록"
```

---

### Task 2: `Match.workoutResult` — 누적값을 `WorkoutResult` 로

**Files:**
- Modify: `Apps/TennisCounter/Shared/Persistence/Match.swift`
- Create: `Apps/TennisCounter/iosTests/Shared/MatchWorkoutResultTests.swift`

**Interfaces:**
- Consumes: `WorkoutCore.WorkoutResult.init(durationSeconds:caloriesBurned:averageHeartRate:totalCaloriesBurned:distanceMeters:steps:healthKitUUID:)`
- Produces: `extension Match { var workoutResult: WorkoutResult? }` — Task 3·4·6 이 이 프로퍼티만 본다.

변환 규칙:

| `WorkoutResult` | 출처 | 비고 |
|---|---|---|
| `durationSeconds` | `workoutElapsedSeconds` | nil 이면 전체가 nil |
| `caloriesBurned` | `workoutCaloriesBurned` | nil 이면 전체가 nil |
| `totalCaloriesBurned` | `workoutTotalCaloriesBurned ?? 0` | 총칼로리 도입 전 기록은 0 (Kit 기본값과 같음) |
| `averageHeartRate` | `averageHeartRate` | nil 허용 — Kit 이 행을 뺀다 |
| `distanceMeters`, `steps`, `healthKitUUID` | 기본값 | 테니스는 수집하지 않는다 |

`durationSeconds`·`caloriesBurned`(경기 구간값)는 **쓰지 않는다.** 이 프로퍼티는 워크아웃 세션 단위다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Apps/TennisCounter/iosTests/Shared/MatchWorkoutResultTests.swift`:

```swift
@testable import TennisCounter
import Testing
import WorkoutCore

struct MatchWorkoutResultTests {
    @Test func workoutResultMapsCumulativeFieldsNotMatchSegment() throws {
        let match = Match()
        match.durationSeconds = 1800 // 경기 구간값 — 무시돼야 한다
        match.caloriesBurned = 150
        match.workoutElapsedSeconds = 4800
        match.workoutCaloriesBurned = 500
        match.workoutTotalCaloriesBurned = 620
        match.averageHeartRate = 138

        let result = try #require(match.workoutResult)

        #expect(result.durationSeconds == 4800)
        #expect(result.caloriesBurned == 500)
        #expect(result.totalCaloriesBurned == 620)
        #expect(result.averageHeartRate == 138)
        #expect(result.distanceMeters == 0)
        #expect(result.steps == 0)
        #expect(result.healthKitUUID == nil)
    }

    @Test func workoutResultIsNilWhenElapsedMissing() {
        let match = Match()
        match.workoutCaloriesBurned = 500
        match.averageHeartRate = 138

        #expect(match.workoutResult == nil)
    }

    @Test func workoutResultIsNilWhenCaloriesMissing() {
        let match = Match()
        match.workoutElapsedSeconds = 4800
        match.averageHeartRate = 138

        #expect(match.workoutResult == nil)
    }

    @Test func workoutResultDefaultsTotalCaloriesToZeroAndKeepsNilHeartRate() {
        let match = Match()
        match.workoutElapsedSeconds = 4800
        match.workoutCaloriesBurned = 500
        // workoutTotalCaloriesBurned, averageHeartRate 는 nil

        let result = match.workoutResult

        #expect(result?.totalCaloriesBurned == 0)
        #expect(result?.averageHeartRate == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:iosTests/MatchWorkoutResultTests test 2>&1 | grep -E "error:|Test Suite|passed|failed" | head
```
Expected: 컴파일 에러 `value of type 'Match' has no member 'workoutResult'`.

- [ ] **Step 3: 최소 구현**

`Apps/TennisCounter/Shared/Persistence/Match.swift` — 파일 상단 import 에 `WorkoutCore` 를 알파벳순으로 넣고, 클래스 닫는 중괄호 뒤에 extension 을 추가한다.

```swift
import Foundation
import SwiftData
import WorkoutCore
```

```swift
extension Match {
    /// 공유 카드용 워크아웃 결과. **워크아웃 누적값** 기준이다 — 카드는 경기 한 판이 아니라
    /// 운동 세션을 자랑하는 용도라서, 경기 구간값(`durationSeconds`·`caloriesBurned`)은 쓰지 않는다.
    /// 누적값 도입(1.1.6) 전 기록은 nil 이므로 호출부가 버튼을 숨긴다.
    var workoutResult: WorkoutResult? {
        guard let elapsed = workoutElapsedSeconds,
              let calories = workoutCaloriesBurned
        else { return nil }
        return WorkoutResult(
            durationSeconds: elapsed,
            caloriesBurned: calories,
            averageHeartRate: averageHeartRate,
            totalCaloriesBurned: workoutTotalCaloriesBurned ?? 0
        )
    }
}
```

`Shared/` 는 워치 타깃도 컴파일하지만 `WorkoutCore` 는 워치에도 링크돼 있어 문제없다. `WorkoutShareUI` 를 여기서 import 하면 안 된다.

- [ ] **Step 4: 통과 확인**

Run: Step 2 와 같은 명령.
Expected: `Test Suite 'MatchWorkoutResultTests' passed`, 4 tests passed.

- [ ] **Step 5: 린트·포맷**

Run: `make lint && make format`
Expected: 경고·오류 0.

- [ ] **Step 6: Commit**

```bash
git add Apps/TennisCounter/Shared/Persistence/Match.swift Apps/TennisCounter/iosTests/Shared/MatchWorkoutResultTests.swift
git commit -m "✨ Match.workoutResult — 워크아웃 누적값을 공유용 WorkoutResult 로 변환"
```

---

### Task 3: `MatchShareButton` — Ralli 스타일을 박은 래퍼

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Components/MatchShareButton.swift`

**Interfaces:**
- Consumes: `Match.workoutResult` (Task 2), `WorkoutShareUI.WorkoutShareButton(result:style:instagramAppID:)`, `WorkoutShareStyle(accentColor:logo:)`, `Color.brand` (`iOSApp/BrandColor.swift`), 에셋 `RalliIcon`
- Produces: `struct MatchShareButton: View { init(match: Match) }` — `workoutResult` 가 nil 이면 `EmptyView` 를 그린다.

- [ ] **Step 1: 컴포넌트 작성**

```swift
import SwiftUI
import WorkoutShareUI

/// 저장된 경기의 워크아웃 결과를 인스타그램 스토리로 공유한다.
/// 누적값이 없는 구버전 기록은 버튼 자체를 그리지 않는다 — Kit 이 값 없는 지표 행을 빼는 것과 같은 규칙.
struct MatchShareButton: View {
    let match: Match

    /// Meta 개발자 대시보드에서 발급한 Facebook App ID. 빈 문자열이면 Kit 이 딥링크를 만들지 않고
    /// iOS 공유 시트로 폴백한다. 발급 후 이 값만 바꾼다.
    private static let instagramAppID = ""

    var body: some View {
        if let result = match.workoutResult {
            WorkoutShareButton(
                result: result,
                style: WorkoutShareStyle(accentColor: .brand, logo: Image("RalliIcon")),
                instagramAppID: Self.instagramAppID
            )
        }
    }
}

#Preview("누적값 있음") {
    let match = Match()
    match.workoutElapsedSeconds = 4800
    match.workoutCaloriesBurned = 500
    match.workoutTotalCaloriesBurned = 620
    match.averageHeartRate = 138
    return MatchShareButton(match: match).padding()
}

#Preview("구버전 기록 — 숨김") {
    let match = Match()
    match.durationSeconds = 1800
    return MatchShareButton(match: match).padding()
}
```

- [ ] **Step 2: 빌드 + 프리뷰 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
```
Expected: `BUILD SUCCEEDED`. Xcode 캔버스에서 첫 프리뷰는 버튼이 보이고, 두 번째는 비어 있다.

- [ ] **Step 3: 린트·포맷**

Run: `make lint && make format`
Expected: 경고·오류 0.

- [ ] **Step 4: Commit**

```bash
git add Apps/TennisCounter/iOSApp/Components/MatchShareButton.swift
git commit -m "✨ MatchShareButton — Ralli 스타일로 감싼 WorkoutShareButton"
```

---

### Task 4: 기록 상세 시트에 버튼

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/History/Components/MatchDetailSheet.swift`

**Interfaces:**
- Consumes: `MatchShareButton(match:)` (Task 3)

- [ ] **Step 1: 섹션 추가**

`MatchDetailSheet.body` 의 `List` 안, `match_detail_section_info` 섹션 **뒤**에 아래 섹션을 붙인다.

```swift
                Section {
                    MatchShareButton(match: match)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
```

구버전 기록이면 `MatchShareButton` 이 `EmptyView` 라 빈 섹션이 남는다. `List` 는 내용 없는 `Section` 을 그리지 않으므로 별도 분기가 필요 없다.

- [ ] **Step 2: 프리뷰에 누적값 주입**

파일 상단 `#Preview` 의 `match.averageHeartRate = 132` 다음 줄에 추가한다 — 지금 프리뷰는 경기 구간값만 있어 버튼이 안 보인다.

```swift
    match.workoutElapsedSeconds = 5400
    match.workoutCaloriesBurned = 320
    match.workoutTotalCaloriesBurned = 410
```

- [ ] **Step 3: 빌드 + 프리뷰 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
```
Expected: `BUILD SUCCEEDED`. 프리뷰 맨 아래에 공유 버튼이 보인다.

- [ ] **Step 4: Commit**

```bash
git add Apps/TennisCounter/iOSApp/Features/History/Components/MatchDetailSheet.swift
git commit -m "✨ 기록 상세 시트에 워크아웃 공유 버튼 추가"
```

---

### Task 5: `saveCurrentMatch` 가 저장된 `Match` 를 돌려준다

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:227-236`
- Modify: `Apps/TennisCounter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift:107,120`

**Interfaces:**
- Produces: `func saveCurrentMatch() -> Match?` — 성공 시 저장된 인스턴스, 세션 없음·저장 실패 시 nil. Task 6 이 반환값을 보관한다.
- 워치 쪽 `WatchApp/.../WorkoutSessionViewModel.saveCurrentMatch()` 는 **다른 타입의 다른 메서드**(ACK 프로토콜)다. 건드리지 않는다.

- [ ] **Step 1: 기존 테스트의 단언을 새 반환 타입으로 고친다**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`:

107행
```swift
        #expect(vm.saveCurrentMatch() == false) // _currentSession nil이면 guard에서 false 리턴
```
→
```swift
        #expect(vm.saveCurrentMatch() == nil) // _currentSession nil이면 guard에서 nil 리턴
```

120행
```swift
        #expect(vm.saveCurrentMatch() == true)
```
→
```swift
        let saved = try #require(vm.saveCurrentMatch())
        #expect(saved.isCompleted)
```

(120행이 속한 테스트 `saveCurrentMatchReturnsTrueOnSuccess` 는 이미 `throws` 다. 이름은 `saveCurrentMatchReturnsMatchOnSuccess` 로 바꾼다.)

- [ ] **Step 2: 실패 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:iosTests/WorkoutSessionViewModelTests test 2>&1 | grep -E "error:" | head
```
Expected: 컴파일 에러 — `Bool` 과 `nil` 비교 불가 / `#require` 에 `Bool` 전달 불가.

- [ ] **Step 3: 반환 타입 변경**

`WorkoutSessionViewModel.swift` 227–236행:

```swift
    /// 저장에 성공하면 저장된 `Match` 를 돌려준다. 결과 화면이 이 인스턴스로 공유 버튼을 켠다.
    /// 세션이 없거나 upsert 가 실패하면 nil.
    func saveCurrentMatch() -> Match? {
        guard let session = _currentSession else { return nil }
        let match = buildMatchFromSession(session)
        do {
            try MatchPersistenceService.shared.upsert(match)
            return match
        } catch {
            return nil
        }
    }
```

이 시점에 `MatchResultView.swift:80` 이 `Bool` 을 기대해 컴파일이 깨진다 — Task 6 에서 고친다. **테스트만 먼저 통과시키려면** 그 줄을 임시로 `viewModel.saveCurrentMatch() != nil ? .saved : .failed` 로 바꿔 둔다.

- [ ] **Step 4: 통과 확인**

Run: Step 2 와 같은 명령, `grep -E "passed|failed"`.
Expected: `WorkoutSessionViewModelTests` 전부 passed.

- [ ] **Step 5: Commit** (Task 6 과 묶어도 된다 — 뷰 임시 수정이 섞이면 여기서 커밋하지 말고 Task 6 끝에서 한 번에)

```bash
git add Apps/TennisCounter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift \
        Apps/TennisCounter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "♻️ saveCurrentMatch 가 저장된 Match 를 반환한다"
```

---

### Task 6: 결과 화면 — 저장 후에만 공유 버튼

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/Match/Result/MatchResultView.swift`

**Interfaces:**
- Consumes: `saveCurrentMatch() -> Match?` (Task 5), `MatchShareButton(match:)` (Task 3)

- [ ] **Step 1: 저장된 Match 보관 + 버튼 노출**

`@State private var saveState` 아래에 상태를 하나 더 둔다:

```swift
    @State private var saveState: SaveButtonState = .idle
    /// 저장에 성공한 인스턴스. 공유 버튼은 이 값이 생긴 뒤에만 나타난다 — 카드 숫자가 기록 탭과 같아야 한다.
    @State private var savedMatch: Match?
```

`saveMatch()` 를 교체한다:

```swift
    private func saveMatch() {
        let match = viewModel.saveCurrentMatch()
        withAnimation {
            savedMatch = match
            saveState = match == nil ? .failed : .saved
        }
    }
```

`Spacer()` 와 `HStack(spacing: 16) { SaveButton ... }` 사이에 버튼을 넣는다:

```swift
                Spacer()

                if let savedMatch {
                    MatchShareButton(match: savedMatch)
                        .padding(.horizontal, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 16) {
```

- [ ] **Step 2: 빌드 확인**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 전체 테스트 + 린트**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | grep -E "Test Suite .* (passed|failed)" | tail -3
make lint && make format
```
Expected: 전부 passed, 린트 0.

- [ ] **Step 4: 시뮬레이터 동작 확인**

시뮬레이터에서 경기 한 판을 끝내고 결과 화면에서:
1. 저장 전 — 공유 버튼 없음
2. 저장 탭 → `저장됨` 과 함께 공유 버튼이 아래에서 올라옴
3. 공유 탭 → 시뮬레이터엔 인스타가 없으니 **iOS 공유 시트**가 뜨고, 미리보기 이미지에 시간·kcal·bpm 카드가 보임

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/iOSApp/Features/Match/Result/MatchResultView.swift
git commit -m "✨ 경기 결과 화면에 저장 후 공유 버튼 노출"
```

---

### Task 7: 실기기 확인 (사람이 한다)

시뮬레이터로는 딥링크 경로를 검증할 수 없다. 아래는 코드가 아니라 체크리스트다.

- [ ] **인스타그램이 설치된 실기기**에서 기록 상세 → 공유 탭 → **인스타그램 스토리 편집기**가 열리고 카드 스티커가 올라오는지 확인. 공유 시트가 뜨면 Task 1 Step 3 의 스킴 등록이 산출물에 안 들어간 것이다 (`plutil` 검증 재실행).
- [ ] 단, `instagramAppID` 가 빈 문자열인 동안은 **의도적으로 공유 시트 폴백**이다. Meta App ID 발급 후 `MatchShareButton.instagramAppID` 를 채우고 다시 확인한다.
- [ ] Meta App ID 발급: [developers.facebook.com](https://developers.facebook.com) → 앱 만들기 → 앱 ID 복사. Ralli 번들 ID 를 iOS 플랫폼으로 등록한다.

---

## Self-Review

**결정 사항 커버리지**
- 두 화면 → Task 4, 6 ✅
- 저장 후에만 → Task 5(반환값) + Task 6(`savedMatch` 가드) ✅
- 누적값 기준 → Task 2 변환 규칙 + 테스트 `workoutResultMapsCumulativeFieldsNotMatchSegment` ✅
- nil 이면 숨김 → Task 2 guard + Task 3 `if let` ✅
- 빈 App ID → Task 3 상수, Task 7 후속 ✅
- Kit 소비자 책임 3항목(README) → 스킴 등록 Task 1, App ID Task 3/7, 누적값 Task 2 ✅

**타입 일관성**
- `Match.workoutResult: WorkoutResult?` — Task 2 정의, Task 3 소비 ✅
- `MatchShareButton(match: Match)` — Task 3 정의, Task 4·6 소비 ✅
- `saveCurrentMatch() -> Match?` — Task 5 정의, Task 6 소비, 테스트 2곳 갱신 ✅

**플레이스홀더 없음** — 모든 코드 스텝에 실제 코드가 있다.
