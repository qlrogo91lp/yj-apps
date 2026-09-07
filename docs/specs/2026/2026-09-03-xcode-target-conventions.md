# Xcode 앱·타깃 구성 규약

세 앱(GolfCounter / TennisCounter / HaruchiFit)이 같은 골격을 쓴다. 새 앱이나 타깃을 추가할 때
**Xcode GUI의 기본값이 규약과 어긋나는 지점은 정해져 있고, 그중 몇 개는 빌드가 통과하므로 조용히 넘어간다.**

이 문서는 그 지점들과 검증 방법을 모은다. 2026-09-03 하루치 핏 타깃 생성에서 실제로 걸린 것들이 근거다.

관련 문서 — `2026-08-27-monorepo-migration-design.md`(구조) · `2026-08-27-ci-pipeline-design.md`(CI) ·
`2026-08-27-code-style-tooling-design.md`(린트)

---

## 1. 이름 규약

| | GolfCounter | TennisCounter | HaruchiFit |
|---|---|---|---|
| iOS 타깃 | `GolfCounter` | `TennisCounter` | `HaruchiFit` |
| 워치 타깃 | `GolfCounter Watch App` | `TennisCounter Watch App` | `HaruchiFit Watch App` |
| 컴플리케이션 타깃 | `ComplicationAppExtension` | `ComplicationAppExtension` | `HaruchiComplicationExtension` |
| 컴플리케이션 **스킴** | `GolfComplicationExtension` | `RalliComplicationExtension` | `HaruchiComplicationExtension` |
| 워치 테스트 | `GolfCounterWatchTests` | `RalliWatchTests` | `HaruchiFitWatchTests` |

**컴플리케이션은 두 앱과 하루치 핏이 다르다.** Golf·Tennis는 타깃 이름(`ComplicationAppExtension`)과
스킴 이름(`GolfComplicationExtension`)이 갈라져 있다 — 출시 산출물명을 유지하려고 그렇게 뒀다.
하루치 핏은 신규라 그럴 이유가 없어 **타깃과 스킴 이름을 일치**시켰다. 스킴 이름은 앱마다 유일해야 하므로
(CI가 워크스페이스 전체에서 이름으로 찾는다) `ComplicationAppExtension` 같은 공용 이름을 스킴에 쓸 수 없다.

### 번들 ID

```
com.yj.<앱>
com.yj.<앱>.watchkitapp
com.yj.<앱>.watchkitapp.<컴플리케이션>
com.yj.<테스트 타깃 이름>
```

컴플리케이션의 마지막 조각은 Golf·Haruchi가 `ComplicationApp`, Tennis만 `widget` 이다. 통일되어 있지 않다.

### 함정 — watchOS App 타깃은 Product Name에 `" Watch App"` 을 자동으로 덧붙인다

생성 시트에 `HaruchiFit Watch App` 을 입력하면 타깃 이름이 **`HaruchiFit Watch App Watch App`** 이 된다.
**`HaruchiFit` 만 입력해야** `HaruchiFit Watch App` 이 나온다.

Widget Extension도 마찬가지로 `"Extension"` 을 덧붙인다 — `HaruchiComplicationExtension` 을 입력하면
스킴/`productName` 이 `HaruchiComplicationExtensionExtension` 이 된다.

이걸 놓치면 rename을 해야 하고, rename은 §3의 문제를 부른다. **생성 시점에 이름을 맞추는 것이 가장 싸다.**

---

## 2. 폴더 규약 — `PBXFileSystemSynchronizedRootGroup`

Xcode 16의 동기화 폴더 방식을 쓴다. 폴더가 곧 빌드 대상이라 **Swift 파일을 만들거나 지울 때
pbxproj를 건드릴 필요가 없다.**

| 폴더 | 소속 타깃 |
|---|---|
| `iOSApp/` | iOS 앱 |
| `WatchApp/` | 워치 앱 |
| `ComplicationApp/` | 컴플리케이션 |
| `Shared/` | iOS 앱 + 워치 앱 + 컴플리케이션 (§9) |
| `iosTests/` `watchosTests/` | 각 테스트 타깃 |

**폴더 rename은 반드시 Xcode 네비게이터에서 한다.** Finder에서 바꾸면 pbxproj의 `path = ` 가 남아
빌드 입력을 못 찾는다. 파일 추가·삭제는 파일시스템만 건드려도 된다.

### 파일 단위로 소속을 빼려면 — `membershipExceptions`

폴더는 타깃에 통째로 붙지만, 특정 파일만 특정 타깃에서 뺄 수 있다. GolfCounter가 그렇게 쓴다:

```
membershipExceptions = ( Services/ConnectivityMessages.swift );
target = ComplicationAppExtension
```

컴플리케이션은 WatchConnectivity를 쓰지 않으므로 그 파일만 빠진다.
Xcode에서는 파일을 고르고 우측 File Inspector의 **Target Membership** 체크를 끄면 된다.

---

## 3. ⚠️ rename이 갱신하지 않는 설정

**이 절이 이 문서의 핵심이다.** Xcode의 타깃·폴더 rename은 `name`·`productName`·product reference·
스킴 이름까지는 따라오지만, **경로가 문자열로 박힌 빌드 설정은 그대로 둔다.**

| 설정 | 가리키는 것 | 어긋났을 때 증상 |
|---|---|---|
| `TEST_HOST` | 호스트 앱 실행파일 경로 | General > Host Application 이 **`Custom`으로 회색 처리**되어 드롭다운이 잠긴다. 테스트 실행 실패 |
| `INFOPLIST_FILE` | Info.plist 경로 | `error: Build input file cannot be found`. 타깃 태스크가 취소되며 **`Command Ld failed` 가 딸려 나온다** — Ld 쪽을 파면 헛수고다 |
| `productName` / `remoteInfo` | 표시용 | 빌드에 영향 없음. 무시해도 된다 |

`TEST_HOST` 가 잠겼을 때는 General 탭에서 못 고친다. **Build Settings > `Test Host`** 에서
값을 지워 초기화하거나 직접 교체한다:

```
$(BUILT_PRODUCTS_DIR)/<앱> Watch App.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/<앱> Watch App
```

### 검증 — rename 뒤에 이걸 돌린다

```bash
APP=HaruchiFit
P=Apps/$APP/$APP.xcodeproj/project.pbxproj
grep -oE '(TEST_HOST|INFOPLIST_FILE) = [^;]+;' $P | sort -u
sed -n '/Begin PBXFileSystemSynchronizedRootGroup/,/End PBXFileSystemSynchronizedRootGroup/p' $P \
  | grep -oE 'path = [^;]+;'
```

출력된 경로가 실제 폴더 이름과 맞는지 눈으로 확인한다.

---

## 4. 스킴은 **공유**해야 커밋된다

`.gitignore` 에 `xcuserdata/` 가 있다. 스킴의 기본 저장 위치가 거기라
**공유하지 않은 스킴은 저장소에 들어가지 않고, CI 러너에는 존재하지 않는다.**

CI는 이름으로 빌드한다:

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" ...
```

공유하지 않으면 러너에서 `scheme not found` 로 실패한다.

`Product > Scheme > Manage Schemes…` → **Shared** 체크 → 파일이
`<앱>.xcodeproj/xcshareddata/xcschemes/*.xcscheme` 로 옮겨진다.

### 함정 — Autocreate 스킴은 체크만으로 파일이 생기지 않는다

"Autocreate schemes" 로 자동 생성된 스킴은 **실체 파일 없이 메모리상으로만** 존재한다.
Shared 체크를 켜도 `xcshareddata/xcschemes/` 가 안 생길 수 있다.
이때는 Manage Schemes에서 해당 행을 `−` 로 지우고 **`Autocreate Schemes Now`** 를 눌러 실체화한 뒤
Shared를 켠다. rename 전 이름이 스킴 목록에 남아 있을 때도 같은 방법으로 정리한다.

```bash
ls Apps/<앱>/<앱>.xcodeproj/xcshareddata/xcschemes/   # .xcscheme 파일이 실제로 있어야 한다
xcodebuild -workspace YJApps.xcworkspace -list        # 앱 스킴 10개 (+ YJKit 프로덕트 스킴 5개)
```

---

## 5. Info.plist — 두 갈래를 **병용**한다

Xcode 13부터 Info.plist 파일 없이 빌드 설정만으로 plist를 만들 수 있다. 그런데 이 방식만으로는
표현 못 하는 값이 있어서, 세 앱 모두 두 방식을 같이 쓴다.

```
GENERATE_INFOPLIST_FILE = YES              # INFOPLIST_KEY_* 를 생성 plist 에 주입
INFOPLIST_FILE = "<앱>-Info.plist"          # 이 파일을 base 로 두고 병합
```

**두 설정은 배타적이지 않다.** 파일이 base가 되고 `INFOPLIST_KEY_*` 가 그 위에 얹힌다.

### `INFOPLIST_KEY_*` 는 Xcode가 **아는 키에만** 동작한다

빌드 설정 값은 문자열이지만, Xcode는 아는 키에 한해 타입을 알고 변환한다.
**모르는 키는 문자열로도 안 들어가고 통째로 버려진다 — 경고도 없다.**

2026-09-03 실측 (`xcodebuild ... INFOPLIST_KEY_X=Y` 로 오버라이드한 뒤 산출물 `Info.plist` 확인):

| 오버라이드 | 생성된 plist |
|---|---|
| `INFOPLIST_KEY_NSHealthShareUsageDescription="대조군"` | `"NSHealthShareUsageDescription" => "대조군"` ✅ |
| `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad="A B C"` | 공백으로 쪼개져 **배열**로 ✅ |
| `INFOPLIST_KEY_LSApplicationQueriesSchemes="instagram-stories facebook"` | **키 자체가 없음** ❌ |

| 넣을 값 | 어디에 |
|---|---|
| Xcode가 아는 키 (`NSHealthShareUsageDescription`, `WKCompanionAppBundleIdentifier`, `UISupportedInterfaceOrientations` …) | `INFOPLIST_KEY_<키>` 빌드 설정 |
| **Xcode가 모르는 키** (`LSApplicationQueriesSchemes`, `NSAppTransportSecurity` …) | `<앱>-Info.plist` 파일 |

빌드는 통과하고 로그에도 아무 말이 없으므로, **산출물 plist를 직접 열어보기 전에는 알 수 없다.**

`GolfCounter-Info.plist` 와 `TennisCounter-Info.plist` 는 현재 내용이 비어 있다(`{}`).
아직 배열 키가 필요 없었을 뿐, 자리는 잡혀 있다.

### 검증

```bash
plutil -p Apps/<앱>/<앱>-Info.plist                                   # 파일 자체
# 빌드 산출물의 최종 병합 결과
plutil -p "$(xcodebuild -workspace YJApps.xcworkspace -scheme "<스킴>" \
  -destination "id=$IOS" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')/Info.plist"
```

### 같은 자리에 있는 Packaging 설정들

`Build Settings > Packaging` 에서 함께 보이는 항목들이다. **`INFOPLIST_FILE` 말고는 전부 기본값을 둔다.**

| 표시 이름 | 빌드 설정 | 기본 | 하는 일 |
|---|---|---|---|
| Generate Info.plist File | `GENERATE_INFOPLIST_FILE` | `YES` | `INFOPLIST_KEY_*` 를 Info.plist로 생성·주입 |
| Info.plist File | `INFOPLIST_FILE` | 없음 | 병합의 **base** 파일. 경로는 **프로젝트 폴더 기준 상대경로** |
| Expand Build Settings in Info.plist File | `INFOPLIST_EXPAND_BUILD_SETTINGS` | `YES` | plist 안의 `$(PRODUCT_NAME)` 같은 변수를 실제 값으로 치환 |
| Preprocess Info.plist File | `INFOPLIST_PREPROCESS` | `NO` | plist를 C 전처리기(`#if`)에 통과시킬지. 구식 기능 |
| Don't Force Info.plist Generation | `DONT_GENERATE_INFOPLIST_FILE` | `NO` | 이중 부정이다. `YES` 면 위의 Generate를 무시한다 |
| Adjust Strings File Names for Info.plist | `STRINGS_FILE_INFOPLIST_RENAME` | `YES` | 로컬라이즈 strings 파일 이름을 산출물에서 `InfoPlist.strings` 로 맞춘다 |

마지막 항목은 `INFOPLIST_FILE` 을 `HaruchiFit-Info.plist` 같은 비표준 이름으로 뒀을 때
"그럼 strings 파일 이름도 맞춰야 하나" 하고 헷갈리기 쉽다. **둘은 무관하다** —
소스가 이미 `InfoPlist.xcstrings`(→ `InfoPlist.strings`)면 바꿀 이름이 없다.
2026-09-03 실측으로 `NO` 로 두고 빌드해도 산출물이 같음을 확인했다.

---

## 6. 로컬라이제이션 — String Catalog(`.xcstrings`)

권한 문구는 **언어별로 달라야 한다.** `INFOPLIST_KEY_*` 에 넣은 값은 개발 언어
(`developmentRegion = en`, 세 앱 공통)의 기본값일 뿐이고, 실제 표시 문구는 로컬라이제이션이 결정한다.

| 층 | 역할 |
|---|---|
| `INFOPLIST_KEY_NSHealth*` 빌드 설정 | **기본값·폴백.** 생성 Info.plist에 박힌다. 키가 여기 없으면 §7의 크래시 |
| `<lang>.lproj/InfoPlist.strings` | **언어별 덮어쓰기.** 사용자 기기 언어에 맞는 문구가 표시된다 |

빌드 설정에는 **영문**을 넣는다. 한글을 넣으면 영어권 사용자에게 한글 문구가 뜬다 —
빌드도 되고 한국어 기기에서는 정상으로 보여서 심사에서야 발견되기 쉽다.

### 두 가지 방식

Golf·Tennis와 YJKit은 전부 레거시 `.strings` 다.
**하루치 핏만 `.xcstrings`(String Catalog, Xcode 15+)를 쓴다** — 신규 앱이 낮은 방식을 물려받을
이유가 없다(`.swiftformat` 의 `--swiftversion 6.0` 과 같은 논리).

| | `.strings` | `.xcstrings` |
|---|---|---|
| 파일 수 | 언어 × 타깃 | **타깃당 1개** |
| 편집 | 텍스트 파일 각각 | Xcode 에디터에서 표로, 언어가 나란히 |
| 번역 상태 | 없음 | `needs review` / `stale` 추적 |
| 소스 자동 추출 | 없음 | `String(localized:)` 를 **Xcode가 자동 수집** |
| 산출물 | `lproj/*.strings` | 동일 — 빌드 때 `xcstringstool` 이 컴파일 |

기존 앱은 파일 우클릭 → **Migrate to String Catalog** 로 옮길 수 있다.

### 배치

동기화 폴더(§2)에 파일만 두면 된다. pbxproj를 건드리지 않는다.

```
Apps/HaruchiFit/iOSApp/InfoPlist.xcstrings
Apps/HaruchiFit/WatchApp/InfoPlist.xcstrings
```

파일 이름은 **`InfoPlist`** 여야 한다. `INFOPLIST_FILE` 이 어떤 이름이든 무관하다(§5).

### `knownRegions` 에 언어를 추가할 필요가 없다

2026-09-03 실측 — `knownRegions = (en, Base)` 인 채로 `ko` 가 든 `.xcstrings` 를 넣고 빌드하니
번들에 `ko.lproj/InfoPlist.strings` 가 정상 생성됐다. **빌드는 `knownRegions` 가 아니라
`.xcstrings` 안의 언어 목록을 따른다.** Xcode UI에서 한국어를 따로 추가하지 않아도 된다.

### 검증

빌드 산출물을 직접 연다. `.xcstrings` 만 단독으로 컴파일해볼 수도 있다.

```bash
APP="$DERIVED/Build/Products/Debug-iphonesimulator/HaruchiFit.app"
find "$APP" -maxdepth 2 -name '*.lproj'       # en.lproj / ko.lproj 가 있어야 한다
plutil -p "$APP/ko.lproj/InfoPlist.strings"   # 한글 문구
plutil -p "$APP/Info.plist" | grep Health     # 영문 기본값

xcstringstool compile --output-directory /tmp/out Apps/HaruchiFit/iOSApp/InfoPlist.xcstrings
```

> **붙여넣기로 들어간 개행에 주의한다.** Build Settings 값에 후행 개행이 섞이면 권한 다이얼로그에
> 빈 줄이 생긴다. 빌드는 통과하고 눈에도 잘 안 띈다. 실제로 2026-09-03에 워치 타깃의
> `NSHealthShareUsageDescription` 이 그렇게 들어갔다(80자 → 82자).
> 값 길이를 비교하면 잡힌다.
>
> ```bash
> grep -oE 'INFOPLIST_KEY_NSHealth[A-Za-z]+ = "[^"]*";' $P
> ```

---

## 7. Capability와 entitlements

`Signing & Capabilities > + Capability > HealthKit` 을 켜면 Xcode가 `.entitlements` 파일을 만들고
`com.apple.developer.healthkit` 을 넣는다. 코드사이닝 때 이 entitlement가 바이너리에 박힌다.

- **없으면 `HKHealthStore` 접근이 OS 수준에서 거부된다.** 코드가 맞아도 권한 요청이 실패한다
- **iOS 앱과 워치 앱에 각각 필요하다.** 워치 앱은 별개 바이너리라 따로 서명된다
- 컴플리케이션에는 필요 없다 (HealthKit을 직접 쓰지 않는다)

### 권한 문구가 없으면 경고가 아니라 **크래시**다

| 키 | 의미 |
|---|---|
| `NSHealthShareUsageDescription` | **읽기**. 건강 앱에서 운동 기록을 가져올 때 |
| `NSHealthUpdateUsageDescription` | **쓰기**. 워크아웃을 건강 앱에 저장할 때 |

문구가 없는 상태로 `requestAuthorization` 을 호출하면 앱이 강제 종료된다. 애플이 개발 단계에서
반드시 잡히도록 일부러 강하게 만든 장치다. 빌드는 통과하므로 **실행해봐야 발견된다.**

---

## 8. `LSApplicationQueriesSchemes` — 조용히 실패하는 설정

iOS 9부터 `UIApplication.canOpenURL(_:)` 은 **화이트리스트 방식**이다. 앱이 물어볼 수 있는 URL 스킴을
Info.plist의 `LSApplicationQueriesSchemes` 에 미리 선언해야 하고,
**선언되지 않은 스킴은 그 앱이 실제로 설치돼 있어도 항상 `false`** 를 돌려준다.
(앱이 설치된 앱 목록을 스캔해 사용자를 프로파일링하던 것을 막으려는 조치)

`WorkoutShareUI` 가 이 함수를 쓴다:

```swift
// Packages/YJKit/Sources/WorkoutShareUI/Share/InstagramStoryShare.swift
static var isAvailable: Bool {
    guard let url = InstagramStoryLink.probeURL else { return false }   // instagram-stories://share
    return UIApplication.shared.canOpenURL(url)
}
```

선언이 없으면 `isAvailable` 이 영원히 `false` → 인스타그램이 설치돼 있어도 항상 일반 공유 시트로 떨어진다.
**폴백 자체는 의도된 설계지만**(설정 누락과 미설치가 같은 경로를 타는 것), 설정 누락 때문에 인스타 경로가
아예 켜지지 않는 것은 다른 문제다. 크래시가 아니라 대체 동작이므로 원인을 찾기 어렵다.

`WorkoutShareUI` 를 링크하는 앱은 **반드시** 이 키를 넣는다. 2026-09-03 기준 링크한 앱은 하루치 핏뿐이다.

---

## 9. YJKit 프로덕트 링크

`Package Dependencies > + > Add Local…` 로 `Packages/YJKit` 를 참조하면 pbxproj에
`XCLocalSwiftPackageReference "../../Packages/YJKit"` 가 기록된다. 원격 의존성과 달리 버전 고정도,
체크아웃도, `Package.resolved` 도 없다 — **패키지 소스를 고치면 다음 빌드에 즉시 반영된다.**

이 단계는 "패키지가 존재한다"만 알린다. 어느 타깃이 무엇을 쓸지는 각 타깃의
`General > Frameworks, Libraries, and Embedded Content` 에서 따로 정한다.

| 타깃 | 링크 |
|---|---|
| `GolfCounter` | ConnectivityCore, PersistenceCore |
| `GolfCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| `TennisCounter` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI |
| `TennisCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| `HaruchiFit` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, WorkoutShareUI |
| `HaruchiFit Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| 컴플리케이션 (전 앱) | **없음** |

### 왜 전부 링크하지 않나

- **플랫폼 제약** — `WorkoutShareUI` 는 소스 전체가 `#if os(iOS)`, `WorkoutSessionService` 의 세션
  제어부는 `#if os(watchOS)` 안에 있다. 맞지 않는 플랫폼에 링크해봐야 빈 모듈이다
- **설계 의도를 강제** — 컴플리케이션이 YJKit을 쓰지 않는 것은 결정 사항이다. 로컬 스냅샷만 읽는다.
  링크해두면 무심코 쓰게 되고, 위젯 익스텐션의 좁은 메모리 예산을 잡아먹는다
- **빌드 시간·바이너리 크기**

`Shared/` 폴더가 3개 타깃에 걸리는 것도 같은 맥락이다. **컴플리케이션은 YJKit을 링크하지 않으므로,
컴플리케이션이 읽어야 할 스냅샷 타입은 앱의 `Shared/` 에 있어야 한다.**
종목별 도메인 타입을 YJKit이 아니라 앱이 소유하는 이유는 루트 `CLAUDE.md` 의 "코어는 도메인을 모른다".

---

## 10. 새 앱을 추가할 때 — 순서와 검증

Xcode GUI가 해야 하는 일과 명령으로 확인할 수 있는 일을 갈라 적는다.
**pbxproj를 직접 편집하지 않는다.**

### Xcode에서

1. **워크스페이스를 연 채** `File > New > Project… > iOS > App`
   → 저장 위치 `Apps/`, **Add to: `YJApps`**, Git 저장소 생성 **해제**
2. 네비게이터에서 **새 프로젝트를 선택한 뒤** `File > New > Target… > watchOS > App`
   → Product Name은 **`<앱>` 만**(§1), Companion은 iOS 앱, Testing System은 **Swift Testing**
3. 같은 방식으로 `watchOS > Widget Extension`
   → Include Live Activity **해제**, Embed in **워치 앱**
4. 폴더 이름을 §2대로 정리 (네비게이터에서 rename)
5. 배포 타깃 — iOS `17.0` / watchOS `10.0`. **PROJECT 레벨도 함께 맞춘다.**
   드롭다운 목록에 없으면 값 칸에 `17.0` 을 직접 입력한다 (`iOS 17`, `17.6` 같은 값이 들어가기 쉽다)
6. 번들 ID를 §1대로 (`Build Settings > Product Bundle Identifier`)
7. `Package Dependencies > + > Add Local… > Packages/YJKit` → 타깃별 프로덕트 링크 (§9)
8. HealthKit Capability + 권한 문구 (§7). 문구는 **영문**으로 넣는다 (§6)
9. 배열 키가 필요하면 `<앱>-Info.plist` 를 만들고 `INFOPLIST_FILE` 로 가리킨다 (§5)
10. 각 타깃 폴더에 `InfoPlist.xcstrings` 를 두고 언어별 문구를 채운다 (§6)
11. `Manage Schemes…` → 스킴 **Shared** 체크 (§4)

### 명령으로 확인

```bash
APP=<앱>; P=Apps/$APP/$APP.xcodeproj/project.pbxproj

xcodebuild -project Apps/$APP/$APP.xcodeproj -list          # 타깃 이름
grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' $P | sort -u  # 번들 ID
grep -oE '(IPHONEOS|WATCHOS)_DEPLOYMENT_TARGET = [^;]+;' $P | sort -u
grep -oE '(TEST_HOST|INFOPLIST_FILE) = [^;]+;' $P | sort -u # §3
ls Apps/$APP/$APP.xcodeproj/xcshareddata/xcschemes/          # §4
xcodebuild -workspace YJApps.xcworkspace -list               # 워크스페이스에서 보이는지
git status --short Apps/$APP                                 # xcuserdata/ 가 빠졌는지
```

그다음 세 스킴을 전부 빌드한다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "<iOS 스킴>"   -destination "id=$IOS"   CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace YJApps.xcworkspace -scheme "<워치 스킴>"   -destination "id=$WATCH" CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace YJApps.xcworkspace -scheme "<컴플리케이션>" -destination "id=$WATCH" CODE_SIGNING_ALLOWED=NO build
```

마지막으로 `Makefile` 의 `APPS`, `.github/workflows/ci.yml` 의 경로 필터·빌드 잡,
앱 폴더의 `.swiftlint.yml` / `.swiftformat` 을 추가한다.

### Xcode 26 신규 프로젝트가 기존 앱과 다른 기본값

새로 만든 프로젝트에는 기존 두 앱에 없는 빌드 설정이 붙는다. 세 앱의
`SWIFT_VERSION` 은 다 같이 `5.0` 이지만 동시성 기본값이 다르다.

| 설정 | 신규 (HaruchiFit) | 기존 (Golf·Tennis) |
|---|---|---|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | 없음 (= `nonisolated`) |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | 없음 |

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 는 **타입이 기본으로 MainActor 에 격리된다**는
뜻이다. SwiftUI 앱에는 대체로 맞는 기본값이지만, YJKit 타입을 확장하는 상수에 걸린다:

```swift
extension WorkoutConfiguration {
    // nonisolated 가 없으면 이 상수가 MainActor 로 격리된다.
    // 기본 인자는 호출 지점(비격리일 수 있다)에서 평가되므로 경고가 난다.
    nonisolated static let strength = WorkoutConfiguration(activityType: .traditionalStrengthTraining,
                                                           locationType: .indoor)
}
```

에러가 아니라 **경고**라 빌드는 통과한다. `WorkoutConfiguration+Golf.swift` 같은 기존 앱 코드를
그대로 옮겨 붙이면 이 차이가 드러난다. 값이 `Sendable` 이면 `nonisolated` 를 붙이는 것이 맞다.

---

## 11. 빌드가 통과해도 틀린 것들 — 요약

이 문서가 다루는 문제 중 **빌드로는 안 잡히는 것**만 모은다. 새 타깃을 만든 뒤 이것만은 눈으로 확인한다.

| 항목 | 틀렸을 때 | 확인 | 절 |
|---|---|---|---|
| 스킴 공유 | CI에서만 실패 | `ls .../xcshareddata/xcschemes/` | §4 |
| 배포 타깃 | 구형 기기에서만 실패 | `grep DEPLOYMENT_TARGET` | §10 |
| `PROJECT` 레벨 배포 타깃 | 다음 타깃이 물려받음 | `grep` 결과가 두 값이면 의심 | §10 |
| HealthKit 권한 문구 누락 | **실행 시 크래시** | 실기기에서 권한 요청 | §7 |
| 권한 문구가 한 타깃에만 | 그 타깃에서만 크래시 | `grep -c INFOPLIST_KEY_NSHealth` 가 `타깃 수 × 2` | §7 |
| 권한 문구에 후행 개행 | 다이얼로그에 빈 줄 | 값 길이 비교 | §6 |
| 권한 문구가 한글만 | **영어권에만 한글이 뜬다** | 산출물 `Info.plist` + `lproj` | §6 |
| `LSApplicationQueriesSchemes` | 조용히 공유 시트로 폴백 | 산출물 `plutil -p` | §8 |
| `INFOPLIST_KEY_` 로 넣은 배열 키 | 키가 통째로 사라짐 | 산출물 `plutil -p` | §5 |
| `TEST_HOST` | 테스트 실행 시 | Host Application이 `Custom`인지 | §3 |

**확인의 절반이 "산출물 `Info.plist` 를 직접 열어보기"다.** 빌드 로그는 이 부류를 알려주지 않는다.
