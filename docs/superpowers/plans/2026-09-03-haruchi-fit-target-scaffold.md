# 하루치 핏 타깃 골격 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Apps/HaruchiFit/` 타깃 3개를 만들어 워크스페이스·린트·CI에 등록하고, 워치에서 워크아웃 세션을 실제로 돌려 `HKWorkoutActivity` 구간 기록이 동작하는지 실기기로 확인한다.

**Architecture:** 기존 GolfCounter의 타깃 구성(iOS 앱 + Watch App + 컴플리케이션 익스텐션)을 그대로 복제한다. 프로젝트 파일은 Xcode 16의 `PBXFileSystemSynchronizedRootGroup` 방식이라 폴더 스캔으로 빌드 대상이 정해지므로, 최초 생성 이후에는 pbxproj를 직접 편집하지 않는다. YJKit은 로컬 SPM 패키지로 참조해 수정이 즉시 반영된다.

**Tech Stack:** Swift 6 / SwiftUI · iOS 17.0 · watchOS 10.0 · HealthKit · SwiftData(+CloudKit) · WidgetKit · Xcode 16 FileSystemSynchronized 프로젝트

**Spec:**
- `docs/superpowers/specs/2026-09-02-haruchi-fit-product-spec.md` — 무엇을 만들지
- `docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md` — 어떻게 만들지 (결정 사항은 6절 D-M1~D-M7)

## 이 플랜의 범위

**포함** — 타깃 3개 생성, 워크스페이스·Makefile·CI 등록, 워치 세션 시작/종료 최소 동작, `HKWorkoutActivity` 실기기 검증.

**제외** (후속 플랜) — iOS 3탭 화면, 잔디 렌더링, SwiftData 모델과 HealthKit 동기화, 부위 태깅, 컴플리케이션 표시 로직, `WorkoutCore` 세그먼트 확장의 본구현, `WorkoutUI` 파라미터 추가(D-M1).

**이 플랜이 끝나면 무엇이 되는가** — 워치에서 운동을 시작하고 근력↔유산소를 전환한 뒤 종료하면, HealthKit에 구간이 나뉜 워크아웃이 저장된다. 화면은 최소 골격이고 폰 앱은 빈 껍데기다. **`HKWorkoutActivity`가 기대대로 동작하는지에 대한 답을 얻는 것이 이 플랜의 핵심 산출물이다** — 이 답에 따라 후속 플랜의 데이터 모델이 갈린다.

## Global Constraints

spec에서 가져온 프로젝트 전역 요구사항이다. **모든 태스크의 요구사항에 이 절이 암묵적으로 포함된다.**

- **배포 타깃** — iOS `17.0`, watchOS `10.0` (YJKit `Package.swift`의 `platforms`와 일치해야 한다)
- **번들 ID 규칙** — `com.yj.HaruchiFit` / `com.yj.HaruchiFit.watchkitapp` / `com.yj.HaruchiFit.watchkitapp.ComplicationApp`
- **타깃 이름** — `HaruchiFit` / `HaruchiFit Watch App` / `HaruchiComplicationExtension`
- **빌드는 워크스페이스 기준** — `-project`가 아니라 `-workspace YJApps.xcworkspace`를 쓴다
- **시뮬레이터는 이름이 아니라 UDID로 지정한다.** 같은 이름의 기기가 런타임별로 중복 존재한다.
  `.github/scripts/pick-simulator.sh <iOS|watchOS> <기기 이름 정규식>`이 UDID를 출력한다
- **브랜드 색** — `#FF9500` 오렌지(근력/브랜드), `#8CB4E8` 블루(유산소), `#FF453A` 심박
- **워크아웃 동작 계약 3조** (`CLAUDE.md`) — ① 칼로리는 워크아웃 누적값 ② 경과시간은 워치가 단일 소스, 폰은 `WorkoutAnchor.interpolatedElapsed(...)`로 보간 ③ pause는 폰→워치 명령, `isPaused`는 워치 앵커로만 갱신(낙관적 토글 금지)
- **`ConnectivityService`는 프로세스당 정확히 하나**, `onReceive` 등록은 생성한 main-queue turn 안에서 끝낸다
- **커밋 메시지는 gitmoji prefix** — ✨ feat / 🐛 fix / ♻️ refactor / 🎨 style / 📝 docs / ✅ test / 🔧 chore / 🔥 remove / ⏪ revert
- **`main` 직접 push 금지** — 브랜치 + PR, 머지는 일반 merge commit. 현재 작업 브랜치는 `feature/haruchi-fit`
- **pbxproj를 직접 편집하지 않는다** — Task 1의 최초 생성만 예외이며, 그것도 Xcode GUI가 수행한다

---

## File Structure

| 경로 | 책임 |
|---|---|
| `Apps/HaruchiFit/HaruchiFit.xcodeproj` | 프로젝트 파일. Task 1에서 Xcode가 생성한 뒤로는 손대지 않는다 |
| `Apps/HaruchiFit/iOSApp/` | iOS 앱. 이 플랜에서는 진입점만 |
| `Apps/HaruchiFit/WatchApp/` | 워치 앱. W0 홈 + 세션 화면 최소 골격 |
| `Apps/HaruchiFit/ComplicationApp/` | 컴플리케이션 익스텐션. 이 플랜에서는 빈 위젯 |
| `Apps/HaruchiFit/Shared/` | 워치 앱 ↔ 컴플리케이션 공유 타입. 위젯 타깃엔 테스트를 붙일 수 없어 로직을 여기 둔다 |
| `Apps/HaruchiFit/watchosTests/` | 워치 테스트 타깃 |
| `Apps/HaruchiFit/.swiftlint.yml` | 루트 `.swiftlint.yml`을 `parent_config`로 상속 |
| `Apps/HaruchiFit/.swiftformat` | 앱별 포맷 설정 |
| `YJApps.xcworkspace/contents.xcworkspacedata` | 프로젝트 등록 (수정) |
| `Makefile` | `APPS` 변수에 추가 (수정) |
| `.github/workflows/ci.yml` | 경로 필터 + 빌드 잡 추가 (수정) |

---

## Task 1: Xcode 프로젝트 생성 + 워크스페이스 등록

**Files:**
- Create: `Apps/HaruchiFit/HaruchiFit.xcodeproj` (Xcode GUI가 생성)
- Modify: `YJApps.xcworkspace/contents.xcworkspacedata`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: 워크스페이스에서 보이는 스킴 3개 — `HaruchiFit`, `HaruchiFit Watch App`, `HaruchiComplicationExtension`

> ⚠️ **이 태스크의 1단계는 사람이 Xcode GUI에서 수행해야 한다.** 새 프로젝트 생성·타깃 추가·빌드 설정은
> 에이전트가 대신할 수 없다. pbxproj를 손으로 쓰는 것은 1000줄 규모라 위험하고, 프로젝트 규약(`CLAUDE.md`)에도
> 어긋난다. 나머지 단계는 에이전트가 수행한다.

- [ ] **Step 1: Xcode에서 프로젝트를 생성한다 (사람이 수행)**

Xcode에서 `File > New > Project…`

1. **iOS > App** 선택
   - Product Name: `HaruchiFit`
   - Organization Identifier: `com.yj` (→ 번들 ID가 `com.yj.HaruchiFit`이 된다)
   - Interface: SwiftUI, Language: Swift
   - **Storage: None** (SwiftData는 나중에 `PersistenceCore`로 붙인다)
   - 저장 위치: `Apps/HaruchiFit/` — **`YJApps.xcworkspace`에 추가하지 않는다.** 독립 프로젝트로 만든 뒤 Step 3에서 등록한다

2. `File > New > Target…` → **watchOS > App**
   - Product Name: `HaruchiFit Watch App`
   - **Companion: `HaruchiFit`** 선택 (→ `WKCompanionAppBundleIdentifier`가 자동 설정된다)

3. `File > New > Target…` → **watchOS > Widget Extension**
   - Product Name: `HaruchiComplicationExtension`
   - **"Include Live Activity" 체크 해제**
   - Embed in: `HaruchiFit Watch App`

4. 배포 타깃을 맞춘다 — 전 타깃의 iOS는 `17.0`, watchOS는 `10.0`

5. 폴더 이름을 GolfCounter 규약에 맞춘다 (Xcode 기본 이름과 다르다):
   - iOS 앱 소스 폴더 → `iOSApp`
   - 워치 앱 소스 폴더 → `WatchApp`
   - 위젯 폴더 → `ComplicationApp`

- [ ] **Step 2: 생성 결과를 확인한다**

```bash
cd /Users/yj/orca/workspaces/yj-apps/haruchi-fit
ls Apps/HaruchiFit/
xcodebuild -project Apps/HaruchiFit/HaruchiFit.xcodeproj -list
```

Expected: 타깃 `HaruchiFit`, `HaruchiFit Watch App`, `HaruchiComplicationExtension`이 보인다.

번들 ID를 확인한다 (GolfCounter와 같은 형태여야 한다):

```bash
grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' \
  Apps/HaruchiFit/HaruchiFit.xcodeproj/project.pbxproj | sort -u
```

Expected: `com.yj.HaruchiFit`, `com.yj.HaruchiFit.watchkitapp`, `com.yj.HaruchiFit.watchkitapp.ComplicationApp`

다르면 Xcode의 각 타깃 `Build Settings > Product Bundle Identifier`에서 고친다.

- [ ] **Step 3: 워크스페이스에 등록한다**

`YJApps.xcworkspace/contents.xcworkspacedata`를 편집한다. 기존 두 `FileRef` 뒤에 추가:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:Apps/TennisCounter/TennisCounter.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:Apps/GolfCounter/GolfCounter.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:Apps/HaruchiFit/HaruchiFit.xcodeproj">
   </FileRef>
</Workspace>
```

- [ ] **Step 4: 스킴을 공유한다 (사람이 수행)**

CI는 스킴 이름으로 빌드하므로 **공유되지 않은 스킴은 CI에서 보이지 않는다.**

Xcode에서 `YJApps.xcworkspace`를 열고 `Product > Scheme > Manage Schemes…`
→ 세 스킴의 **Shared** 체크박스를 켠다.

- [ ] **Step 5: 워크스페이스에서 스킴이 보이는지 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -list
```

Expected: 기존 7개 + `HaruchiFit`, `HaruchiFit Watch App`, `HaruchiComplicationExtension` = **10개**

공유 스킴 파일이 실제로 생겼는지도 확인한다:

```bash
ls Apps/HaruchiFit/HaruchiFit.xcodeproj/xcshareddata/xcschemes/
```

Expected: `.xcscheme` 파일 3개. 비어 있으면 Step 4가 저장되지 않은 것이다.

- [ ] **Step 6: 빌드가 되는지 확인한다**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" \
  -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" \
  -destination "id=$WATCH" build
```

Expected: 둘 다 `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit YJApps.xcworkspace
git commit -m "✨ 하루치 핏 타깃 3개 생성 + 워크스페이스 등록

iOS 앱 · Watch App · 컴플리케이션 익스텐션을 GolfCounter와 같은 구성으로
만들고 워크스페이스에 등록한다. 스킴 3개를 공유해 CI가 이름으로 빌드할 수 있게 한다."
```

---

## Task 2: YJKit 프로덕트 연결 + HealthKit 권한 설정

**Files:**
- Modify: `Apps/HaruchiFit/HaruchiFit.xcodeproj` (Xcode GUI — 패키지 참조와 Capability)
- Create: `Apps/HaruchiFit/HaruchiFit.entitlements`
- Create: `Apps/HaruchiFit/HaruchiFit Watch App.entitlements`

**Interfaces:**
- Consumes: Task 1의 타깃 3개
- Produces: `import WorkoutCore` / `WorkoutUI` / `ConnectivityCore` / `PersistenceCore` / `WorkoutShareUI`가 컴파일되는 상태

- [ ] **Step 1: 로컬 패키지를 참조한다 (사람이 수행)**

Xcode에서 `HaruchiFit` 프로젝트 선택 → `Package Dependencies` 탭 → `+` → **Add Local…**
→ `Packages/YJKit` 폴더 선택

- [ ] **Step 2: 타깃별로 프로덕트를 링크한다 (사람이 수행)**

각 타깃의 `General > Frameworks, Libraries, and Embedded Content`에서 추가한다.
**아키텍처 문서 7절의 표 그대로다:**

| 타깃 | 링크할 프로덕트 |
|---|---|
| `HaruchiFit` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, WorkoutShareUI |
| `HaruchiFit Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| `HaruchiComplicationExtension` | (없음 — 로컬 스냅샷만 읽는다) |

- [ ] **Step 3: HealthKit Capability와 Info.plist 문구를 넣는다 (사람이 수행)**

`HaruchiFit`과 `HaruchiFit Watch App` 두 타깃에서 `Signing & Capabilities > + Capability > HealthKit`

그리고 각 타깃 `Build Settings > Info.plist Values`에 다음을 넣는다
(문구가 없으면 권한 요청 시 **크래시한다**):

| 키 | 값 |
|---|---|
| `NSHealthShareUsageDescription` | `운동 기록을 가져와 잔디를 채우기 위해 건강 앱 데이터를 읽습니다.` |
| `NSHealthUpdateUsageDescription` | `애플워치로 기록한 운동을 건강 앱에 저장합니다.` |

iOS 타깃에는 공유 딥링크용 키도 넣는다 — **빠지면 크래시가 아니라 조용히 공유 시트로 폴백되므로
나중에 원인을 찾기 어렵다** (아키텍처 D-M2):

| 키 | 값 |
|---|---|
| `LSApplicationQueriesSchemes` | 배열 1개 — `instagram-stories` |

- [ ] **Step 4: 임포트가 되는지 확인한다**

`Apps/HaruchiFit/WatchApp/` 안의 앱 진입점 파일 맨 위에 임시로 임포트를 추가한다:

```swift
import ConnectivityCore
import WorkoutCore
import WorkoutUI
```

빌드한다:

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" \
  -destination "id=$WATCH" build
```

Expected: `** BUILD SUCCEEDED **`
실패하면 `No such module` 메시지가 가리키는 프로덕트가 Step 2에서 빠진 것이다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/HaruchiFit
git commit -m "🔧 YJKit 프로덕트 연결 + HealthKit 권한 문구 추가

아키텍처 문서 7절의 타깃별 프로덕트 표대로 링크한다.
LSApplicationQueriesSchemes 누락은 크래시가 아니라 조용한 폴백이라
지금 함께 넣어 나중에 원인을 찾는 비용을 없앤다."
```

---

## Task 3: 린트·포맷 설정 + Makefile 등록

**Files:**
- Create: `Apps/HaruchiFit/.swiftlint.yml`
- Create: `Apps/HaruchiFit/.swiftformat`
- Modify: `Makefile:1`

**Interfaces:**
- Consumes: Task 1의 폴더 구조 (`iOSApp`, `WatchApp`, `ComplicationApp`, `Shared`)
- Produces: `make lint` / `make format` / `make fix`가 하루치 핏을 순회한다

- [ ] **Step 1: `.swiftlint.yml`을 만든다**

`Apps/HaruchiFit/.swiftlint.yml`:

```yaml
parent_config: ../../.swiftlint.yml

# included 는 이 앱 디렉터리 기준 상대 경로다. 앱 폴더에서 swiftlint 를 실행한다.
included:
  - iOSApp
  - WatchApp
  - ComplicationApp
  - Shared
```

- [ ] **Step 2: `.swiftformat`을 만든다**

GolfCounter의 설정을 기준으로 복사하되 `--swiftversion`은 **6.0**으로 둔다
(신규 앱이므로 낮은 버전을 물려받을 이유가 없다):

```bash
cp Apps/GolfCounter/.swiftformat Apps/HaruchiFit/.swiftformat
```

그리고 `--swiftversion` 줄을 `6.0`으로 고친다. 현재 값 확인:

```bash
grep -n 'swiftversion' Apps/HaruchiFit/.swiftformat
```

- [ ] **Step 3: Makefile에 앱을 추가한다**

`Makefile:1`을 고친다:

```makefile
APPS := GolfCounter TennisCounter HaruchiFit
```

- [ ] **Step 4: 린트가 도는지 확인한다**

```bash
make lint
make format
```

Expected: 세 앱이 순회되고 `==> HaruchiFit` 이 출력된다. 위반이 있으면 `make fix`로 고친다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/HaruchiFit/.swiftlint.yml Apps/HaruchiFit/.swiftformat Makefile
git commit -m "🔧 하루치 핏 린트·포맷 설정 추가

루트 .swiftlint.yml 을 parent_config 로 상속하고 앱 고유 included 만 둔다.
swiftversion 은 6.0 — 신규 앱이라 낮은 버전을 물려받을 이유가 없다."
```

---

## Task 4: CI 등록

**Files:**
- Modify: `.github/workflows/ci.yml` — 변경 판별 블록(`:81` 부근)과 빌드 잡

**Interfaces:**
- Consumes: Task 1의 스킴 3개, Task 3의 린트 설정
- Produces: PR에서 `Apps/HaruchiFit/**` 변경 시 하루치 핏만 빌드되고, `Packages/YJKit/` 변경 시 세 앱이 전부 빌드된다

- [ ] **Step 1: 현재 판별 로직을 읽는다**

```bash
sed -n '70,95p' .github/workflows/ci.yml
```

`golf`, `tennis` 두 플래그가 어떻게 세팅되는지 확인한다. 하루치 핏은 같은 패턴을 따른다.

- [ ] **Step 2: 판별 블록에 `haruchi` 플래그를 추가한다**

기본값 선언부(`kit=`, `golf=`, `tennis=`가 초기화되는 곳)와 base 미확인 폴백에
`haruchi`를 함께 넣는다. 그리고 경로 필터를 추가한다:

```bash
            if echo "$relevant" | grep -qE '^Apps/TennisCounter/'; then
              tennis=true
            fi
            if echo "$relevant" | grep -qE '^Apps/HaruchiFit/'; then
              haruchi=true
            fi
```

`GITHUB_OUTPUT` 블록에도 추가한다:

```bash
          {
            echo "kit=$kit"
            echo "golf=$golf"
            echo "tennis=$tennis"
            echo "haruchi=$haruchi"
          } >> "$GITHUB_OUTPUT"
          echo "판별 결과 — kit=$kit golf=$golf tennis=$tennis haruchi=$haruchi"
```

**루트 설정 변경(`^(\.github/|Makefile|\.swiftlint\.yml|YJApps\.xcworkspace/)`)과
코어 변경(`^Packages/YJKit/`)에서 `haruchi=true`도 함께 세팅해야 한다** — 빠뜨리면
YJKit을 고쳐도 하루치 핏이 빌드되지 않아 회귀를 놓친다.

- [ ] **Step 3: 린트 잡 조건에 추가한다**

`lint` 잡의 `if:` 조건에 하루치 핏을 넣는다:

```yaml
    if: needs.changes.outputs.golf == 'true' || needs.changes.outputs.tennis == 'true' || needs.changes.outputs.haruchi == 'true'
```

- [ ] **Step 4: 빌드 잡을 추가한다**

GolfCounter 빌드 잡(`:180` 부근)을 본떠 하루치 핏 잡을 만든다. 스킴 3개를 빌드한다:

```yaml
          xcodebuild -workspace "$WORKSPACE" -scheme "HaruchiFit" \
            -destination "id=$IOS" build
          xcodebuild -workspace "$WORKSPACE" -scheme "HaruchiFit Watch App" \
            -destination "id=$WATCH" build
          xcodebuild -workspace "$WORKSPACE" -scheme "HaruchiComplicationExtension" \
            -destination "id=$WATCH" build
```

시뮬레이터 선택은 기존 잡과 동일하게 `pick-simulator.sh`를 쓴다 — **이름으로 지정하지 않는다.**

- [ ] **Step 5: 판별 로직을 로컬에서 검증한다**

CI를 돌리지 않고 grep 패턴만 따로 확인한다:

```bash
# 하루치 핏만 바뀐 경우 → haruchi 만 true 여야 한다
echo "Apps/HaruchiFit/WatchApp/App.swift" | grep -qE '^Apps/HaruchiFit/' && echo "haruchi=true"
echo "Apps/HaruchiFit/WatchApp/App.swift" | grep -qE '^Apps/GolfCounter/' || echo "golf=false (정상)"

# 문서만 바뀐 경우 → 전부 스킵되어야 한다
echo "docs/superpowers/plans/x.md" | grep -vE '(^|/)docs/|\.md$' || echo "문서만 — 스킵 (정상)"

# YJKit 변경 → 전 앱 빌드
echo "Packages/YJKit/Sources/WorkoutCore/X.swift" | grep -qE '^Packages/YJKit/' && echo "kit+golf+tennis+haruchi=true"
```

Expected: 각 줄의 `(정상)` 표시가 그대로 출력된다.

- [ ] **Step 6: YAML 문법을 확인한다**

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
```

Expected: `YAML OK`

- [ ] **Step 7: 커밋**

```bash
git add .github/workflows/ci.yml
git commit -m "👷 CI에 하루치 핏 빌드 등록

경로 필터에 Apps/HaruchiFit/ 을 추가하고 스킴 3개를 빌드한다.
루트 설정·YJKit 변경 시에도 haruchi=true 로 세팅한다 — 빠뜨리면
코어를 고쳐도 하루치 핏 회귀를 놓친다."
```

---

## Task 5: 워치 세션 최소 골격 — 시작과 종료

**Files:**
- Create: `Apps/HaruchiFit/WatchApp/HaruchiFitApp.swift` (Xcode 기본 진입점을 대체)
- Create: `Apps/HaruchiFit/WatchApp/WorkoutViewModel.swift`
- Create: `Apps/HaruchiFit/WatchApp/HomeView.swift`

**Interfaces:**
- Consumes: `WorkoutSessionService(configuration:)`, `WorkoutConfiguration(activityType:locationType:)`, `WorkoutMetricsView(metrics:isPaused:)`, `WorkoutControlsView(isPaused:isPauseAvailable:onPauseResume:onEnd:)` — 전부 YJKit 기존 API
- Produces: `WorkoutViewModel` — `start()`, `end() async`, `@Published var isActive: Bool`. Task 6이 여기에 구간 전환을 얹는다

> `WorkoutSessionService`는 **싱글톤이 아니다.** 앱 루트에서 한 번 만들어 주입한다 (YJKit README).

- [ ] **Step 1: ViewModel을 만든다**

`Apps/HaruchiFit/WatchApp/WorkoutViewModel.swift`:

```swift
import Foundation
import WorkoutCore

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var isActive = false

    let session: WorkoutSessionService

    init() {
        // 근력 세션으로 시작한다. 유산소 전환은 Task 6에서 구간으로 다룬다.
        session = WorkoutSessionService(
            configuration: WorkoutConfiguration(activityType: .traditionalStrengthTraining,
                                                locationType: .indoor)
        )
    }

    func requestAuthorization() async -> Bool {
        await session.requestAuthorization()
    }

    func start() {
        session.startWorkout()
        isActive = true
    }

    func end() async -> WorkoutResult? {
        let result = await session.stopWorkout()
        isActive = false
        return result
    }

    /// `WorkoutSessionService`는 조립된 `WorkoutMetrics`를 노출하지 않는다 —
    /// 개별 @Published 값만 있으므로 여기서 뷰가 쓸 형태로 만든다.
    /// 총 칼로리는 활동 + 휴식이다 (YJKit README).
    var metrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(session.elapsedSeconds),
                       activeCalories: session.currentCalories,
                       totalCalories: session.currentCalories + session.currentBasalCalories,
                       heartRate: session.currentHeartRate)
    }
}
```

> `session.elapsedSeconds`는 `Int`이고 `WorkoutMetrics.elapsedSeconds`는 `TimeInterval`이다 —
> 변환이 필요하다.

- [ ] **Step 2: 홈 화면을 만든다**

`Apps/HaruchiFit/WatchApp/HomeView.swift`:

```swift
import SwiftUI
import WorkoutUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: WorkoutViewModel

    var body: some View {
        if viewModel.isActive {
            TabView {
                WorkoutMetricsView(metrics: viewModel.metrics,
                                   isPaused: viewModel.session.isPaused)
                WorkoutControlsView(
                    isPaused: viewModel.session.isPaused,
                    onPauseResume: {
                        viewModel.session.isPaused
                            ? viewModel.session.resumeWorkout()
                            : viewModel.session.pauseWorkout()
                    },
                    onEnd: { Task { _ = await viewModel.end() } }
                )
            }
            .tabViewStyle(.verticalPage)
        } else {
            VStack(spacing: 12) {
                Text("Haruchi Fit")
                    .font(.headline)
                    .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.0)) // #FF9500
                Button("운동 시작") { viewModel.start() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

> `WorkoutMetricsView`가 표시하는 항목은 **경과시간 · 활동 kcal · 총 kcal · BPM 4개로 고정**이다 —
> 뷰가 라벨과 색을 소유하므로 앱이 문자열을 관리하지 않는다 (YJKit README).
> 목업이 요구하는 상단 모드 라벨(`진행 중 · 근력`)은 이 플랜에 없다 — D-M1의 파라미터 추가 작업이며 후속 플랜이다.

- [ ] **Step 3: 진입점에서 ViewModel을 주입한다**

`Apps/HaruchiFit/WatchApp/HaruchiFitApp.swift`:

```swift
import SwiftUI

@main
struct HaruchiFitWatchApp: App {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .task { _ = await viewModel.requestAuthorization() }
        }
    }
}
```

Xcode가 만든 기본 진입점 파일(`HaruchiFit_Watch_AppApp.swift` 등)이 남아 있으면 **삭제한다** —
`@main`이 둘이면 컴파일 에러가 난다.

- [ ] **Step 4: 빌드한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" \
  -destination "id=$WATCH" build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 실기기에서 동작을 확인한다 (사람이 수행)**

> **시뮬레이터로는 검증할 수 없다.** HealthKit 워크아웃 세션은 실기기에서만 정상 동작한다.

애플워치에 설치하고:
1. 앱을 열어 HealthKit 권한을 허용한다
2. `운동 시작`을 누른다 → 지표 화면에 **경과시간이 흐르고 심박이 잡히는지** 본다
3. 컨트롤 페이지에서 `운동 종료`를 누른다
4. **건강 앱 > 운동**에서 방금 세션이 저장됐는지 확인한다

- [ ] **Step 6: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp
git commit -m "✨ 워치 워크아웃 세션 최소 골격

WorkoutSessionService 를 앱 루트에서 만들어 주입하고, YJKit 의
WorkoutMetricsView·WorkoutControlsView 로 세션 화면을 구성한다.
근력 세션으로 고정 — 유산소 전환은 다음 태스크에서 구간으로 다룬다."
```

---

## Task 6: `HKWorkoutActivity` 실기기 검증 (스파이크)

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/WorkoutViewModel.swift`
- Modify: `docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md` — 2절·3절에 결과 반영

**Interfaces:**
- Consumes: Task 5의 `WorkoutViewModel`
- Produces: **아키텍처 문서 2절의 "검증 필요" 표시를 사실로 대체한 결과.** 후속 플랜의 데이터 모델이 여기에 달려 있다

> **이건 스파이크다.** 목표는 기능 완성이 아니라 **답을 얻는 것**이다.
> `HKWorkoutActivity`가 기대대로 동작하면 세그먼트를 HealthKit에 남기고,
> 아니면 SwiftData 전용으로 폴백한다 (아키텍처 2절).
> **검증이 끝나면 이 태스크의 임시 UI는 되돌린다.**

- [ ] **Step 1: 독립 스파이크 파일을 만든다**

`WorkoutSessionService`는 `HKWorkoutSession`을 **private으로 감추고 있어** 밖에서 구간 전환을 걸 수 없다.
패키지를 고치는 건 검증 결과가 나온 뒤이므로(아키텍처 2절 "WorkoutCore에 필요한 확장"),
**스파이크는 서비스를 쓰지 않고 자기 세션을 직접 만든다.** Task 5의 코드는 건드리지 않는다.

`Apps/HaruchiFit/WatchApp/SegmentSpike.swift`:

```swift
import Foundation
import HealthKit

/// 스파이크 전용 — HKWorkoutActivity 구간이 실제로 저장되는지 확인한다.
/// 검증이 끝나면 이 파일을 통째로 삭제한다.
@MainActor
final class SegmentSpike: NSObject, ObservableObject {
    @Published private(set) var log: [String] = []

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start() {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self

            let now = Date()
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { _, _ in }

            self.session = session
            self.builder = builder
            append("세션 시작 (근력)")
        } catch {
            append("세션 생성 실패: \(error)")
        }
    }

    /// 유산소 구간을 연다. `beginNewActivity`는 비동기이며 실제 시작은 델리게이트가 알려준다.
    func beginCardio() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .indoor
        session?.beginNewActivity(configuration: config, date: Date(), metadata: nil)
        append("유산소 구간 요청")
    }

    /// 현재 구간을 닫는다. 헤더에 따르면 **메인 세션 활동(근력)으로 되돌아간다.**
    func endCurrentActivity() {
        session?.endCurrentActivity(on: Date())
        append("구간 종료 요청 → 메인(근력) 복귀 예상")
    }

    func end() async {
        guard let session, let builder else { return }
        let endDate = Date()
        session.end()
        await withCheckedContinuation { continuation in
            builder.endCollection(withEnd: endDate) { _, _ in continuation.resume() }
        }
        try? await builder.finishWorkout()
        append("세션 종료")
        await inspectLastWorkout()
    }

    private func append(_ line: String) {
        log.append("\(Date().formatted(date: .omitted, time: .standard)) \(line)")
        print("[SPIKE] \(line)")
    }
}

extension SegmentSpike: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didChangeTo _: HKWorkoutSessionState,
                                    from _: HKWorkoutSessionState,
                                    date _: Date) {}

    nonisolated func workoutSession(_: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in append("세션 실패: \(error)") }
    }

    /// 구간이 실제로 시작된 시점 — 요청과 이 콜백 사이의 지연이 검증 포인트다.
    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didBeginActivityWith configuration: HKWorkoutConfiguration,
                                    date: Date) {
        Task { @MainActor in
            append("구간 시작됨: type=\(configuration.activityType.rawValue) at \(date)")
        }
    }

    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didEndActivityWith configuration: HKWorkoutConfiguration,
                                    date: Date) {
        Task { @MainActor in
            append("구간 종료됨: type=\(configuration.activityType.rawValue) at \(date)")
        }
    }
}
```

> **`endCurrentActivity(on:)`의 의미에 주의한다.** SDK 헤더는 이 메서드가 구간을 끝내고
> **"메인 세션 활동으로 되돌아간다"**(reverting to the main session activity)고 설명한다.
> 즉 근력으로 돌아가는 방법이 두 가지다 — ① `endCurrentActivity`로 메인(근력)에 복귀
> ② `beginNewActivity(.traditionalStrengthTraining)`로 새 구간을 염.
> **둘 중 어느 쪽이 워크아웃에 구간을 제대로 남기는지가 이 스파이크의 핵심 확인 사항이다.**

**API는 SDK 헤더에서 확인했다** (`WatchOS26.5.sdk/…/HealthKit.framework/Headers/`):

| 심볼 | 가용성 | 용도 |
|---|---|---|
| `HKWorkoutSession.beginNewActivity(configuration:date:metadata:)` | watchOS 9.0+ / iOS 17.0+ | **라이브 세션의 구간 시작 — 이걸 쓴다** |
| `HKWorkoutSession.endCurrentActivity(on:)` | watchOS 9.0+ / iOS 17.0+ | 현재 구간 종료 |
| `HKWorkout.workoutActivities` | watchOS 9.0+ | 저장된 워크아웃에서 구간 되읽기 |
| `HKWorkoutBuilder.addWorkoutActivity(_:completion:)` | watchOS 9.0+ | 수동 빌더용 — **여기서는 쓰지 않는다** |

배포 타깃이 watchOS 10.0이므로 **가용성 문제는 없다.**

> ⚠️ **API가 존재하는 것과 기대대로 동작하는 것은 다른 문제다.** 이 스파이크가 확인하려는 것은
> 후자다 — 구간이 실제로 저장되는지, 시각이 정확한지, 짧은 구간이 버려지지 않는지.

- [ ] **Step 2: 저장된 워크아웃을 되읽는 코드를 넣는다**

`SegmentSpike`에 추가한다. 세션 종료 직후 방금 저장된 워크아웃을 다시 읽어 구간이 남았는지 본다:

```swift
extension SegmentSpike {
    func inspectLastWorkout() async {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil,
                                  limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let workout = samples?.first as? HKWorkout else {
                Task { @MainActor in self?.append("워크아웃 없음") }
                return
            }
            let activities = workout.workoutActivities
            Task { @MainActor in
                self?.append("전체 \(Int(workout.duration))초 · 구간 \(activities.count)개")
                for (i, a) in activities.enumerated() {
                    let type = a.workoutConfiguration.activityType.rawValue
                    let end = a.endDate.map { "\($0)" } ?? "nil"
                    self?.append("  [\(i)] type=\(type) \(a.startDate) → \(end)")
                }
            }
        }
        store.execute(query)
    }
}
```

- [ ] **Step 3: 스파이크 화면을 임시로 붙인다**

`HomeView`에 스파이크 진입 버튼을 하나 두고, 그 화면에 버튼 4개와 로그를 띄운다.
**디자인은 신경 쓰지 않는다 — 누를 수 있고 로그가 보이면 된다.**

```swift
struct SpikeView: View {
    @StateObject private var spike = SegmentSpike()

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Button("시작(근력)") { spike.start() }
                Button("유산소 구간") { spike.beginCardio() }
                Button("구간 종료") { spike.endCurrentActivity() }
                Button("세션 종료") { Task { await spike.end() } }
                ForEach(spike.log, id: \.self) { line in
                    Text(line).font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
```

- [ ] **Step 4: 실기기에서 시나리오 A를 실행한다 (사람이 수행)**

**시나리오 A — `endCurrentActivity`로 복귀:**

1. `시작(근력)` → **1분 이상** 기다린다 (짧은 구간은 HealthKit이 버릴 수 있다)
2. `유산소 구간` → 1분 이상
3. `구간 종료` (메인 근력으로 복귀) → 1분 이상
4. `세션 종료`

로그의 `구간 N개`와 각 구간 시각을 기록한다.

- [ ] **Step 5: 시나리오 B를 실행한다 (사람이 수행)**

**시나리오 B — `beginNewActivity`로 근력 구간을 다시 염:**

1. `시작(근력)` → 1분 이상
2. `유산소 구간` → 1분 이상
3. **`유산소 구간` 대신 근력으로 `beginNewActivity`를 부르도록** Step 1의 `beginCardio()`를
   복사해 `beginStrength()`를 만들고 버튼을 추가한 뒤, 그걸 누른다 → 1분 이상
4. `세션 종료`

- [ ] **Step 6: 두 시나리오를 비교해 판정한다**

**성공 판정:** 두 시나리오 중 **적어도 하나**에서 `구간 3개`가 나오고,
activityType이 근력(`.traditionalStrengthTraining` = **50**) → 유산소(`.running` = **37**) → 근력 순이며,
각 구간의 시작·종료 시각이 실제 버튼을 누른 시점과 맞는다.

**실패 판정:** 두 시나리오 모두 구간이 0개 또는 1개다. 또는 시각이 크게 어긋난다.

**어느 쪽이 됐든 성공한 시나리오를 기록한다** — 후속 플랜의 `WorkoutCore` 확장이 그 방식을 따른다.

- [ ] **Step 7: 결과를 아키텍처 문서에 반영한다**

`docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md`를 고친다.

**성공했다면** 2절의 "검증 필요" 블록을 실측 결과로 바꾼다 — 확인한 SDK 시그니처,
구간 수, 시각 정확도, 검증한 watchOS 버전과 기기를 적는다. 폴백 문단은 남기되
"검증 통과로 불필요"라고 표시한다.

**실패했다면** 2절을 폴백 확정으로 바꾸고, **3절 데이터 모델 표에서 세그먼트 행을
`⚠️ HKWorkoutActivity (검증 필요)` → `❌ 없음`으로, SwiftData 열을 `✅ 원본`으로 고친다.**
9절 리스크 표의 해당 행도 "발생함 — 폴백 적용"으로 갱신한다.

- [ ] **Step 8: 스파이크 코드를 되돌린다**

`SegmentSpike.swift`와 `SpikeView`, `HomeView`의 진입 버튼을 **전부 삭제한다.**
**검증으로 얻은 지식은 문서에 남고, 임시 코드는 남기지 않는다.**

```bash
rm Apps/HaruchiFit/WatchApp/SegmentSpike.swift
```

`HomeView`에서 스파이크 진입 버튼을 지웠는지 확인한다:

```bash
grep -rn 'SegmentSpike\|SpikeView' Apps/HaruchiFit/ || echo "스파이크 코드 없음 (정상)"
```

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" \
  -destination "id=$WATCH" build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 커밋**

```bash
git add -A Apps/HaruchiFit docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md
git commit -m "📝 HKWorkoutActivity 구간 기록을 실기기로 검증

세그먼트를 HealthKit 에 남길 수 있는지 확인하고 결과를 아키텍처 문서
2·3절에 실측으로 기록한다. 후속 플랜의 데이터 모델이 이 답에 달려 있었다.
스파이크 코드는 되돌리고 지식만 문서에 남긴다."
```

---

## 완료 조건

- [ ] `xcodebuild -workspace YJApps.xcworkspace -list`에 스킴 **10개**가 보인다
- [ ] 세 스킴이 전부 빌드된다 (`HaruchiFit`, `HaruchiFit Watch App`, `HaruchiComplicationExtension`)
- [ ] `make lint`와 `make format`이 하루치 핏을 순회하고 통과한다
- [ ] `make kit-test`가 여전히 통과한다 (26 tests — YJKit을 건드리지 않았으므로 회귀가 없어야 한다)
- [ ] CI 판별 로직이 `Apps/HaruchiFit/**` 변경에 반응한다
- [ ] **실기기에서** 워치 앱이 워크아웃을 시작·종료하고 건강 앱에 기록이 남는다
- [ ] **`HKWorkoutActivity` 검증 결과가 아키텍처 문서에 실측으로 기록됐다**

## 다음 플랜

이 플랜이 끝나면 검증 결과에 따라 갈린다.

1. **`WorkoutCore` 세그먼트 확장** — Task 6 결과를 반영한 본구현. 기존 두 앱 회귀 검증 포함
2. **`WorkoutUI` 파라미터 추가** (D-M1) — 모드 라벨 + 전환 행. 색 처리 결정 포함
3. **SwiftData 모델 + HealthKit 동기화** — 아키텍처 3·4절
4. **iOS 3탭 화면** — 홈 잔디, 기록, 통계
5. **컴플리케이션 표시 로직** — `Shared/`에 두고 워치 테스트에서 검증
