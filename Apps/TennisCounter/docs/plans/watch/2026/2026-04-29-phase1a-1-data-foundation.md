# Phase 1-A ① Data Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwiftData Match/SetRecord 모델 생성, iOSApp에 ModelContainer 연결, 영어/한국어 Localizable.strings 초기 설정, 3-탭 skeleton TabView 구축

**Architecture:** `Match` (`@Model`)와 `SetRecord` (`@Model`)를 Shared/Models에 두어 iOS/Watch 공용. iOSApp.swift가 ModelContainer를 소유하고 Summary/Match/History 3-탭을 렌더링. Localizable.strings는 `String(localized:)` API 사용.

**Tech Stack:** SwiftData (iOS 17+), SwiftUI TabView, Foundation String(localized:)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `Shared/Models/Match.swift` | Create | SwiftData Match 모델 |
| `Shared/Models/SetRecord.swift` | Create | SwiftData SetRecord 모델 |
| `iOSApp/iOSApp.swift` | Modify | ModelContainer 주입 + 3-탭 skeleton |
| `iOSApp/en.lproj/Localizable.strings` | Create | 영어 마스터 문자열 |
| `iOSApp/ko.lproj/Localizable.strings` | Create | 한국어 번역 |
| `WatchApp/en.lproj/Localizable.strings` | Create | Watch 영어 문자열 |
| `WatchApp/ko.lproj/Localizable.strings` | Create | Watch 한국어 번역 |

---

### Task 1: SwiftData 모델 생성

**Files:**
- Create: `Shared/Models/Match.swift`
- Create: `Shared/Models/SetRecord.swift`

> **주의**: 두 파일 모두 iOS와 Watch 타겟 모두에 추가해야 한다. Xcode에서 파일 선택 후 Target Membership에서 두 타겟 체크.

- [ ] **Step 1: SetRecord.swift 생성**

```swift
import Foundation
import SwiftData

@Model
class SetRecord {
    var myGames: Int = 0
    var yourGames: Int = 0
    var setNumber: Int = 0

    init(myGames: Int, yourGames: Int, setNumber: Int) {
        self.myGames = myGames
        self.yourGames = yourGames
        self.setNumber = setNumber
    }
}
```

- [ ] **Step 2: Match.swift 생성**

```swift
import Foundation
import SwiftData

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var matchFormat: String = "one_set"   // "one_set" | "best_of_3"
    @Relationship(deleteRule: .cascade) var sets: [SetRecord]? = []
    var opponentName: String?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false

    init(matchFormat: String = "one_set") {
        self.matchFormat = matchFormat
    }
}
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/Match.swift Shared/Models/SetRecord.swift
git commit -m "feat: add Match and SetRecord SwiftData models"
```

---

### Task 2: iOSApp.swift – ModelContainer + 3-탭 TabView

**Files:**
- Modify: `iOSApp/iOSApp.swift`

> **참고**: 현재 iOSApp.swift는 `MatchView()`를 직접 렌더링. 이 태스크에서 3-탭 구조로 교체하고 ModelContainer를 주입한다. Summary/History 탭은 각 feature plan에서 채워질 placeholder로 남겨둔다.

- [ ] **Step 1: iOSApp.swift 전체 교체**

```swift
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Match.self, SetRecord.self])
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Summary")
                .tabItem {
                    Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                }

            NavigationStack {
                Text("Match")
            }
            .tabItem {
                Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
            }

            Text("History")
                .tabItem {
                    Label(String(localized: "tab_history"), systemImage: "clock.fill")
                }
        }
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/iOSApp.swift
git commit -m "feat: add 3-tab skeleton and ModelContainer to iOSApp"
```

---

### Task 3: Localizable.strings – 영어 (iOS)

**Files:**
- Create: `iOSApp/en.lproj/Localizable.strings`

> **Xcode 설정 필수**: `iOSApp/en.lproj/` 디렉터리를 생성한 뒤 Xcode에서 File > Add Files > `iOSApp/en.lproj/Localizable.strings`를 선택하고 TennisCounter 타겟에 추가해야 `String(localized:)` API가 동작한다.

- [ ] **Step 1: en.lproj 디렉터리 및 파일 생성**

```bash
mkdir -p iOSApp/en.lproj
```

`iOSApp/en.lproj/Localizable.strings` 파일 내용:

```
/* Tabs */
"tab_summary" = "Summary";
"tab_match" = "Match";
"tab_history" = "History";

/* Match Format */
"match_format_one_set" = "One Set";
"match_format_best_of_3" = "Best of 3";
"match_format_one_set_desc" = "Quick practice, one set";
"match_format_best_of_3_desc" = "Official match, first to win 2 sets";

/* Match Screen */
"new_match" = "New Match";
"score_label_me" = "ME";
"score_label_opp" = "OPP";
"btn_confirm" = "Confirm";
"btn_reset" = "Reset";
"btn_undo" = "Undo";
"btn_end_match" = "End Match";
"btn_end_set" = "End Set";
"btn_new_match" = "New Match";
"set_indicator_format" = "Set %d";
"match_over_win" = "Victory!";
"match_over_lose" = "Defeat";
"game_score_label" = "Games";

/* Summary */
"summary_period_today" = "Today";
"summary_period_week" = "This Week";
"summary_period_month" = "This Month";
"summary_period_all" = "All Time";
"summary_total_matches" = "Matches";
"summary_win_rate" = "Win Rate";
"summary_streak" = "Day Streak";
"summary_recent_matches" = "Recent Matches";
"summary_no_matches" = "No matches this period";

/* History */
"history_title" = "History";
"history_empty" = "No matches recorded yet";
"history_view_calendar" = "Calendar";
"history_view_list" = "List";

/* Common */
"btn_cancel" = "Cancel";
"btn_save" = "Save";
"vs_label" = "vs";
```

- [ ] **Step 2: Xcode에 파일 추가**

Xcode에서 수동으로 수행:
1. File > Add Files to "TennisCounter"
2. `iOSApp/en.lproj/Localizable.strings` 선택
3. Target Membership: `TennisCounter` 체크

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add "iOSApp/en.lproj/Localizable.strings"
git commit -m "feat: add English Localizable.strings for iOS"
```

---

### Task 4: Localizable.strings – 한국어 (iOS)

**Files:**
- Create: `iOSApp/ko.lproj/Localizable.strings`

> **Xcode 설정 필수**: Project > Info > Localizations에서 Korean을 추가해야 `ko.lproj`가 인식된다.

- [ ] **Step 1: ko.lproj 디렉터리 및 파일 생성**

```bash
mkdir -p iOSApp/ko.lproj
```

`iOSApp/ko.lproj/Localizable.strings` 파일 내용:

```
/* Tabs */
"tab_summary" = "요약";
"tab_match" = "경기";
"tab_history" = "기록";

/* Match Format */
"match_format_one_set" = "한 세트";
"match_format_best_of_3" = "3세트 매치";
"match_format_one_set_desc" = "빠른 연습, 한 세트만 기록";
"match_format_best_of_3_desc" = "정식 경기, 2세트 선취 시 종료";

/* Match Screen */
"new_match" = "새 경기";
"score_label_me" = "나";
"score_label_opp" = "상대";
"btn_confirm" = "확인";
"btn_reset" = "초기화";
"btn_undo" = "되돌리기";
"btn_end_match" = "경기 종료";
"btn_end_set" = "세트 종료";
"btn_new_match" = "새 경기";
"set_indicator_format" = "%d세트";
"match_over_win" = "승리!";
"match_over_lose" = "패배";
"game_score_label" = "게임";

/* Summary */
"summary_period_today" = "오늘";
"summary_period_week" = "이번 주";
"summary_period_month" = "이번 달";
"summary_period_all" = "전체";
"summary_total_matches" = "경기 수";
"summary_win_rate" = "승률";
"summary_streak" = "연속 플레이";
"summary_recent_matches" = "최근 경기";
"summary_no_matches" = "이 기간에 경기가 없습니다";

/* History */
"history_title" = "기록";
"history_empty" = "저장된 경기가 없습니다";
"history_view_calendar" = "달력";
"history_view_list" = "목록";

/* Common */
"btn_cancel" = "취소";
"btn_save" = "저장";
"vs_label" = "vs";
```

- [ ] **Step 2: Xcode에 Korean Localization 추가**

Xcode에서 수동으로 수행:
1. Project Navigator에서 TennisCounter 프로젝트 선택
2. Project > Info > Localizations > `+` > Korean 추가
3. `iOSApp/ko.lproj/Localizable.strings`를 TennisCounter 타겟에 추가

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add "iOSApp/ko.lproj/Localizable.strings"
git commit -m "feat: add Korean Localizable.strings for iOS"
```

---

### Task 5: Watch Localizable.strings

**Files:**
- Create: `WatchApp/en.lproj/Localizable.strings`
- Create: `WatchApp/ko.lproj/Localizable.strings`

> Watch 앱은 iOS와 별도 타겟이므로 별도 lproj가 필요하다.

- [ ] **Step 1: Watch 영어 문자열 파일 생성**

```bash
mkdir -p WatchApp/en.lproj WatchApp/ko.lproj
```

`WatchApp/en.lproj/Localizable.strings` 파일 내용:

```
"watch_quick_match" = "Quick Match";
"watch_score_me" = "ME";
"watch_score_opp" = "OPP";
"watch_undo" = "Undo";
"watch_new_match" = "New Match";
"watch_victory" = "Victory!";
"watch_defeat" = "Defeat";
"watch_set_label" = "SET";
```

`WatchApp/ko.lproj/Localizable.strings` 파일 내용:

```
"watch_quick_match" = "빠른 경기";
"watch_score_me" = "나";
"watch_score_opp" = "상대";
"watch_undo" = "되돌리기";
"watch_new_match" = "새 경기";
"watch_victory" = "승리!";
"watch_defeat" = "패배";
"watch_set_label" = "세트";
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add "WatchApp/en.lproj/" "WatchApp/ko.lproj/"
git commit -m "feat: add Watch Localizable.strings (en + ko)"
```

---

### Task 6: CloudKit 준비 (수동 Xcode 작업)

> Apple Developer Program 가입 후 진행. 지금은 설정만 해두고 실제 CloudKit 동작은 개발자 계정 활성화 후 확인.

- [ ] **Step 1: CloudKit Capability 추가 (Xcode 수동)**

1. Xcode > TennisCounter 타겟 선택
2. Signing & Capabilities > `+` > iCloud 추가
3. CloudKit 체크 → Container 자동 생성: `iCloud.com.yourname.TennisCounter`
4. Background Modes에서 `Remote notifications` 체크 (CloudKit silent push용)

- [ ] **Step 2: ModelContainer에 CloudKit 활성화**

`iOSApp/iOSApp.swift`의 `.modelContainer(for:)` 수정:

```swift
// 기존
.modelContainer(for: [Match.self, SetRecord.self])

// CloudKit 활성화 후 교체
.modelContainer(for: [Match.self, SetRecord.self],
                configurations: ModelConfiguration(cloudKitDatabase: .automatic))
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/iOSApp.swift
git commit -m "feat: enable CloudKit sync in ModelContainer"
```

---

## 완료 기준

- [x] `Match`, `SetRecord` SwiftData 모델이 Shared/Models에 존재
- [x] iOS 앱 실행 시 3-탭 TabView가 표시됨
- [x] `String(localized: "tab_summary")` 가 영어로 "Summary", 한국어로 "요약" 반환
- [x] iOS/Watch 빌드 모두 성공
