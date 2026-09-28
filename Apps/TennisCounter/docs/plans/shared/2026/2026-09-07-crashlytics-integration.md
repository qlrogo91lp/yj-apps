# Ralli Crashlytics 연동 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ralli iOS·워치 앱에 YJKit `MonitoringCore` 를 붙여 크래시가 Firebase 콘솔에 심볼 붙은 스택으로 올라오고, 경기 저장 실패가 non-fatal 로 기록되게 한다.

**Architecture:** 두 앱 진입점이 `CrashlyticsReporter.start()` 의 결과를 앱 레이어의 `AppCrashReporter.current` 에 담고, `WorkoutSessionViewModel` 은 그 값을 기본 인자로 받는다(→ 기존 호출부 무변경). plist 가 없으면(CI·새 체크아웃) `start()` 가 Noop 을 돌려주고, 테스트 실행 중에는 `start()` 자체를 건너뛴다. 저장 실패 3곳이 `MonitoringError(domain: "Ralli.Save", …)` 를 `record` 하고, 경기 시작·종료·저장 시도 3곳이 `log` 브레드크럼을 남긴다. plist·dSYM 스크립트는 타깃별.

> **2026-09-28 개정** — 저장소가 공개라 plist 를 git 에서 뺐다(`.gitignore`). 그에 맞춰 Kit 의
> `configureFirebase()` 가 `start() -> CrashReporting` 으로 바뀌었고(PR #35), CI 는 plist 없이 Noop 으로 돈다.
> 원안의 ViewModel 기본값 `CrashlyticsReporter()` 는 초기화 없이 리포터를 만들어 프리뷰·테스트를 죽일 수
> 있었다 — 이제 `CrashlyticsReporter` 는 `start()` 로만 얻는다.

**Tech Stack:** MonitoringCore / FirebaseCrashlytics / Swift Testing

**Spec:** [Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md](../../../../../../Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md)

**선행:** [YJKit MonitoringCore 플랜](../../../../../../Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md) 이 머지돼 있어야 한다. Firebase 콘솔 작업(Task 0)은 사람이 먼저 해 둔다.

## non-fatal 코드 표

| domain | code | 어디서 | context |
|---|---|---|---|
| `Ralli.Save` | 1 | iOS `saveCurrentMatch` upsert 실패 | `source: local`, `matchId` |
| `Ralli.Save` | 2 | iOS `saveFromWatch` upsert 실패 | `source: watch`, `sessionId` |
| `Ralli.Save` | 3 | 워치 저장 ACK 타임아웃 | `sessionId` |

같은 domain, 다른 code — 콘솔에서 "저장 실패" 로 모이되 경로별로 갈린다.

## Global Constraints

- **YJKit 은 수정하지 않는다.**
- 익스텐션 2개(`ComplicationApp`, `TennisLiveActivity`)에는 `MonitoringCore` 를 링크하지도, `start()` 를 부르지도 않는다.
- ViewModel 은 `CrashReporting` 프로토콜만 안다. `FirebaseCrashlytics` import 는 앱 진입점에도 없다 — `CrashlyticsReporter` 만.
- 주입 파라미터 기본값은 `AppCrashReporter.current` — 기존 테스트·프리뷰가 그대로 컴파일되고, 채워지기 전엔 Noop 이다.
- `GoogleService-Info.plist` 는 **커밋하지 않는다** — 저장소가 공개다. 루트 `.gitignore` 가 막는다. 로컬에만 두고, 새 체크아웃·워크트리에는 콘솔에서 다시 받는다.
- **CI 는 바꾸지 않는다.** plist 가 없으니 앱이 Noop 으로 돈다. GitHub Secret 도 쓰지 않는다.
- PR 은 Ralli 연동만 따로.

**빌드·테스트 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" -only-testing:watchosTests test
make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `iOSApp/GoogleService-Info.plist`, `WatchApp/GoogleService-Info.plist` | 로컬에만 (git 밖) | Firebase 앱 식별 |
| `TennisCounter.xcodeproj/project.pbxproj` | 수정 | 두 타깃에 `MonitoringCore` 링크, dSYM Build Phase(Release plist 검사 포함), `ENABLE_USER_SCRIPT_SANDBOXING = NO` |
| `Shared/Services/AppCrashReporter.swift` | 생성 | 앱이 쓰는 리포터 한 곳. 기본 Noop, 진입점이 `start()` 결과로 채운다 |
| `iOSApp/iOSApp.swift`, `WatchApp/WatchApp.swift` | 수정 | `AppCrashReporter.start()` |
| `CLAUDE.md` (TennisCounter) | 수정 | plist 가 git 밖에 있다는 것과 받는 곳 한 줄 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | `crashReporter` 주입(기본값 `AppCrashReporter.current`), 저장 실패 2곳 `record`, 브레드크럼 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | `crashReporter` 주입, ACK 타임아웃 `record`, 브레드크럼 |
| `iosTests/Support/CrashReportingSpy.swift`, `watchosTests/Support/CrashReportingSpy.swift` | 생성 | YJKit 테스트의 스파이 복사 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`, `watchosTests/…` | 수정 | non-fatal 테스트 |

---

### Task 0: Firebase 콘솔 + plist (사람이 한다) — 2026-09-28 콘솔·plist 완료

- [x] [console.firebase.google.com](https://console.firebase.google.com) → 프로젝트 추가 **Ralli** (Google Analytics 는 끈다 — Crashlytics 만 쓴다)
- [x] 앱 추가 → Apple → 번들 ID `com.yj.TennisCounter` → `GoogleService-Info.plist` 다운로드 → `Apps/TennisCounter/iOSApp/` 에 저장
- [x] 앱 추가 → Apple → 번들 ID `com.yj.TennisCounter.watchkitapp` → plist 다운로드 → `Apps/TennisCounter/WatchApp/` 에 저장
- [x] ~~두 앱 모두 왼쪽 메뉴 **Crashlytics → 시작하기** 눌러 활성화~~ — 지금 콘솔엔 버튼이 없다. SDK 가 첫 보고를 보내면 대시보드가 자동으로 켜진다 (Task 4 에서 확인)
- [x] `plutil -p Apps/TennisCounter/iOSApp/GoogleService-Info.plist | grep BUNDLE_ID` → `com.yj.TennisCounter` 인지, 워치 것은 `.watchkitapp` 인지 확인. **바뀌면 크래시가 엉뚱한 앱으로 간다**

synchronized group 이라 파일을 폴더에 두면 타깃에 자동 포함된다. `iOSApp/` 은 `TennisCounter` 에만, `WatchApp/` 은 워치 타깃에만 붙어 있어 섞이지 않는다 (2026-09-28 빌드 산출물에서 확인).

- [ ] **plist 는 커밋하지 않는다.** 새 체크아웃·워크트리에서는 콘솔 → 프로젝트 설정 → 내 앱에서 다시 받아 같은 자리에 넣는다
- [x] GCP 에서 API 키 제한 — iOS 앱(번들 ID 두 개) + API 목록에서 `Firebase AI Logic API` 제외 (09-28 완료. GitHub secret scanning 경고 #1 은 Revoked 로 닫음)

---

### Task 1: 타깃 설정 — 링크·초기화·dSYM

**Files:**
- Modify: `TennisCounter.xcodeproj/project.pbxproj` (Xcode UI)
- Modify: `iOSApp/iOSApp.swift`, `WatchApp/WatchApp.swift`

- [ ] **Step 1: `MonitoringCore` 링크**

Xcode → `TennisCounter` 타깃 → Frameworks, Libraries → `+` → YJKit `MonitoringCore`. `TennisCounter Watch App` 타깃도 동일. 익스텐션 2개는 **하지 않는다.**

- [ ] **Step 2: 앱 리포터 자리 + 진입점에서 초기화**

`Shared/Services/AppCrashReporter.swift` (iOS·워치 두 타깃이 공유하는 폴더):
```swift
import Foundation
import MonitoringCore

/// 앱이 쓰는 크래시 리포터 한 곳. 코어는 싱글톤을 두지 않으므로 어디에 들고 있을지는 앱이 정한다.
/// 진입점이 `start()` 를 부르기 전과 테스트 실행 중에는 Noop 이다.
enum AppCrashReporter {
    private(set) static var current: CrashReporting = NoopCrashReporter()

    /// 테스트 실행 중이면 건너뛴다 — 로컬엔 plist 가 있어 테스트가 실제 Firebase 로 브레드크럼을 보내게 된다.
    static func start() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        current = CrashlyticsReporter.start()
    }
}
```

`iOSApp/iOSApp.swift` — `init()` 첫 줄에 `AppCrashReporter.start()`.
`WatchApp/WatchApp.swift` — `@main` 구조체에 `init()` 이 없으면 만들어 `AppCrashReporter.start()`.
진입점은 `MonitoringCore` 를 import 하지 않아도 된다.

- [ ] **Step 3: dSYM 업로드 Build Phase — 두 타깃 각각**

타깃 → Build Phases → `+` → New Run Script Phase. 이름 `Upload dSYMs to Crashlytics`. **맨 아래**로 옮긴다 (dSYM 이 생성된 뒤 돌아야 한다).

```bash
# Release(Archive) 에서만. Debug 는 디버거가 붙어 리포트가 안 올라가니 의미 없다.
if [ "${CONFIGURATION}" != "Release" ]; then exit 0; fi
# plist 가 git 밖이라 빠진 채 아카이브될 수 있다. 그러면 앱은 Noop 으로 돌아 수집이 조용히 꺼진다 — 여기서 막는다.
PLIST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "error: GoogleService-Info.plist 가 번들에 없다 — Firebase 콘솔에서 받아 타깃 폴더에 넣는다"
  exit 1
fi
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

Input Files 에는 dSYM 한 줄만 둔다. **plist 는 넣지 않는다** — 넣으면 plist 가 없는 CI(Debug)에서 입력 파일 누락으로 빌드가 깨질 수 있다. 검사는 위 스크립트가 Release 에서만 한다.
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
```
`Crashlytics/run` 이 plist 를 입력 파일 없이 번들에서 찾는지는 Task 4 의 심볼 확인으로 검증한다. 못 찾으면 `-gsp` 인자로 위 `$PLIST` 를 넘긴다.

- [ ] **Step 4: 스크립트 샌드박스 끄기**

두 타깃 Build Settings → `User Script Sandboxing` → **No**. 지금 프로젝트에 `ENABLE_USER_SCRIPT_SANDBOXING = YES` 가 8곳 있다 — 앱 타깃 2개(Debug/Release = 4곳)만 바꾼다. `YES` 면 스크립트가 dSYM·plist 를 못 읽고 **로그 없이 실패**한다.

- [ ] **Step 5: 빌드 두 스킴**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -2
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -2
```
Expected: `BUILD SUCCEEDED` × 2. 실행하면 콘솔에 `[FirebaseCore][I-COR000001] ... Configuring the default app` 이 뜬다 — 뜨지 않으면 plist 가 타깃에 안 들어간 것.
plist 를 잠시 옮겨 두고 한 번 더 빌드·실행해 **죽지 않고 로그만 없는지**(Noop) 확인한다. CI 가 이 상태다.

- [ ] **Step 6: 커밋**

```bash
git add Apps/TennisCounter/TennisCounter.xcodeproj/project.pbxproj \
        Apps/TennisCounter/Shared/Services/AppCrashReporter.swift \
        Apps/TennisCounter/iOSApp/iOSApp.swift Apps/TennisCounter/WatchApp/WatchApp.swift \
        Apps/TennisCounter/CLAUDE.md   # plist 가 git 밖이라는 한 줄
git commit -m "🔧 iOS·워치에 MonitoringCore 링크 + Firebase 초기화 + dSYM 업로드"
```

---

### Task 2: iOS — 저장 실패 non-fatal + 브레드크럼

**Files:**
- Create: `iosTests/Support/CrashReportingSpy.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Produces: `WorkoutSessionViewModel.init(liveActivity:crashReporter: CrashReporting = AppCrashReporter.current)`

- [ ] **Step 1: 스파이**

`iosTests/Support/CrashReportingSpy.swift` — YJKit `Tests/MonitoringCoreTests/CrashReportingSpy.swift` 와 같은 내용, import 만 바꾼다:
```swift
import Foundation
import MonitoringCore

final class CrashReportingSpy: CrashReporting, @unchecked Sendable {
    enum Call: Equatable {
        case record(domain: String, code: Int, context: [String: String])
        case log(String)
    }

    private(set) var calls: [Call] = []

    func record(_ error: Error, context: [String: String]) {
        let ns = error as NSError
        calls.append(.record(domain: ns.domain, code: ns.code, context: context))
    }

    func log(_ message: String) {
        calls.append(.log(message))
    }
}
```

- [ ] **Step 2: 실패하는 테스트**

`WorkoutSessionViewModelTests.swift` 끝에:
```swift
    // MARK: - Crash reporting

    @Test @MainActor func localSaveFailureIsRecordedAsNonFatal() throws {
        let spy = CrashReportingSpy()
        let vm = WorkoutSessionViewModel(liveActivity: LiveActivitySpy(), crashReporter: spy)
        // MatchPersistenceService 를 실패하게 만드는 기존 헬퍼가 있으면 쓴다. 없으면
        // configure 를 안 한 상태(컨텍스트 nil)에서 upsert 가 throw 하는 경로를 쓴다 —
        // 이 파일의 saveCurrentMatchReturnsMatchOnSuccess 가 컨텍스트를 어떻게 세팅하는지 보고 반대로 한다.
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 3)])

        #expect(vm.saveCurrentMatch() == nil)
        let recorded = spy.calls.compactMap { call -> (String, Int, [String: String])? in
            if case let .record(domain, code, context) = call { return (domain, code, context) }
            return nil
        }
        #expect(recorded.count == 1)
        #expect(recorded.first?.0 == "Ralli.Save")
        #expect(recorded.first?.1 == 1)
        #expect(recorded.first?.2["source"] == "local")
    }

    @Test @MainActor func matchLifecycleLeavesBreadcrumbs() {
        let spy = CrashReportingSpy()
        let vm = WorkoutSessionViewModel(liveActivity: LiveActivitySpy(), crashReporter: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 3)])

        #expect(spy.calls.contains(.log("match started")))
        #expect(spy.calls.contains(.log("match finished")))
    }
```

- [ ] **Step 3: 실패 확인** — `extra argument 'crashReporter'`.

- [ ] **Step 4: 구현**

프로퍼티·init:
```swift
    private let crashReporter: CrashReporting

    init(liveActivity: LiveActivityControlling = LiveActivityService.shared,
         crashReporter: CrashReporting = AppCrashReporter.current)
    {
        self.liveActivity = liveActivity
        self.crashReporter = crashReporter
        setupScoreSync()
        setupConnectivityBindings()
    }
```
import 에 `MonitoringCore` (알파벳순).

`saveCurrentMatch` (작업 #1 이후 `-> Match?` 형태):
```swift
        do {
            crashReporter.log("save attempted (local)")
            try MatchPersistenceService.shared.upsert(match)
            return match
        } catch {
            crashReporter.record(
                MonitoringError(domain: "Ralli.Save", code: 1, message: "\(error)"),
                context: ["source": "local", "matchId": match.matchId?.uuidString ?? "nil"]
            )
            return nil
        }
```

`saveFromWatch`:
```swift
        var success = true
        crashReporter.log("save attempted (watch)")
        do { try MatchPersistenceService.shared.upsert(match) } catch {
            success = false
            crashReporter.record(
                MonitoringError(domain: "Ralli.Save", code: 2, message: "\(error)"),
                context: ["source": "watch", "sessionId": msg.sessionId.uuidString]
            )
        }
```

`startMatch` 본문 첫 줄에 `crashReporter.log("match started")`, `finishMatch` 의 `phase = .finished(...)` 직후 `crashReporter.log("match finished")`.

- [ ] **Step 5: 통과 → 린트 → 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift \
        Apps/TennisCounter/iosTests/Support/CrashReportingSpy.swift \
        Apps/TennisCounter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ iOS 경기 저장 실패를 non-fatal 로 기록 + 브레드크럼"
```

---

### Task 3: 워치 — ACK 타임아웃 non-fatal + 브레드크럼

**Files:**
- Create: `watchosTests/Support/CrashReportingSpy.swift` (Task 2 Step 1 과 동일 내용)
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Produces: `init(healthKit:metricsThrottle:ackTimeoutSeconds:haptics:crashReporter: CrashReporting = AppCrashReporter.current)` — `haptics` 는 작업 #3 에서 생긴 파라미터. #3 이 아직이면 그 자리 없이 추가한다.

- [ ] **Step 1: 실패하는 테스트**

```swift
    // MARK: - Crash reporting

    @Test @MainActor func saveAckTimeoutIsRecordedAsNonFatal() async throws {
        let spy = CrashReportingSpy()
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05, crashReporter: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()

        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(spy.calls.contains {
            if case let .record(domain, code, context) = $0 {
                return domain == "Ralli.Save" && code == 3 && context["sessionId"] == vm.activeSessionId.uuidString
            }
            return false
        })
    }

    @Test @MainActor func successfulAckIsNotRecorded() {
        let spy = CrashReportingSpy()
        let vm = WorkoutSessionViewModel(crashReporter: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))

        #expect(!spy.calls.contains { if case .record = $0 { return true }; return false })
    }
```

- [ ] **Step 2: 실패 확인 → 구현**

프로퍼티 `private let crashReporter: CrashReporting`, init 파라미터·대입 추가, import `MonitoringCore`.

타임아웃 클로저:
```swift
        DispatchQueue.main.asyncAfter(deadline: .now() + ackTimeoutSeconds) { [weak self] in
            guard let self, saveAttemptToken == token, saveAckState == .pending else { return }
            saveAckState = .failed
            crashReporter.record(
                MonitoringError(domain: "Ralli.Save", code: 3, message: "ack timeout after \(ackTimeoutSeconds)s"),
                context: ["sessionId": activeSessionId.uuidString]
            )
            haptics.play(.saveFailed)   // 작업 #3 이 있으면 이 줄이 이미 있다
        }
```

브레드크럼 — `startMatch` 첫 줄 `crashReporter.log("match started")`, `finishMatch` 의 `phase = .finished(session)` 직후 `crashReporter.log("match finished")`, `saveCurrentMatch` 의 `saveAckState = .pending` 직전 `crashReporter.log("save attempted")`.

- [ ] **Step 3: 워치 테스트 전체 + 린트 → 커밋**

```bash
git add Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift \
        Apps/TennisCounter/watchosTests/Support/CrashReportingSpy.swift \
        Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ 워치 저장 ACK 타임아웃을 non-fatal 로 기록 + 브레드크럼"
```

---

### Task 4: 실기기 검증 + App Store Connect (사람이 한다)

**강제 크래시** — 두 앱 각각. DEBUG 전용 임시 코드, 확인 후 **커밋 전에 제거**:
```swift
#if DEBUG
Button("Crash") { fatalError("crashlytics test") }
#endif
```
- [ ] iOS: 디버거 **없이** 실행(Xcode 에서 Run 후 Stop, 홈에서 앱 아이콘으로 실행) → Crash 탭 → 앱 재실행 → 1~5분 뒤 콘솔 Crashlytics 에 `fatalError("crashlytics test")` 가 **심볼 붙은 파일:줄** 로 보이는지. 심볼이 `<redacted>` 면 dSYM 업로드 실패 → Task 1 Step 3·4 재확인
- [ ] 워치: 같은 절차. 워치는 폰이 옆에 있어야 올라간다 — 재실행 후 폰 옆에서 몇 분 둔다.
      **안 올라오면 GCP 키의 iOS 번들 ID 제한부터 의심한다** — 워치 SDK 가 번들 ID 헤더를 보내는지는 여기서 처음 확인된다
- [ ] 임시 버튼 제거 확인: `git diff --stat` 에 Crash 버튼 없음

**plist 누락 방어**
- [ ] plist 를 잠시 옮기고 Release 아카이브 → dSYM 스크립트의 `error:` 로 **실패하는지**. 확인 후 되돌린다

**non-fatal**
- [ ] 폰 앱을 완전히 종료 → 워치에서 경기 저장 → 8초 뒤 "실패" → 콘솔 non-fatal 탭에 `Ralli.Save` code 3, 커스텀 키 `sessionId`
- [ ] 브레드크럼: 위 리포트의 Logs 탭에 `match started` → `match finished` → `save attempted` 순서

**App Store Connect**
- [ ] 앱 개인정보 → 데이터 유형 → **Crash Data** · **Other Diagnostic Data** 추가, "사용자에게 연결됨: 아니오", "추적: 아니오"
- [ ] Privacy Manifest 는 Firebase 가 자체 포함 — 아카이브 후 Xcode 의 Privacy Report 에 Crashlytics 항목이 보이면 됨

---

## 후속 (이번 커밋에 넣지 않는다)

- **수집 끄기 토글 (작업 #8)** — `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)`. `CrashlyticsReporter` 에 `static func setCollectionEnabled(_:)` 래퍼를 Kit 에 추가하고 설정 페이지가 부른다
- **non-fatal 확장** — WatchConnectivity 전송 실패, HealthKit 권한 거부. 첫 크래시 데이터를 본 뒤
- **골프·하루치 연동** — 이 플랜을 그대로 따라간다. Firebase 프로젝트는 앱마다 새로

## Self-Review

- 스펙 커버리지 — 범위(iOS+워치, 익스텐션 제외: 제약·Task 1), non-fatal 저장 실패 3곳(코드 표·Task 2·3), 앱 소유 항목(Task 0·1·4), dSYM 함정(Task 1 Step 3·4), 실기기 검증(Task 4), 수집 정책(후속) ✅
- 타입 일관성 — `CrashReporting.record(_:context:)`/`log(_:)`, `MonitoringError(domain:code:message:)`, `CrashlyticsReporter.start()` 가 Kit 구현(PR #35, 09-28 개정)과 일치 ✅. 스파이 `Call` 케이스가 iOS·워치 테스트에서 같은 모양 ✅
- 작업 #1(`saveCurrentMatch -> Match?`)·#3(`haptics`)과의 교차점을 각 스텝에 명시 ✅
- Task 2 Step 2 의 "저장 실패를 만드는 방법" 만 기존 테스트 파일을 보고 정하도록 열어 뒀다 — `MatchPersistenceService` 가 싱글톤이라 실패 주입 경로가 파일마다 다를 수 있다.
