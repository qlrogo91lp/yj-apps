# String Catalog 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ralli iOS·워치 타깃의 `.lproj/.strings` 로컬라이즈 파일 8개를 타깃별 String Catalog(`.xcstrings`) 4개로 전환한다. 동작은 바뀌지 않는다.

**Architecture:** Xcode 의 **Migrate to String Catalog** 메뉴가 `ko`·`en` 두 언어의 `.strings` 를 읽어 카탈로그 하나로 합치고 옛 파일을 지운다. 호출부는 전부 `String(localized:)` 라 Swift 코드는 한 줄도 바뀌지 않는다. 타깃 간 카탈로그 통합은 **하지 않는다** — iOS·워치가 공유하는 키 16개 중 4개가 일부러 다른 표현을 쓰고 있어, 합치려면 표현 결정이 먼저 필요하다 (2026-09-07 결정: A안 타깃별 유지).

**Tech Stack:** Xcode 26 String Catalog / `String(localized:)` / `PBXFileSystemSynchronizedRootGroup`

**Spec:** 별도 스펙 없음 — 2026-09-07 대화에서 확정. 결정 근거는 아래 §결정 사항.

## 결정 사항 (2026-09-07)

| 논점 | 결정 | 이유 |
|---|---|---|
| 카탈로그 단위 | **타깃별** (`iOSApp/`, `WatchApp/` 각각) | 공유 키 4개(`early_end_confirm_title`·`early_end_confirm_message`·`result_save_failed`·`mode_no_ad`)가 워치 화면 폭 때문에 다른 표현을 쓴다. 합치면 이 결정이 끼어든다 |
| 전환 방법 | **Xcode 메뉴**, 카탈로그 JSON 수동 작성 금지 | `extractionState`·`state` 필드를 손으로 쓰면 틀리기 쉽다. 도구가 정확하다 |
| 미사용 키 20개 (iOS 17 · 워치 3) | **그대로 옮긴다** | 전환 커밋을 "동작 무변경" 하나로 남긴다. 카탈로그가 Stale 로 표시하니 다음 기능 작업 때 정리 |
| `InfoPlist.strings` | 같이 전환 (`InfoPlist.xcstrings`) | HealthKit 권한 문구. 빠지면 프롬프트가 죽는다 — 규약 문서 §HealthKit 권한 문구 |
| LiveActivity 하드코딩 (`Text("Ralli")`, `Text("Tiebreak")`) | 범위 밖 | 로컬라이즈 자체가 안 된 문자열. 별도 작업 |

## Global Constraints

- ~~**Swift 파일을 수정하지 않는다.**~~ → **2026-09-08 범위 확대.** 전환이 하드코딩 문자열을
  드러내서 정리까지 함께 한다. 아래 §추출 문제 참고.
- 카탈로그 파일(`.xcstrings`)은 **Xcode 가 만든 것만** 커밋한다. 손으로 쓰거나 고치지 않는다.
  → **예외(2026-09-08)**: 하드코딩을 정리한 뒤 남는 항목 삭제와 신규 키 5개의 ko·en 입력은
  손으로 한다. `xcodebuild` 는 카탈로그를 갱신하지 않아 Xcode 왕복 없이는 방법이 없다.
- 브랜치는 **`feature/ralli-string-catalog`**, 메인 체크아웃에서 작업한다 (워크트리 없음).
  `feat/ralli` 은 PR #11 로 머지되어 더 쓰지 않는다 — 새 작업은 항목별 브랜치를 판다 (루트 `TODO.md`).
- ~~커밋은 **하나**~~ → **커밋 3개** (2026-09-08). 전환 / verbatim 정리 / 누락 번역.
- ~~전환 전후로 **키 개수가 같아야 한다**~~ → **기존 키가 사라지지 않아야 한다.**
  전환 직후엔 추출 때문에 늘고(iOS 91 · 워치 37), 정리 후 iOS 76(71+신규 5) · 워치 27 이 된다.

**빌드 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build
```

## File Structure

| 파일 | 상태 | 비고 |
|---|---|---|
| `Apps/TennisCounter/iOSApp/Localizable.xcstrings` | 생성 (Xcode) | ← `iOSApp/{ko,en}.lproj/Localizable.strings` |
| `Apps/TennisCounter/iOSApp/InfoPlist.xcstrings` | 생성 (Xcode) | ← `iOSApp/{ko,en}.lproj/InfoPlist.strings` |
| `Apps/TennisCounter/WatchApp/Localizable.xcstrings` | 생성 (Xcode) | ← `WatchApp/{ko,en}.lproj/Localizable.strings` |
| `Apps/TennisCounter/WatchApp/InfoPlist.xcstrings` | 생성 (Xcode) | ← `WatchApp/{ko,en}.lproj/InfoPlist.strings` |
| `Apps/TennisCounter/{iOSApp,WatchApp}/{ko,en}.lproj/` | 삭제 (Xcode) | 폴더째 사라져야 한다 |
| `Apps/TennisCounter/TennisCounter.xcodeproj/project.pbxproj` | 수정 (Xcode) | synchronized group 이라 변경이 거의 없어야 한다. `knownRegions` 는 그대로 |

---

### Task 1: 전환 전 스냅샷

전환이 키를 빠뜨리지 않았는지 비교할 기준을 남긴다.

**Files:** 없음 (스크래치 출력만)

- [ ] **Step 1: 키 개수·목록 기록**

Run (루트에서):
```bash
cd Apps/TennisCounter
for f in iOSApp/ko.lproj/Localizable.strings WatchApp/ko.lproj/Localizable.strings \
         iOSApp/ko.lproj/InfoPlist.strings WatchApp/ko.lproj/InfoPlist.strings; do
  echo "$f: $(grep -cE '^"?[A-Za-z_][A-Za-z0-9_]*"? *=' "$f")"
done
grep -oE '^"[^"]+"' iOSApp/ko.lproj/Localizable.strings | sort > /tmp/ios-keys-before.txt
grep -oE '^"[^"]+"' WatchApp/ko.lproj/Localizable.strings | sort > /tmp/watch-keys-before.txt
```
Expected:
```
iOSApp/ko.lproj/Localizable.strings: 71
WatchApp/ko.lproj/Localizable.strings: 27
iOSApp/ko.lproj/InfoPlist.strings: 2
WatchApp/ko.lproj/InfoPlist.strings: 2
```

- [ ] **Step 2: 워킹트리가 깨끗한지 확인**

Run: `git status --short`
Expected: 출력 없음. 전환 diff 에 다른 변경이 섞이면 안 된다.

---

### Task 2: iOS 타깃 전환

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Localizable.xcstrings`, `Apps/TennisCounter/iOSApp/InfoPlist.xcstrings`
- Delete: `Apps/TennisCounter/iOSApp/ko.lproj/`, `Apps/TennisCounter/iOSApp/en.lproj/`

- [ ] **Step 1: `Localizable.strings` 마이그레이션**

`YJApps.xcworkspace` 를 열고 네비게이터에서 **TennisCounter › iOSApp › Localizable.strings** (언어 폴더가 접힌 그룹 항목) 우클릭 → **Migrate to String Catalog…** → 대화상자에서 `Localizable.strings` 체크 확인 → **Migrate**.

메뉴가 안 보이면 Edit → Convert → **To String Catalog…** 로 같은 대화상자가 열린다.

- [ ] **Step 2: `InfoPlist.strings` 마이그레이션**

같은 방법으로 **iOSApp › InfoPlist.strings** 를 전환한다.

- [ ] **Step 3: 파일시스템 확인**

Run:
```bash
ls Apps/TennisCounter/iOSApp/*.xcstrings
ls -d Apps/TennisCounter/iOSApp/*.lproj 2>&1
```
Expected:
```
Apps/TennisCounter/iOSApp/InfoPlist.xcstrings
Apps/TennisCounter/iOSApp/Localizable.xcstrings
ls: .../iOSApp/*.lproj: No such file or directory
```
`.lproj` 폴더가 남아 있으면 Xcode 가 참조만 끊고 파일을 안 지운 것이다 — 폴더를 직접 지운다 (`rm -r Apps/TennisCounter/iOSApp/{ko,en}.lproj`). synchronized group 이라 pbxproj 는 건드릴 게 없다.

- [ ] **Step 4: 키 개수 비교**

Run:
```bash
cd Apps/TennisCounter
python3 -c "import json;d=json.load(open('iOSApp/Localizable.xcstrings'));print(len(d['strings']), d['sourceLanguage'])"
python3 -c "import json;d=json.load(open('iOSApp/InfoPlist.xcstrings'));print(len(d['strings']))"
python3 -c "import json;print('\n'.join(sorted('\"%s\"'%k for k in json.load(open('iOSApp/Localizable.xcstrings'))['strings'])))" \
  | diff /tmp/ios-keys-before.txt - && echo "iOS 키 일치"
```
Expected: `71 en`, `2`, `iOS 키 일치`.

- [ ] **Step 5: 두 언어가 모두 들어갔는지 확인**

Run:
```bash
python3 -c "
import json
d=json.load(open('Apps/TennisCounter/iOSApp/Localizable.xcstrings'))
missing=[k for k,v in d['strings'].items() if set(v.get('localizations',{}))!={'ko','en'}]
print('언어 누락 키:', missing or '없음')"
```
Expected: `언어 누락 키: 없음`.

---

### Task 3: 워치 타깃 전환

**Files:**
- Create: `Apps/TennisCounter/WatchApp/Localizable.xcstrings`, `Apps/TennisCounter/WatchApp/InfoPlist.xcstrings`
- Delete: `Apps/TennisCounter/WatchApp/ko.lproj/`, `Apps/TennisCounter/WatchApp/en.lproj/`

- [ ] **Step 1: `Localizable.strings` 마이그레이션**

네비게이터에서 **TennisCounter › WatchApp › Localizable.strings** 우클릭 → **Migrate to String Catalog…** → **Migrate**.

- [ ] **Step 2: `InfoPlist.strings` 마이그레이션**

**WatchApp › InfoPlist.strings** 도 같은 방법으로.

- [ ] **Step 3: 파일시스템 확인**

Run:
```bash
ls Apps/TennisCounter/WatchApp/*.xcstrings
ls -d Apps/TennisCounter/WatchApp/*.lproj 2>&1
```
Expected: `InfoPlist.xcstrings`, `Localizable.xcstrings` 두 줄과 `No such file or directory`. 남아 있으면 `rm -r Apps/TennisCounter/WatchApp/{ko,en}.lproj`.

- [ ] **Step 4: 키 개수·언어 비교**

Run:
```bash
cd Apps/TennisCounter
python3 -c "import json;d=json.load(open('WatchApp/Localizable.xcstrings'));print(len(d['strings']), d['sourceLanguage'])"
python3 -c "import json;d=json.load(open('WatchApp/InfoPlist.xcstrings'));print(len(d['strings']))"
python3 -c "import json;print('\n'.join(sorted('\"%s\"'%k for k in json.load(open('WatchApp/Localizable.xcstrings'))['strings'])))" \
  | diff /tmp/watch-keys-before.txt - && echo "워치 키 일치"
python3 -c "
import json
d=json.load(open('WatchApp/Localizable.xcstrings'))
missing=[k for k,v in d['strings'].items() if set(v.get('localizations',{}))!={'ko','en'}]
print('언어 누락 키:', missing or '없음')"
```
Expected: `27 en`, `2`, `워치 키 일치`, `언어 누락 키: 없음`.

---

### Task 4: 빌드·산출물·실행 검증

**Files:** 없음

- [ ] **Step 1: 두 스킴 빌드**

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -2
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -2
```
Expected: 둘 다 `BUILD SUCCEEDED`.

- [ ] **Step 2: 산출물에 두 언어 리소스가 생성됐는지**

카탈로그는 빌드 시 언어별 `.strings` 로 컴파일된다. 번들 안에 `ko.lproj`·`en.lproj` 가 **다시 생겨 있어야** 정상이다.

Run:
```bash
APP="$(xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')"
ls "$APP"/ko.lproj "$APP"/en.lproj
plutil -p "$APP/ko.lproj/InfoPlist.strings" | head -3
```
Expected: `ko.lproj` 에 `InfoPlist.strings`·`Localizable.strings`, `en.lproj` 에 `Localizable.strings`.
`NSHealthShareUsageDescription => "Ralli가 경기 중 칼로리와 심박수를 측정합니다."`.

> `en.lproj/InfoPlist.strings` 는 **안 생기는 게 정상이다.** `en` 이 sourceLanguage 라 카탈로그가
> 중복 파일을 만들지 않고, 영어 문구는 빌드 설정 `INFOPLIST_KEY_*` 를 통해 앱 `Info.plist` 에 이미 들어 있다.

- [ ] **Step 3: 시뮬레이터에서 한국어·영어 한 바퀴**

Xcode 에서 스킴 편집 → Run → Options → **App Language** 를 `Korean` 으로 두고 실행. 홈(요약) → 경기 모드 선택 → 점수 화면 → 조기 종료 다이얼로그(취소) → 기록 탭 → 상세 시트까지 문자열이 한국어인지 확인. `English` 로 바꿔 한 번 더.

워치 스킴도 같은 방법으로 모드 선택 → 점수 → 조기 종료 다이얼로그를 본다. 다이얼로그 문구가 **"경기 중단"** (워치용 짧은 표현) 이어야 한다 — iOS 문구("경기를 중단할까요?")가 뜨면 카탈로그가 섞인 것이다.

- [ ] **Step 4: HealthKit 권한 프롬프트 문구**

워치 시뮬레이터에서 앱을 지우고 다시 설치한 뒤 워크아웃을 시작한다. 권한 프롬프트에 **"Ralli가 경기 중 칼로리와 심박수를 측정합니다."** 가 떠야 한다. 문구가 비거나 프롬프트가 안 뜨면 `InfoPlist.xcstrings` 가 타깃에 안 붙은 것이다.

- [ ] **Step 5: 린트**

Run: `make lint && make format`
Expected: 경고·오류 0 (Swift 파일이 안 바뀌었으니 당연히 통과해야 한다).

---

### Task 5: 커밋

- [ ] **Step 1: diff 가 리소스 전환뿐인지 확인**

Run: `git status --short`
Expected: `.xcstrings` 4개 추가(`A` 또는 `??`), `.strings` 8개 삭제(`D`), `project.pbxproj` 수정(`M`) 정도. **Swift 파일이 있으면 안 된다.**

- [ ] **Step 2: Commit**

```bash
git add Apps/TennisCounter
git commit -m "🔧 iOS·워치 로컬라이즈를 String Catalog 으로 전환"
```

---

## 추출 문제와 하드코딩 정리 (2026-09-08)

### 무슨 일이 있었나

카탈로그를 타깃에 붙이면 Xcode 가 `SWIFT_EMIT_LOC_STRINGS = YES` 를 켠다 (pbxproj 변경 2줄이
그것). 그때부터 **소스의 하드코딩 문자열이 카탈로그로 자동 추출된다.** 전환 직후 키가
iOS 71 → 91, 워치 27 → 37, InfoPlist 2 → 4 로 늘었다. 기존 키와 번역은 하나도 안 사라졌다.

빌드마다 추출이 도니 손으로 지워도 다시 생긴다. 그래서 **정리는 소스를 고쳐야 끝난다.**

### 결정 사항

| 논점 | 결정 | 이유 |
|---|---|---|
| 늘어난 키를 어떻게 | **소스를 고쳐 정리한다** (B안) | 지워도 빌드마다 되살아난다. `SWIFT_EMIT_LOC_STRINGS = NO` 로 끄면 카탈로그의 이점을 버린다 |
| 번역 대상이 아닌 것 | `Text(verbatim:)` | 점수·세트 숫자, 구분자(`:` `\|` `·`), 게임 수 선택지(4/5/6), 브랜드명 |
| 세트 라벨 `Set 1` | **영어 유지** | 사용자 결정. `set_indicator_format`(`%d세트`)은 계속 미사용 키 |
| `Format` · `Date` · `No set data` | **번역한다** | 같은 시트에서 섹션 헤더·값은 한국어인데 라벨만 영어라 섞여 보였다 |
| `Picker("Period")` | **번역한다** | segmented 라 화면엔 안 보이고 VoiceOver 만 읽는다 |
| 점수 영역 접근성 힌트 | **영어 번역 추가** | 한국어가 코드에 박혀 영어 기기에서도 한국어로 읽혔다. 실제 버그 |
| `CFBundleDisplayName` · `CFBundleName` | 그대로 둔다 | 브랜드명이라 ko·en 이 같다. 원래도 로컬라이즈 안 돼 있었다 |
| 워치의 `match_format_*` 4개 | `MatchFormat` 번역 프로퍼티를 **`iOSApp/Extensions/` 로 이동** | 호출부가 iOS 뿐인데 `Shared` 에 있어 워치에도 컴파일됐다. `Shared/Models` 는 플랫폼 독립이라는 컨벤션에도 맞다 |

### 신규 키 5개 (iOS 만)

| 키 | ko | en | 자리 |
|---|---|---|---|
| `history_no_set_data` | 세트 기록이 없습니다 | No set data | `MatchDetailSheet` 세트 섹션 |
| `history_field_format` | 경기 방식 | Format | `MatchDetailSheet` 경기 정보 |
| `history_field_date` | 날짜 | Date | `MatchDetailSheet` 경기 정보 |
| `summary_period_label` | 기간 | Period | `SummaryView` 기간 Picker (VoiceOver) |
| `score_point_zone_hint` | 탭으로 포인트 추가, 길게 눌러 점수 수정 | Tap to add a point, long press to edit the score | `PlayerPointZone` (VoiceOver) |

### 카탈로그를 손으로 고칠 때

- **`xcodebuild` 는 카탈로그를 갱신하지 않는다.** 추출 결과 반영은 Xcode.app 빌드에서만 일어난다
- 파일 전체를 재직렬화하면 안 된다 — Xcode 는 빈 항목을 `{` 개행 `}` 로 쓰고 키 정렬도 자체
  규칙이라 diff 가 통째로 뒤집힌다. **해당 항목만 텍스트로 잘라내고 끼워 넣는다**
- 마지막 항목을 지우면 앞 항목에 쉼표가 남는다
- `extractionState` 는 **Xcode 가 소스에서 못 찾은 키에만 `"manual"`** 로 붙는다. 소스에 있는
  키엔 없다. 신규 키를 손으로 넣을 때 이 필드를 붙이면 안 된다

### 키 개수 최종

| | 전환 전 | 전환 직후 | 정리 후 |
|---|---|---|---|
| iOS Localizable | 71 | 91 | **76** (71 + 신규 5) |
| 워치 Localizable | 27 | 37 | **27** |
| InfoPlist (양쪽) | 2 | 4 | **4** (`CFBundle*` 2개는 그대로 둔다) |

---

## 후속 (이번 커밋에 넣지 않는다)

- **미사용 키 정리** — 카탈로그 에디터에서 Stale 표시된 20개 (iOS: `score_label_me`, `score_label_opp`, `btn_reset`, `btn_end_match`, `btn_end_set`, `btn_new_match`, `set_indicator_format`, `game_score_label`, `workout_in_progress`, `workout_paused`, `summary_period_all`, `summary_streak`, `summary_no_matches`, `history_view_calendar`, `history_view_list`, `btn_save`, `vs_label` / 워치: `watch_quick_match`, `watch_rematch`, `score_deciding_point`). 다음 기능 작업에서 화면을 건드릴 때 같이 지운다.
- **LiveActivity·컴플리케이션 하드코딩** — `TennisLiveActivity/Components/LiveActivityView.swift` 의
  `Text("Ralli")`·`Text("Tiebreak")`, `ComplicationApp/ComplicationApp.swift` 의
  `.configurationDisplayName("Ralli")`·`.description("Tennis Counter")`. 그 타깃엔 카탈로그가 없어
  추출되지 않았다.
- **iOS·워치 카탈로그 통합** — 표현이 다른 키 4개를 워치 전용 키로 나누거나 통일한 뒤에.

## Self-Review

- 결정 사항 5개 → Task 2·3(타깃별), 전 태스크(Xcode 메뉴), 후속(미사용 키·LiveActivity), Task 2·3 Step 2 (`InfoPlist`) ✅
- 키 개수 불변 제약 → Task 1 스냅샷 + Task 2·3 diff ✅
- Swift 무변경 제약 → Task 5 Step 1 ✅
- 코드 스텝 없음 — 이 계획은 Xcode UI 조작 + 셸 검증만으로 구성된다. 플레이스홀더 없음.
