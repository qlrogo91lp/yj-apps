# common: 로컬라이즈 (ko/en) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한국어로 하드코딩된 세 타깃의 사용자 노출 문자열을 한국어·영어 두 언어로 지원한다.

**Architecture:** tennis-counter와 같은 방식 — `.lproj/Localizable.strings` 파일에 **상징 키**(`home_start_button`)를 두고, 코드에서 `String(localized:)`로 부른다. 영어는 단순 번역이 아니라 공간별 영문 골프 관습을 따른다(iOS는 문장, 워치·컴플리케이션은 축약). 영어 복수형은 `.stringsdict` 없이 문구로 회피한다. 언어에 따라 달라지는 텍스트는 모델·ViewModel에서 View로 옮긴다.

**Tech Stack:** Swift 5(language mode) / SwiftUI / Foundation `String(localized:)` / Swift Testing. 새 의존성 없음.

**참조 spec:** `docs/superpowers/specs/2026-08-17-localization-design.md` — 섹션 번호 참조는 전부 이 문서 기준이다.

**선행 조건:** 없음. plan ⑥([PR #23](https://github.com/qlrogo91lp/golf_counter/pull/23))이 머지되어 통계 탭이 존재해야 문자열이 전부 모인다 — **머지 완료됨** (merge commit `5811dd0`).

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0**
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:`), **main 직접 커밋 금지** — 브랜치 + PR
- 빌드 검증 시뮬레이터: iOS `iPhone 17 Pro`, watch/complication `Apple Watch Series 11 (46mm)`
- `make lint`(swiftlint) / `make format`(swiftformat --lint) **위반 0** — `swiftlint`는 경고에도 exit 0을 내므로 **전체 출력을 읽어 `Found 0 violations`를 확인한다** (plan ⑥에서 이걸 놓쳐 회귀가 통과된 적 있다)
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`, **View는 테스트하지 않는다**
- 호출 패턴은 두 가지로 고정한다 (spec §3):
  - 고정 문자열 → `Text(String(localized: "key"))`
  - 숫자 포함 → `Text(String(format: String(localized: "key"), value))`
- `Int` 자리표시자는 **`%lld`** (`%d` 아님 — 64비트에서 `Int`는 `Int64`)
- `.strings` 파일은 `/* 화면명 */` 주석으로 구획을 나눈다 (tennis 관례)
- **`.stringsdict`를 만들지 않는다** (spec §5) — 영어 복수형이 필요해 보이는 문구는 라벨 형식으로 회피한다
- **`Shared/`에 `.lproj`를 만들지 않는다** (spec §7)
- `knownRegions`에 이미 `en, Base, ko`가 있다. `developmentRegion`은 `en` 그대로 두고 **바꾸지 않는다** (상징 키라 무관)
- 앱 표시명(`CFBundleDisplayName = GolfCounter`)은 **건드리지 않는다** — 이름 교체는 이 plan의 범위 밖 (spec §1)

## 파일 구조

| 파일 | 책임 | Task |
|------|------|------|
| `ComplicationApp/{en,ko}.lproj/Localizable.strings` (신규) | 컴플리케이션 문자열 3개 | 1 |
| `Shared/Models/ComplicationState.swift` (수정) | `strokesText` 제거 | 1 |
| `ComplicationApp/ComplicationApp.swift` (수정) | 문자열 3곳 교체 + 타수 포맷 | 1 |
| `watchosTests/Shared/ComplicationStateTests.swift` (수정) | `strokesText` 단언 삭제 | 1 |
| `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (수정) | §10 형식 결정 정정 | 1 |
| `WatchApp/{en,ko}.lproj/Localizable.strings` (신규) | 워치 문자열 ~22개 | 2 |
| `WatchApp/Features/Home/HomeViewModel.swift` (수정) | `startButtonLabel` 제거 | 2 |
| 워치 View 6개 (수정) | 문자열 교체 | 2 |
| `watchosTests/Home/HomeViewModelTests.swift` (수정) | `startButtonLabel` 단언 삭제 | 2 |
| `watchosTests/Localization/StringsParityTests.swift` (신규) | ko/en 키 집합 일치 검증 | 2 |
| `iOSApp/{en,ko}.lproj/Localizable.strings` (신규) | iOS 문자열 ~28개 (기록) | 3 |
| iOS 기록 View 7개 (수정) | 문자열 교체 | 3 |
| `iosTests/Localization/StringsParityTests.swift` (신규) | ko/en 키 집합 일치 검증 | 3 |
| `iOSApp/{en,ko}.lproj/Localizable.strings` (추가) | iOS 문자열 ~22개 (통계) | 4 |
| iOS 통계 View 3개 (수정) | 문자열 교체 | 4 |
| `iOSApp/{en,ko}.lproj/InfoPlist.strings` (신규) | HealthKit 권한 2개 | 5 |
| `WatchApp/{en,ko}.lproj/InfoPlist.strings` (신규) | HealthKit 권한 2개 | 5 |

## 영어 문구 방침 요약 (spec §4)

| 공간 | 방침 | 예 |
|------|------|-----|
| iOS | 단어·문장 | `평균 타수` → `Avg. Strokes` |
| iOS 스코어카드 행 | 영문 관습 — 타수에 단위 없음 | `5타 · 2퍼트` → `5 · 2p` |
| 워치 | 축약 | `5타(2p)` → `5 (2p)` |
| 컴플리케이션 | 숫자만 | `13타` → `13` |

**ko와 en의 구조가 다른 키에는 `.strings` 주석으로 이유를 남긴다.**

---

### Task 1: 컴플리케이션 타깃 — `.lproj` 인식 검증 겸함

**Files:**
- Create: `ComplicationApp/en.lproj/Localizable.strings`, `ComplicationApp/ko.lproj/Localizable.strings`
- Modify: `Shared/Models/ComplicationState.swift`, `ComplicationApp/ComplicationApp.swift`
- Modify: `watchosTests/Shared/ComplicationStateTests.swift`
- Modify: `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md`

**Interfaces:**
- Consumes: 없음
- Produces: `.lproj`가 동기화 그룹에서 인식된다는 사실 (Task 2~5가 이 위에 선다)

**이 태스크가 spec §10의 리스크를 없앤다.** 이 프로젝트는 `PBXFileSystemSynchronizedRootGroup`을 써서 지금까지 pbxproj를 한 번도 수정하지 않았는데, `.lproj`가 자동으로 로컬라이즈 리소스로 잡히는지는 확인된 바 없다. **가장 작은 타깃(문자열 3개)에서 먼저 확인해, 안 되면 60여 개를 옮기기 전에 알아챈다.**

- [ ] **Step 1: `.lproj` 파일 두 개 생성**

`ComplicationApp/ko.lproj/Localizable.strings`:

```
/* Complication */
"complication_start_round" = "라운드 시작";
"complication_description" = "라운드 진행 상황";

/* 컴플리케이션은 가장 좁은 공간이라 영어는 숫자만 쓴다 (spec §4) */
"complication_strokes" = "%lld타";
```

`ComplicationApp/en.lproj/Localizable.strings`:

```
/* Complication */
"complication_start_round" = "Start Round";
"complication_description" = "Round progress";

/* 컴플리케이션은 가장 좁은 공간이라 영어는 숫자만 쓴다 (spec §4) */
"complication_strokes" = "%lld";
```

- [ ] **Step 2: 문자열 하나만 먼저 교체해 인식 여부 확인**

`ComplicationApp/ComplicationApp.swift:76`을 교체한다.

교체 대상:

```swift
                Text("라운드 시작")
```

새 내용:

```swift
                Text(String(localized: "complication_start_round"))
```

- [ ] **Step 3: 빌드하고 실제로 번역이 걸리는지 확인 — 이 태스크의 핵심 관문**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

그다음 **빌드 산출물에 `.lproj`가 들어갔는지 직접 확인한다.** 빌드만 성공하는 것으로는 부족하다 — `.lproj`가 리소스로 복사되지 않아도 빌드는 성공하고, 런타임에 키가 그대로 화면에 뜬다.

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*ComplicationApp.appex/*.lproj*" -name "Localizable.strings" 2>/dev/null | head
```

Expected: `en.lproj/Localizable.strings`와 `ko.lproj/Localizable.strings` 두 경로가 나온다.

**둘 다 안 나오면 여기서 멈추고 BLOCKED로 보고한다.** pbxproj 수정이 필요하다는 뜻이고, 그건 이 프로젝트에서 예외적인 일이라 진행 방향을 사용자가 다시 정해야 한다. 나머지 Step을 진행하지 말 것.

- [ ] **Step 4: 나머지 문자열 두 곳 교체**

`ComplicationApp/ComplicationApp.swift:99`를 교체한다.

교체 대상:

```swift
        .description("라운드 진행 상황")
```

새 내용:

```swift
        .description(String(localized: "complication_description"))
```

`.configurationDisplayName("GolfCounter")`는 **건드리지 않는다** — 브랜드명이라 두 언어에서 같다.

- [ ] **Step 5: `ComplicationState.strokesText` 제거 (spec §6)**

`Shared/Models/ComplicationState.swift`에서 아래를 통째로 삭제한다:

```swift

    var strokesText: String {
        "\(totalStrokes)타"
    }
```

`holeText`(`"H3"`)와 `relativeToParText`(`"+1"`/`"E"`)는 **그대로 둔다** — 골프 표기라 두 언어에서 같다.

- [ ] **Step 6: 호출부를 View에서 포맷하도록 교체**

`ComplicationApp/ComplicationApp.swift:71`을 교체한다.

교체 대상:

```swift
                    Text(entry.state.strokesText)
```

새 내용:

```swift
                    Text(String(format: String(localized: "complication_strokes"),
                                entry.state.totalStrokes))
```

- [ ] **Step 7: 테스트 단언 삭제**

`watchosTests/Shared/ComplicationStateTests.swift:42`의 아래 한 줄을 삭제한다:

```swift
        #expect(state.strokesText == "13타")
```

같은 테스트의 `holeText`·`relativeToParText` 단언은 **남긴다** — 언어 중립 값이라 로케일과 무관하게 유효하다.

- [ ] **Step 8: 빌드·테스트·lint 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
make lint && make format
```

Expected: 컴플리케이션 `** BUILD SUCCEEDED **`, 워치 `** TEST SUCCEEDED **`, lint 출력에 `Found 0 violations`

- [ ] **Step 9: 리빌드 스펙 §10 정정 (spec §2)**

`docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md`에서 아래 줄을 교체한다.

교체 대상:

```markdown
- **String Catalog(`.xcstrings`)** 기반 ko/en. tennis의 lproj 방식 대신 신규 표준 채택 (Xcode 15+).
```

새 내용:

```markdown
- **`.lproj/Localizable.strings`** 기반 ko/en, 상징 키(`home_start_button`). 초판은 String Catalog(`.xcstrings`)를 채택했으나 2026-08-17에 뒤집었다 — `.xcstrings`를 고른 근거였던 복수형 내장 지원이, 복수형을 문구로 회피하기로 하면서 무의미해졌고, 형제 프로젝트 tennis-counter와 같은 방식으로 관리하는 편이 낫다고 판단했다 (spec `2026-08-17-localization-design.md` §2·§5).
```

- [ ] **Step 10: 커밋**

```bash
make lint && make format
git add ComplicationApp/ Shared/Models/ComplicationState.swift \
        watchosTests/Shared/ComplicationStateTests.swift \
        docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md
git commit -m "✨ feat: 컴플리케이션 로컬라이즈 + .lproj 방식 확정"
```

---

### Task 2: 워치 타깃

**Files:**
- Create: `WatchApp/en.lproj/Localizable.strings`, `WatchApp/ko.lproj/Localizable.strings`
- Create: `watchosTests/Localization/StringsParityTests.swift`
- Modify: `WatchApp/Features/Home/HomeViewModel.swift`, `WatchApp/Features/Home/HomeView.swift`, `WatchApp/Features/Home/Components/HoleCountSelector.swift`, `WatchApp/Features/Round/RoundSessionView.swift`, `WatchApp/Features/Round/ParSelection/ParSelectionView.swift`, `WatchApp/Features/Round/Counting/CountingView.swift`, `WatchApp/Features/Round/Scorecard/ScorecardView.swift`, `WatchApp/Features/Round/Summary/SummaryView.swift`
- Modify: `watchosTests/Home/HomeViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1이 확인한 `.lproj` 인식
- Produces: 없음

- [ ] **Step 1: `.lproj` 파일 두 개 생성**

`WatchApp/ko.lproj/Localizable.strings`:

```
/* Home */
"home_hole_count" = "홀 수";
"home_start_button" = "%lld홀 시작";
"home_pending_title" = "진행 중인 라운드가 있습니다";
"home_pending_message" = "새로 시작하면 지워집니다.";
"home_start_new" = "새로 시작";

/* Common */
"common_cancel" = "취소";

/* Par Selection */
"par_hole_number" = "%lld번 홀";

/* Counting */
"counting_skip_title" = "이 홀은 기록되지 않습니다";
"counting_skip_confirm" = "건너뛰기";

/* Round End */
"round_end_title_recorded" = "%lld홀이 기록됩니다";
"round_end_title_empty" = "기록된 홀이 없습니다";
"round_end_confirm" = "종료";
"round_end_confirm_empty" = "저장 없이 종료";

/* Scorecard — 영문 스코어카드 관습: 타수에 단위를 붙이지 않는다 (spec §4) */
"scorecard_row" = "%lld타(%lldp)";
"scorecard_total" = "합계 %lld타 · %lld퍼트 · %@";

/* Summary */
"summary_holes_completed" = "%lld홀 완료";
"summary_holes_empty" = "기록된 홀 없음";
"summary_strokes_putts" = "%lld타 · %lld퍼트";
"summary_discard_button" = "저장 안 함";
"summary_discard_title" = "이 라운드를 저장하지 않고 버릴까요?";
"summary_discard_confirm" = "버리기";
"summary_transmitting" = "전송 중…";
"summary_save_send" = "저장 & 전송";
```

`WatchApp/en.lproj/Localizable.strings`:

```
/* Home */
"home_hole_count" = "Holes";
"home_start_button" = "Start %lld Holes";
"home_pending_title" = "Round in progress";
"home_pending_message" = "Starting new will discard it.";
"home_start_new" = "Start New";

/* Common */
"common_cancel" = "Cancel";

/* Par Selection */
"par_hole_number" = "Hole %lld";

/* Counting */
"counting_skip_title" = "This hole won't be recorded";
"counting_skip_confirm" = "Skip";

/* Round End */
"round_end_title_recorded" = "%lld holes will be saved";
"round_end_title_empty" = "No holes recorded";
"round_end_confirm" = "End";
"round_end_confirm_empty" = "End Without Saving";

/* Scorecard — 영문 스코어카드 관습: 타수에 단위를 붙이지 않는다 (spec §4) */
"scorecard_row" = "%lld (%lldp)";
"scorecard_total" = "Total %lld · %lldp · %@";

/* Summary */
"summary_holes_completed" = "%lld holes";
"summary_holes_empty" = "No holes recorded";
"summary_strokes_putts" = "%lld · %lldp";
"summary_discard_button" = "Discard";
"summary_discard_title" = "Discard this round without saving?";
"summary_discard_confirm" = "Discard";
"summary_transmitting" = "Sending…";
"summary_save_send" = "Save & Send";
```

- [ ] **Step 2: 키 집합 일치 테스트 작성**

`watchosTests/Localization/StringsParityTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

/// ko/en 번역표의 키가 어긋나면 한쪽 언어에서 키 문자열이 그대로 화면에 뜬다.
/// 파일을 손으로 관리하므로(String Catalog가 아니다) 이 검증이 필요하다 (spec §3).
struct StringsParityTests {
    private func keys(_ localization: String) throws -> Set<String> {
        let url = try #require(Bundle.main.url(forResource: "Localizable",
                                               withExtension: "strings",
                                               subdirectory: nil,
                                               localization: localization))
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return Set(table.keys)
    }

    @Test func 워치_두언어의_키집합이_같다() throws {
        let ko = try keys("ko")
        let en = try keys("en")

        #expect(ko == en, "ko에만: \(ko.subtracting(en)) / en에만: \(en.subtracting(ko))")
    }

    @Test func 워치_번역표가_비어있지_않다() throws {
        #expect(try keys("ko").count >= 20)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 이 시점에는 두 파일의 키가 같으므로 **PASS한다.** 이 테스트는 버그를 잡는 게 아니라 앞으로의 어긋남을 막는 안전망이다.

`#require`가 nil로 실패하면(`Bundle.main`에서 `.strings`를 못 찾으면) Task 1의 인식 확인과 모순되는 것이므로 **멈추고 보고한다.**

- [ ] **Step 4: `HomeViewModel.startButtonLabel` 제거 (spec §6)**

`WatchApp/Features/Home/HomeViewModel.swift`에서 아래를 통째로 삭제한다:

```swift

    var startButtonLabel: String {
        "\(holeCount)홀 시작"
    }
```

- [ ] **Step 5: 워치 View 문자열 교체**

`WatchApp/Features/Home/HomeView.swift:17`:

교체 대상:
```swift
                    Text(viewModel.startButtonLabel)
```
새 내용:
```swift
                    Text(String(format: String(localized: "home_start_button"), viewModel.holeCount))
```

`WatchApp/Features/Home/HomeView.swift:34,38,39,41`:

교체 대상:
```swift
            .confirmationDialog("진행 중인 라운드가 있습니다",
```
새 내용:
```swift
            .confirmationDialog(String(localized: "home_pending_title"),
```

교체 대상:
```swift
                Button("새로 시작", role: .destructive, action: viewModel.startNewRound)
                Button("취소", role: .cancel) {}
```
새 내용:
```swift
                Button(String(localized: "home_start_new"), role: .destructive, action: viewModel.startNewRound)
                Button(String(localized: "common_cancel"), role: .cancel) {}
```

교체 대상:
```swift
                Text("새로 시작하면 지워집니다.")
```
새 내용:
```swift
                Text(String(localized: "home_pending_message"))
```

`WatchApp/Features/Home/Components/HoleCountSelector.swift:13`:

교체 대상:
```swift
            Text("홀 수")
```
새 내용:
```swift
            Text(String(localized: "home_hole_count"))
```

`WatchApp/Features/Round/RoundSessionView.swift:49,70,71,75`:

교체 대상:
```swift
            Button("취소", role: .cancel) {}
```
새 내용:
```swift
            Button(String(localized: "common_cancel"), role: .cancel) {}
```

교체 대상:
```swift
            ? "\(viewModel.recordedHoleCount)홀이 기록됩니다"
            : "기록된 홀이 없습니다"
```
새 내용:
```swift
            ? String(format: String(localized: "round_end_title_recorded"), viewModel.recordedHoleCount)
            : String(localized: "round_end_title_empty")
```

교체 대상:
```swift
        viewModel.recordedHoleCount > 0 ? "종료" : "저장 없이 종료"
```
새 내용:
```swift
        viewModel.recordedHoleCount > 0
            ? String(localized: "round_end_confirm")
            : String(localized: "round_end_confirm_empty")
```

`WatchApp/Features/Round/ParSelection/ParSelectionView.swift:64`:

교체 대상:
```swift
            Text("\(viewModel.currentHoleNumber)번 홀")
```
새 내용:
```swift
            Text(String(format: String(localized: "par_hole_number"), viewModel.currentHoleNumber))
```

`WatchApp/Features/Round/Counting/CountingView.swift:38,42,43`:

교체 대상:
```swift
        .confirmationDialog("이 홀은 기록되지 않습니다",
```
새 내용:
```swift
        .confirmationDialog(String(localized: "counting_skip_title"),
```

교체 대상:
```swift
            Button("건너뛰기", role: .destructive, action: viewModel.skipCurrentHole)
            Button("취소", role: .cancel) {}
```
새 내용:
```swift
            Button(String(localized: "counting_skip_confirm"), role: .destructive, action: viewModel.skipCurrentHole)
            Button(String(localized: "common_cancel"), role: .cancel) {}
```

`WatchApp/Features/Round/Scorecard/ScorecardView.swift:19,30`:

교체 대상:
```swift
                    Text("\(row.score)타(\(row.putts)p)")
```
새 내용:
```swift
                    Text(String(format: String(localized: "scorecard_row"), row.score, row.putts))
```

교체 대상:
```swift
                Text("합계 \(snapshot.totalStrokes)타 · \(totalPutts)퍼트 · \(ScoreFormat.relativeToPar(snapshot.relativeToPar))")
```
새 내용:
```swift
                Text(String(format: String(localized: "scorecard_total"),
                            snapshot.totalStrokes,
                            totalPutts,
                            ScoreFormat.relativeToPar(snapshot.relativeToPar)))
```

`WatchApp/Features/Round/Summary/SummaryView.swift:29,53,61,65,66,72,73,78,79`:

교체 대상:
```swift
            Text("\(viewModel.trimmedTotalStrokes)타 · \(viewModel.trimmedTotalPutts)퍼트")
```
새 내용:
```swift
            Text(String(format: String(localized: "summary_strokes_putts"),
                        viewModel.trimmedTotalStrokes,
                        viewModel.trimmedTotalPutts))
```

교체 대상:
```swift
                Button("저장 안 함") { isConfirmingDiscard = true }
```
새 내용:
```swift
                Button(String(localized: "summary_discard_button")) { isConfirmingDiscard = true }
```

교체 대상:
```swift
        .confirmationDialog("이 라운드를 저장하지 않고 버릴까요?",
```
새 내용:
```swift
        .confirmationDialog(String(localized: "summary_discard_title"),
```

교체 대상:
```swift
            Button("버리기", role: .destructive, action: viewModel.discardRound)
            Button("취소", role: .cancel) {}
```
새 내용:
```swift
            Button(String(localized: "summary_discard_confirm"), role: .destructive, action: viewModel.discardRound)
            Button(String(localized: "common_cancel"), role: .cancel) {}
```

교체 대상:
```swift
            ? "\(viewModel.recordedHoleCount)홀 완료"
            : "기록된 홀 없음"
```
새 내용:
```swift
            ? String(format: String(localized: "summary_holes_completed"), viewModel.recordedHoleCount)
            : String(localized: "summary_holes_empty")
```

교체 대상:
```swift
        if viewModel.isTransmitting { return "전송 중…" }
        return viewModel.recordedHoleCount > 0 ? "저장 & 전송" : "저장 없이 종료"
```
새 내용:
```swift
        if viewModel.isTransmitting { return String(localized: "summary_transmitting") }
        return viewModel.recordedHoleCount > 0
            ? String(localized: "summary_save_send")
            : String(localized: "round_end_confirm_empty")
```

- [ ] **Step 6: `startButtonLabel` 테스트 삭제**

`watchosTests/Home/HomeViewModelTests.swift`에서 아래 테스트 함수를 **통째로 삭제한다** (앞뒤 빈 줄 포함):

```swift
    @Test func 시작_버튼_문구가_홀수를_말한다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.startButtonLabel == "18홀 시작")

        viewModel.toggleHoleCount()
        #expect(viewModel.startButtonLabel == "9홀 시작")
    }
```

이 테스트가 검증하던 것은 두 가지다 — (1) `holeCount`가 18에서 9로 토글된다, (2) 그 값이 문구에 들어간다. (1)은 바로 위 테스트(`#expect(viewModel.holeCount == 18)`)와 `toggleHoleCount`를 다루는 다른 테스트가 이미 덮는다. (2)는 이제 번역표의 내용이라 테스트할 가치가 없다 (spec §6).

**`toggleHoleCount`를 검증하는 다른 테스트가 이 파일에 없다면** 삭제 대신 아래로 바꾼다:

```swift
    @Test func 홀수를_토글하면_9와_18을_오간다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        viewModel.toggleHoleCount()

        #expect(viewModel.holeCount == 9)
    }
```

- [ ] **Step 7: 빌드·테스트·lint 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
make lint && make format
```

Expected: `** TEST SUCCEEDED **`, lint 출력에 `Found 0 violations`

- [ ] **Step 8: 40mm 영어 화면 확인 — 이 태스크에서 가장 중요한 검증**

영어는 한국어보다 길다. 40mm가 가장 좁으므로 여기서 잘리면 다른 크기는 안전하다.

```bash
xcrun simctl list devices available | grep "40mm"
```

`Apple Watch SE 3 (40mm)`를 부팅하고, 워치 앱을 영어로 실행해 홈·파 선택·요약 화면을 확인한다. 스킴의 App Language를 English로 두거나 실행 인자에 `-AppleLanguages "(en)"`를 준다.

확인할 것:
1. 홈의 `Start 18 Holes` 버튼 텍스트가 잘리지 않는다
2. 요약의 `Save & Send` 버튼이 한 줄에 들어간다
3. 종료 다이얼로그의 `18 holes will be saved`가 읽힌다

**잘리는 문구가 있으면 `.strings`의 영어 쪽을 더 짧게 고친다** (코드나 레이아웃을 고치지 않는다 — spec §4가 영어를 공간에 맞추기로 한 이유가 이것이다). 고친 뒤 다시 확인한다.

- [ ] **Step 9: 커밋**

```bash
make lint && make format
git add WatchApp/ watchosTests/
git commit -m "✨ feat: 워치 로컬라이즈"
```

---

### Task 3: iOS 기록 영역

**Files:**
- Create: `iOSApp/en.lproj/Localizable.strings`, `iOSApp/ko.lproj/Localizable.strings`
- Create: `iosTests/Localization/StringsParityTests.swift`
- Modify: `iOSApp/MainTabView.swift`, `iOSApp/Components/EmptyRounds.swift`, `iOSApp/Features/History/HistoryView.swift`, `iOSApp/Features/History/Components/RoundCard.swift`, `iOSApp/Features/History/Detail/RoundDetailView.swift`, `iOSApp/Features/History/Detail/Components/HoleRow.swift`, `iOSApp/Features/History/Detail/Components/HoleEditSheet.swift`, `iOSApp/Features/History/Detail/Components/WorkoutMetricsGrid.swift`

**Interfaces:**
- Consumes: Task 1이 확인한 `.lproj` 인식
- Produces: `iOSApp/{en,ko}.lproj/Localizable.strings` (Task 4가 여기에 통계 키를 덧붙인다)

- [ ] **Step 1: `.lproj` 파일 두 개 생성**

`iOSApp/ko.lproj/Localizable.strings`:

```
/* Tabs */
"tab_stats" = "통계";
"tab_history" = "기록";

/* Common */
"common_cancel" = "취소";
"common_save" = "저장";
"common_delete" = "삭제";

/* Empty State */
"empty_rounds_title" = "기록된 라운드가 없습니다";
"empty_rounds_message" = "Apple Watch에서 라운드를 시작하세요";

/* History */
"history_title" = "기록";
"history_delete_title" = "이 라운드를 삭제할까요?";

/* Round Card — 영문은 골프 약식 표기 (spec §4) */
"round_card_holes" = "%lld홀";
"round_card_strokes" = "%lld타";

/* Round Detail */
"detail_title" = "라운드 상세";
"detail_section_course" = "골프장";
"detail_course_placeholder" = "골프장명 입력";
"detail_section_scorecard" = "스코어카드";
"detail_section_workout" = "워크아웃";
"detail_total" = "합계";
"detail_strokes_putts" = "%lld타 · %lld퍼트";

/* Hole Row — 영문 스코어카드 관습: 타수에 단위를 붙이지 않는다 (spec §4) */
"hole_row_strokes_putts" = "%lld타 · %lld퍼트";
"hole_row_unrecorded" = "기록 없음";

/* Hole Edit */
"edit_section_strokes" = "타수";
"edit_section_putts" = "퍼팅";
"edit_strokes_value" = "%lld타";
"edit_putts_value" = "%lld퍼트";

/* Workout Metrics */
"workout_calories" = "칼로리";
"workout_heart_rate" = "평균 심박";
"workout_distance" = "거리";
"workout_steps" = "걸음";
"workout_duration" = "소요 시간";
"workout_duration_hm" = "%lld시간 %lld분";
"workout_duration_m" = "%lld분";
```

`iOSApp/en.lproj/Localizable.strings`:

```
/* Tabs */
"tab_stats" = "Stats";
"tab_history" = "History";

/* Common */
"common_cancel" = "Cancel";
"common_save" = "Save";
"common_delete" = "Delete";

/* Empty State */
"empty_rounds_title" = "No rounds recorded";
"empty_rounds_message" = "Start a round on your Apple Watch";

/* History */
"history_title" = "History";
"history_delete_title" = "Delete this round?";

/* Round Card — 영문은 골프 약식 표기 (spec §4) */
"round_card_holes" = "%lldH";
"round_card_strokes" = "%lld";

/* Round Detail */
"detail_title" = "Round Detail";
"detail_section_course" = "Course";
"detail_course_placeholder" = "Enter course name";
"detail_section_scorecard" = "Scorecard";
"detail_section_workout" = "Workout";
"detail_total" = "Total";
"detail_strokes_putts" = "%lld · %lld putts";

/* Hole Row — 영문 스코어카드 관습: 타수에 단위를 붙이지 않는다 (spec §4) */
"hole_row_strokes_putts" = "%lld · %lldp";
"hole_row_unrecorded" = "Not recorded";

/* Hole Edit */
"edit_section_strokes" = "Strokes";
"edit_section_putts" = "Putts";
"edit_strokes_value" = "%lld";
"edit_putts_value" = "%lld";

/* Workout Metrics */
"workout_calories" = "Calories";
"workout_heart_rate" = "Avg. Heart Rate";
"workout_distance" = "Distance";
"workout_steps" = "Steps";
"workout_duration" = "Duration";
"workout_duration_hm" = "%lldh %lldm";
"workout_duration_m" = "%lldm";
```

- [ ] **Step 2: 키 집합 일치 테스트 작성**

`iosTests/Localization/StringsParityTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter
import Testing

/// ko/en 번역표의 키가 어긋나면 한쪽 언어에서 키 문자열이 그대로 화면에 뜬다.
/// 파일을 손으로 관리하므로(String Catalog가 아니다) 이 검증이 필요하다 (spec §3).
struct StringsParityTests {
    private func keys(_ localization: String) throws -> Set<String> {
        let url = try #require(Bundle.main.url(forResource: "Localizable",
                                               withExtension: "strings",
                                               subdirectory: nil,
                                               localization: localization))
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return Set(table.keys)
    }

    @Test func iOS_두언어의_키집합이_같다() throws {
        let ko = try keys("ko")
        let en = try keys("en")

        #expect(ko == en, "ko에만: \(ko.subtracting(en)) / en에만: \(en.subtracting(ko))")
    }

    @Test func iOS_번역표가_비어있지_않다() throws {
        #expect(try keys("ko").count >= 25)
    }
}
```

- [ ] **Step 3: iOS 기록 영역 View 문자열 교체**

`iOSApp/MainTabView.swift:9,12`:

교체 대상:
```swift
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }
```
새 내용:
```swift
                .tabItem { Label(String(localized: "tab_stats"), systemImage: "chart.bar.fill") }
```

교체 대상:
```swift
                .tabItem { Label("기록", systemImage: "clock.fill") }
```
새 내용:
```swift
                .tabItem { Label(String(localized: "tab_history"), systemImage: "clock.fill") }
```

`iOSApp/Components/EmptyRounds.swift:7,9`:

교체 대상:
```swift
            Label("기록된 라운드가 없습니다", systemImage: "figure.golf")
```
새 내용:
```swift
            Label(String(localized: "empty_rounds_title"), systemImage: "figure.golf")
```

교체 대상:
```swift
            Text("Apple Watch에서 라운드를 시작하세요")
```
새 내용:
```swift
            Text(String(localized: "empty_rounds_message"))
```

`iOSApp/Features/History/HistoryView.swift:27,34,35,40,41`:

교체 대상:
```swift
                                    Label("삭제", systemImage: "trash")
```
새 내용:
```swift
                                    Label(String(localized: "common_delete"), systemImage: "trash")
```

교체 대상:
```swift
            .navigationTitle("기록")
            .confirmationDialog("이 라운드를 삭제할까요?",
```
새 내용:
```swift
            .navigationTitle(String(localized: "history_title"))
            .confirmationDialog(String(localized: "history_delete_title"),
```

교체 대상:
```swift
                Button("삭제", role: .destructive) { delete(round) }
                Button("취소", role: .cancel) { pendingDeletion = nil }
```
새 내용:
```swift
                Button(String(localized: "common_delete"), role: .destructive) { delete(round) }
                Button(String(localized: "common_cancel"), role: .cancel) { pendingDeletion = nil }
```

`iOSApp/Features/History/Components/RoundCard.swift:20,34`:

교체 대상:
```swift
                Text("\(round.recordedHoleCount)홀")
```
새 내용:
```swift
                Text(String(format: String(localized: "round_card_holes"), round.recordedHoleCount))
```

교체 대상:
```swift
                Text("\(round.totalStrokes)타")
```
새 내용:
```swift
                Text(String(format: String(localized: "round_card_strokes"), round.totalStrokes))
```

`iOSApp/Features/History/Detail/RoundDetailView.swift:19,41,54,55,61,75,77,88`:

교체 대상:
```swift
        .navigationTitle("라운드 상세")
```
새 내용:
```swift
        .navigationTitle(String(localized: "detail_title"))
```

41행과 77행은 같은 내용이다. **두 곳 모두** 교체한다.

교체 대상 (2곳):
```swift
                Text("\(round.totalStrokes)타 · \(round.totalPutts)퍼트")
```
새 내용 (2곳):
```swift
                Text(String(format: String(localized: "detail_strokes_putts"),
                            round.totalStrokes, round.totalPutts))
```

교체 대상:
```swift
        Section("골프장") {
            TextField("골프장명 입력", text: $courseNameDraft)
```
새 내용:
```swift
        Section(String(localized: "detail_section_course")) {
            TextField(String(localized: "detail_course_placeholder"), text: $courseNameDraft)
```

교체 대상:
```swift
        Section("스코어카드") {
```
새 내용:
```swift
        Section(String(localized: "detail_section_scorecard")) {
```

교체 대상:
```swift
                Text("합계").font(.subheadline.weight(.semibold))
```
새 내용:
```swift
                Text(String(localized: "detail_total")).font(.subheadline.weight(.semibold))
```

교체 대상:
```swift
        Section("워크아웃") {
```
새 내용:
```swift
        Section(String(localized: "detail_section_workout")) {
```

`iOSApp/Features/History/Detail/Components/HoleRow.swift:33,40`:

교체 대상:
```swift
                Text("\(score)타 · \(putts)퍼트")
```
새 내용:
```swift
                Text(String(format: String(localized: "hole_row_strokes_putts"), score, putts))
```

교체 대상:
```swift
                Text("기록 없음")
```
새 내용:
```swift
                Text(String(localized: "hole_row_unrecorded"))
```

`iOSApp/Features/History/Detail/Components/HoleEditSheet.swift:36,37,42,43,52,55`:

교체 대상:
```swift
                Section("타수") {
                    Stepper("\(model.score)타",
```
새 내용:
```swift
                Section(String(localized: "edit_section_strokes")) {
                    Stepper(String(format: String(localized: "edit_strokes_value"), model.score),
```

교체 대상:
```swift
                Section("퍼팅") {
                    Stepper("\(model.putts)퍼트",
```
새 내용:
```swift
                Section(String(localized: "edit_section_putts")) {
                    Stepper(String(format: String(localized: "edit_putts_value"), model.putts),
```

교체 대상:
```swift
                    Button("취소") { dismiss() }
```
새 내용:
```swift
                    Button(String(localized: "common_cancel")) { dismiss() }
```

교체 대상:
```swift
                    Button("저장") {
```
새 내용:
```swift
                    Button(String(localized: "common_save")) {
```

`iOSApp/Features/History/Detail/Components/WorkoutMetricsGrid.swift:9-13,27`:

교체 대상:
```swift
            StatCard(title: "칼로리", value: "\(Int(round.calories.rounded())) kcal")
            StatCard(title: "평균 심박", value: heartRateText)
            StatCard(title: "거리", value: String(format: "%.2f km", round.distanceMeters / 1000))
            StatCard(title: "걸음", value: "\(round.steps)")
            StatCard(title: "소요 시간", value: durationText)
```
새 내용:
```swift
            StatCard(title: String(localized: "workout_calories"), value: "\(Int(round.calories.rounded())) kcal")
            StatCard(title: String(localized: "workout_heart_rate"), value: heartRateText)
            StatCard(title: String(localized: "workout_distance"), value: String(format: "%.2f km", round.distanceMeters / 1000))
            StatCard(title: String(localized: "workout_steps"), value: "\(round.steps)")
            StatCard(title: String(localized: "workout_duration"), value: durationText)
```

교체 대상:
```swift
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
```
새 내용:
```swift
        return hours > 0
            ? String(format: String(localized: "workout_duration_hm"), hours, minutes)
            : String(format: String(localized: "workout_duration_m"), minutes)
```

`kcal`·`km`은 국제 단위 기호라 두 언어에서 같다 — 번역하지 않는다.

- [ ] **Step 4: 빌드·테스트·lint 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
make lint && make format
```

Expected: `** TEST SUCCEEDED **` (기존 44건 + 신규 2건), lint 출력에 `Found 0 violations`

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add iOSApp/ iosTests/
git commit -m "✨ feat: iOS 기록 영역 로컬라이즈"
```

---

### Task 4: iOS 통계 영역

**Files:**
- Modify: `iOSApp/en.lproj/Localizable.strings`, `iOSApp/ko.lproj/Localizable.strings` (키 추가)
- Modify: `iOSApp/Features/Stats/StatsView.swift`, `iOSApp/Features/Stats/Components/ScoreDistributionChart.swift`, `iOSApp/Features/Stats/Components/OverParTrendChart.swift`

**Interfaces:**
- Consumes: Task 3의 `iOSApp/{en,ko}.lproj/Localizable.strings`
- Produces: 없음

**spec §5의 복수형 회피가 여기서 실제로 적용된다.** `총 N라운드`와 `18홀 라운드 N개 기준` 두 캡션이 영어에서 `1 rounds`를 만들 수 있는 유일한 곳이라, 라벨 형식으로 쓴다.

- [ ] **Step 1: 통계 키 추가**

`iOSApp/ko.lproj/Localizable.strings`의 끝에 덧붙인다:

```

/* Stats */
"stats_title" = "통계";
"stats_section_trend" = "오버파 추이";
"stats_section_distribution" = "스코어 분포";
"stats_section_par" = "파별 성적";
"stats_par_caption" = "홀당 평균 오버파";
"stats_card_avg_strokes" = "평균 타수";
"stats_card_best" = "베스트 스코어";
"stats_card_avg_over_par" = "평균 오버파";
"stats_card_putts_per_hole" = "홀당 평균 퍼트";
"stats_best_holes" = "%lld홀";

/* 영어는 복수형을 피해 라벨 형식으로 쓴다 — "1 rounds"를 막는다 (spec §5) */
"stats_round_total" = "총 %lld라운드";
"stats_full_round_caption" = "18홀 라운드 %lld개 기준";

/* Distribution Chart */
"chart_axis_holes" = "홀 수";
"chart_axis_bucket" = "구간";
"chart_bucket_value" = "%lld홀 · %@";
"bucket_birdie_or_better" = "버디 이상";
"bucket_par" = "파";
"bucket_bogey" = "보기";
"bucket_double_or_worse" = "더블보기+";

/* Trend Chart */
"chart_axis_even_par" = "이븐파";
"chart_axis_date" = "날짜";
"chart_axis_over_par" = "오버파";
```

`iOSApp/en.lproj/Localizable.strings`의 끝에 덧붙인다:

```

/* Stats */
"stats_title" = "Stats";
"stats_section_trend" = "Over-Par Trend";
"stats_section_distribution" = "Score Distribution";
"stats_section_par" = "By Par";
"stats_par_caption" = "Avg. over par per hole";
"stats_card_avg_strokes" = "Avg. Strokes";
"stats_card_best" = "Best Score";
"stats_card_avg_over_par" = "Avg. Over Par";
"stats_card_putts_per_hole" = "Putts per Hole";
"stats_best_holes" = "%lldH";

/* 영어는 복수형을 피해 라벨 형식으로 쓴다 — "1 rounds"를 막는다 (spec §5) */
"stats_round_total" = "Rounds: %lld";
"stats_full_round_caption" = "Full rounds: %lld";

/* Distribution Chart */
"chart_axis_holes" = "Holes";
"chart_axis_bucket" = "Bucket";
"chart_bucket_value" = "%lld · %@";
"bucket_birdie_or_better" = "Birdie or better";
"bucket_par" = "Par";
"bucket_bogey" = "Bogey";
"bucket_double_or_worse" = "Double+";

/* Trend Chart */
"chart_axis_even_par" = "Even";
"chart_axis_date" = "Date";
"chart_axis_over_par" = "Over par";
```

- [ ] **Step 2: 키 일치 테스트가 통과하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: Task 3에서 만든 `iOS_두언어의_키집합이_같다`가 PASS. **실패하면 두 파일에 덧붙인 키가 어긋난 것이므로** 실패 메시지의 차집합을 보고 고친다.

- [ ] **Step 3: `StatsView` 문자열 교체**

`iOSApp/Features/Stats/StatsView.swift:27,33,40,43,45,46,49,56,63,70`:

교체 대상:
```swift
            .navigationTitle("통계")
```
새 내용:
```swift
            .navigationTitle(String(localized: "stats_title"))
```

교체 대상:
```swift
            sectionHeader("오버파 추이", caption: "총 \(summary.roundCount)라운드")
```
새 내용:
```swift
            sectionHeader(String(localized: "stats_section_trend"),
                          caption: String(format: String(localized: "stats_round_total"), summary.roundCount))
```

교체 대상:
```swift
            StatCard(title: "평균 타수",
```
새 내용:
```swift
            StatCard(title: String(localized: "stats_card_avg_strokes"),
```

교체 대상:
```swift
            StatCard(title: "베스트 스코어",
```
새 내용:
```swift
            StatCard(title: String(localized: "stats_card_best"),
```

교체 대상:
```swift
                     caption: summary.best.map { "\($0.holeCount)홀" })
```
새 내용:
```swift
                     caption: summary.best.map {
                         String(format: String(localized: "stats_best_holes"), $0.holeCount)
                     })
```

교체 대상:
```swift
            StatCard(title: "평균 오버파",
```
새 내용:
```swift
            StatCard(title: String(localized: "stats_card_avg_over_par"),
```

교체 대상:
```swift
            StatCard(title: "홀당 평균 퍼트",
```
새 내용:
```swift
            StatCard(title: String(localized: "stats_card_putts_per_hole"),
```

교체 대상:
```swift
            sectionHeader("스코어 분포", caption: nil)
```
새 내용:
```swift
            sectionHeader(String(localized: "stats_section_distribution"), caption: nil)
```

교체 대상:
```swift
            sectionHeader("파별 성적", caption: "홀당 평균 오버파")
```
새 내용:
```swift
            sectionHeader(String(localized: "stats_section_par"),
                          caption: String(localized: "stats_par_caption"))
```

교체 대상:
```swift
        "18홀 라운드 \(summary.fullRoundCount)개 기준"
```
새 내용:
```swift
        String(format: String(localized: "stats_full_round_caption"), summary.fullRoundCount)
```

- [ ] **Step 4: `ScoreDistributionChart` 문자열 교체**

`iOSApp/Features/Stats/Components/ScoreDistributionChart.swift:10,11,14,27-30`:

교체 대상:
```swift
            BarMark(x: .value("홀 수", bucket.count),
                    y: .value("구간", Self.title(for: bucket.bucket)))
```
새 내용:
```swift
            BarMark(x: .value(String(localized: "chart_axis_holes"), bucket.count),
                    y: .value(String(localized: "chart_axis_bucket"), Self.title(for: bucket.bucket)))
```

교체 대상:
```swift
                    Text("\(bucket.count)홀 · \(Self.percent(bucket.ratio))")
```
새 내용:
```swift
                    Text(String(format: String(localized: "chart_bucket_value"),
                                bucket.count, Self.percent(bucket.ratio)))
```

교체 대상:
```swift
        case .birdieOrBetter: "버디 이상"
        case .par: "파"
        case .bogey: "보기"
        case .doubleOrWorse: "더블보기+"
```
새 내용:
```swift
        case .birdieOrBetter: String(localized: "bucket_birdie_or_better")
        case .par: String(localized: "bucket_par")
        case .bogey: String(localized: "bucket_bogey")
        case .doubleOrWorse: String(localized: "bucket_double_or_worse")
```

`chartYScale(domain:)`은 같은 `title(for:)`를 쓰므로 자동으로 맞는다 — **건드리지 않는다.**

- [ ] **Step 5: `OverParTrendChart` 문자열 교체**

`iOSApp/Features/Stats/Components/OverParTrendChart.swift:10,15,16,19,20`:

교체 대상:
```swift
            RuleMark(y: .value("이븐파", 0))
```
새 내용:
```swift
            RuleMark(y: .value(String(localized: "chart_axis_even_par"), 0))
```

교체 대상:
```swift
                LineMark(x: .value("날짜", point.date),
                         y: .value("오버파", point.relativeToPar))
```
새 내용:
```swift
                LineMark(x: .value(String(localized: "chart_axis_date"), point.date),
                         y: .value(String(localized: "chart_axis_over_par"), point.relativeToPar))
```

교체 대상:
```swift
                PointMark(x: .value("날짜", point.date),
                          y: .value("오버파", point.relativeToPar))
```
새 내용:
```swift
                PointMark(x: .value(String(localized: "chart_axis_date"), point.date),
                          y: .value(String(localized: "chart_axis_over_par"), point.relativeToPar))
```

- [ ] **Step 6: 빌드·테스트·lint 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
make lint && make format
```

Expected: `** TEST SUCCEEDED **`, lint 출력에 `Found 0 violations`

- [ ] **Step 7: 영어 화면 확인**

iPhone 17 Pro 시뮬레이터를 영어로 실행해 통계 탭과 기록 탭을 확인한다.

확인할 것:
1. 통계 카드 4개의 제목(`Avg. Strokes` 등)이 잘리지 않는다
2. 분포 차트의 Y축 라벨 4개(`Birdie or better` 등)가 읽히고 **순서가 위에서부터 birdie → par → bogey → double**이다
3. `Full rounds: 3` 캡션이 카드 밑에 들어간다
4. 라운드가 없을 때 `No rounds recorded`가 뜬다

라운드 데이터가 없으면 빈 상태만 보인다. 차트를 채워 보려면 시뮬레이터에 라운드를 임시로 넣어야 하는데, **그 목적의 코드를 커밋하지 않는다.**

- [ ] **Step 8: 커밋**

```bash
make lint && make format
git add iOSApp/
git commit -m "✨ feat: iOS 통계 영역 로컬라이즈"
```

---

### Task 5: HealthKit 권한 문구 (InfoPlist)

**Files:**
- Create: `iOSApp/en.lproj/InfoPlist.strings`, `iOSApp/ko.lproj/InfoPlist.strings`
- Create: `WatchApp/en.lproj/InfoPlist.strings`, `WatchApp/ko.lproj/InfoPlist.strings`

**Interfaces:**
- Consumes: Task 1이 확인한 `.lproj` 인식
- Produces: 없음

권한 문구는 `INFOPLIST_KEY_NSHealthShareUsageDescription` 빌드 설정으로 들어가 있어 생성된 Info.plist에 한국어로 박힌다. `InfoPlist.strings`가 런타임에 언어별로 덮어쓴다. **빌드 설정은 건드리지 않는다** — 한국어 값이 그대로 폴백으로 남는다.

두 문구는 iOS·워치 **양쪽 타깃 모두**에 설정되어 있으므로 양쪽에 파일을 만든다.

- [ ] **Step 1: iOS `InfoPlist.strings` 두 개 생성**

`iOSApp/ko.lproj/InfoPlist.strings`:

```
"NSHealthShareUsageDescription" = "라운드 중 심박수·칼로리를 기록하기 위해 사용합니다.";
"NSHealthUpdateUsageDescription" = "라운드 중 심박수·칼로리를 기록하기 위해 사용합니다.";
```

`iOSApp/en.lproj/InfoPlist.strings`:

```
"NSHealthShareUsageDescription" = "Used to record heart rate and calories during a round.";
"NSHealthUpdateUsageDescription" = "Used to record heart rate and calories during a round.";
```

- [ ] **Step 2: 워치 `InfoPlist.strings` 두 개 생성**

파일이 타깃별로 분리되므로 내용이 iOS와 같아도 각각 만들어야 한다.

`WatchApp/ko.lproj/InfoPlist.strings`:

```
"NSHealthShareUsageDescription" = "라운드 중 심박수·칼로리를 기록하기 위해 사용합니다.";
"NSHealthUpdateUsageDescription" = "라운드 중 심박수·칼로리를 기록하기 위해 사용합니다.";
```

`WatchApp/en.lproj/InfoPlist.strings`:

```
"NSHealthShareUsageDescription" = "Used to record heart rate and calories during a round.";
"NSHealthUpdateUsageDescription" = "Used to record heart rate and calories during a round.";
```

- [ ] **Step 3: 빌드 산출물에 포함됐는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
find ~/Library/Developer/Xcode/DerivedData -path "*GolfCounter.app/*.lproj/InfoPlist.strings" 2>/dev/null | head
```

Expected: `** BUILD SUCCEEDED **`, `en.lproj`·`ko.lproj` 두 경로가 나온다

- [ ] **Step 4: 세 타깃 빌드·테스트 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
make lint && make format
```

Expected: iOS·워치 `** TEST SUCCEEDED **`, 컴플리케이션 `** BUILD SUCCEEDED **`, lint 출력에 `Found 0 violations`

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add iOSApp/ WatchApp/
git commit -m "✨ feat: HealthKit 권한 문구 로컬라이즈"
```

---

## 완료 조건

- 세 타깃의 사용자 노출 문자열이 ko/en 모두에서 올바르게 표시된다
- 워치 40mm에서 영어 문구가 잘리거나 겹치지 않는다 (Task 2 Step 8에서 확인)
- 모델·ViewModel에 언어 의존 문자열이 남아 있지 않다 (`ComplicationState.strokesText`·`HomeViewModel.startButtonLabel` 제거됨)
- ko/en 키 집합이 일치한다 (양 타깃의 `StringsParityTests`가 강제)
- `.stringsdict`가 없다 — 복수형은 문구로 회피했다
- `Shared/`에 `.lproj`가 없다
- 리빌드 스펙 §10이 실제 채택한 형식(`.lproj`)과 일치한다
- 세 타깃 빌드 성공, iOS·워치 테스트 전부 통과, `make lint` 출력에 `Found 0 violations`

## 이 plan이 하지 않는 것

- 앱 표시명 교체 (`CFBundleDisplayName`은 `GolfCounter` 그대로)
- MapKit 위치 권한 문구 — plan ⑧이 위치 기능과 함께 넣는다
- 실기기 검증 — ⑦·⑧이 끝난 뒤 일괄 수행하기로 했다
- App Store 등록 정보
