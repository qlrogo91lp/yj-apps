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

- **Swift 파일을 수정하지 않는다.** 이 계획은 리소스 파일 전환만 한다.
- 카탈로그 파일(`.xcstrings`)은 **Xcode 가 만든 것만** 커밋한다. 손으로 쓰거나 고치지 않는다.
- 브랜치는 **`feat/ralli`**, 메인 체크아웃에서 작업한다 (워크트리 없음).
- 커밋은 **하나**: `🔧 iOS·워치 로컬라이즈를 String Catalog 으로 전환`.
- 전환 전후로 **키 개수가 같아야 한다** (iOS 71 · 워치 27 · InfoPlist 각 2). 줄거나 늘면 도구가 뭔가 놓친 것이다.

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
  echo "$f: $(grep -cE '^"?[A-Za-z_]+"? *=' "$f")"
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
Expected: 두 폴더 각각에 `InfoPlist.strings`, `Localizable.strings`. `NSHealthShareUsageDescription => "Ralli가 경기 중 칼로리와 심박수를 측정합니다."`.

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

## 후속 (이번 커밋에 넣지 않는다)

- **미사용 키 정리** — 카탈로그 에디터에서 Stale 표시된 20개 (iOS: `score_label_me`, `score_label_opp`, `btn_reset`, `btn_end_match`, `btn_end_set`, `btn_new_match`, `set_indicator_format`, `game_score_label`, `workout_in_progress`, `workout_paused`, `summary_period_all`, `summary_streak`, `summary_no_matches`, `history_view_calendar`, `history_view_list`, `btn_save`, `vs_label` / 워치: `watch_quick_match`, `watch_rematch`, `score_deciding_point`). 다음 기능 작업에서 화면을 건드릴 때 같이 지운다.
- **LiveActivity 하드코딩** — `TennisLiveActivity/Components/LiveActivityView.swift` 의 `Text("Ralli")`, `Text("Tiebreak")`. LiveActivity 타깃엔 로컬라이즈 리소스 자체가 없다.
- **iOS·워치 카탈로그 통합** — 표현이 다른 키 4개를 워치 전용 키로 나누거나 통일한 뒤에.

## Self-Review

- 결정 사항 5개 → Task 2·3(타깃별), 전 태스크(Xcode 메뉴), 후속(미사용 키·LiveActivity), Task 2·3 Step 2 (`InfoPlist`) ✅
- 키 개수 불변 제약 → Task 1 스냅샷 + Task 2·3 diff ✅
- Swift 무변경 제약 → Task 5 Step 1 ✅
- 코드 스텝 없음 — 이 계획은 Xcode UI 조작 + 셸 검증만으로 구성된다. 플레이스홀더 없음.
