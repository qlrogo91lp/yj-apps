# iOS 온보딩 워치 중심 재구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 온보딩을 4페이지에서 5페이지로 바꿔 워치 사용법(크라운·스와이프·컴플리케이션)을 3장으로 다루고, 기능 목록 페이지를 없앤다.

**Architecture:** 뼈대(`OnboardingGate` · `OnboardingScreenshotPage` · `iOSApp.swift` 진입 분기)는 그대로 둔다. `OnboardingView` 의 `TabView` 내용물만 5장으로 갈아끼우고, 쓰이지 않게 되는 `OnboardingFeatureListPage` 를 지운다. 문자열은 목록용 9개를 빼고 스와이프·컴플리케이션용 4개를 넣는다. 그림은 Figma 워치 목업에 합성한 5장을 로컬라이즈 이미지셋으로 넣는다.

**Tech Stack:** SwiftUI / `@AppStorage` / Asset Catalog 이미지 로컬라이즈 / String Catalog(`.xcstrings`) / Swift Testing

**Spec:** [docs/specs/ios/2026/2026-09-07-onboarding-design.md](../../../specs/ios/2026/2026-09-07-onboarding-design.md) (2026-09-17 개정판)

**선행 플랜:** [2026-09-07-onboarding.md](2026-09-07-onboarding.md) 의 Task 1~3(뼈대)은 PR #17 로 완료. **그 플랜의 Task 4(스크린샷)는 이 문서로 대체된다** — 구성이 바뀌어 찍을 그림이 달라졌다.

## Global Constraints

- **iOS 타깃만.** `WatchApp/`·`Shared/`·`ComplicationApp/` 은 건드리지 않는다.
- 문자열은 전부 `String(localized:)`, 카탈로그는 `iOSApp/Localizable.xcstrings`.
  **`xcodebuild` 는 카탈로그를 갱신하지 않는다** — 손으로 넣는 키에는 `"extractionState": "manual"` 을 반드시 붙인다. 붙이지 않으면 Xcode 가 다음 추출에서 지운다.
- 이미지 에셋은 **로컬라이즈된 이미지셋**(ko/en), Scales 는 **Single Scale**. 코드는 이미지 이름 하나만 안다.
- `OnboardingGate.version` 은 **1 그대로 둔다.** 아직 출시된 적 없는 온보딩을 고치는 것이라 올릴 이유가 없다.
- 온보딩은 시트가 아니라 **루트 교체**로 띄운다 (기존 구조 유지).
- SwiftLint: line length 경고 150 / 오류 200. SwiftFormat: 4-space, imports 알파벳순. 한 파일 = 한 타입 (private helper 예외).
- **View 는 테스트하지 않는다** (루트 `CLAUDE.md` 의 테스트 우선순위). 이 작업은 순수 로직 변경이 없어 새 테스트를 쓰지 않는다. 기존 테스트가 계속 통과하는지만 확인한다.
- 브랜치 **`feat/onboarding-watch-focused`**, 메인 체크아웃. gitmoji 커밋.

**빌드·테스트 명령** (저장소 루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
make lint && make format
```

## 문자열 표

**제거 (9개)** — 기능 목록 페이지가 사라지며 쓰이지 않는다.

`onboarding_more_title` · `onboarding_more_mirror_title` · `onboarding_more_mirror_body` ·
`onboarding_more_undo_title` · `onboarding_more_undo_body` · `onboarding_more_lock_title` ·
`onboarding_more_lock_body` · `onboarding_more_pause_title` · `onboarding_more_pause_body`

**추가 (4개)**

| 키 | ko | en |
|---|---|---|
| `onboarding_swipe_title` | 좌우로 넘겨보세요 | Swipe Left and Right |
| `onboarding_swipe_body` | 왼쪽은 일시정지와 종료, 오른쪽은 칼로리·심박·시간. 가운데가 점수입니다. | Pause and end on the left. Calories, heart rate and time on the right. Your score sits in the middle. |
| `onboarding_complication_title` | 한 번 탭으로 빠르게 | Start in One Tap |
| `onboarding_complication_body` | 문자판에 Ralli 컴플리케이션을 올려두면 앱을 찾지 않고 바로 열립니다. 경기 중엔 아이콘이 돌아 진행 중임을 알려줍니다. | Put the Ralli complication on your watch face and it opens right up. During a match the icon spins to show it's running. |

**유지 (11개)** — 값을 바꾸지 않는다.

`onboarding_skip` · `onboarding_next` · `onboarding_start` · `onboarding_crown_title` ·
`onboarding_crown_body` · `onboarding_crown_up` · `onboarding_crown_down` ·
`onboarding_health_title` · `onboarding_health_body` · `onboarding_share_title` · `onboarding_share_body`

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `iOSApp/Localizable.xcstrings` | 수정 | 위 문자열 표대로 9개 제거 · 4개 추가 |
| `iOSApp/Features/Onboarding/OnboardingView.swift` | 수정 | `TabView` 5장, `lastPage` 3 → 4 |
| `iOSApp/Features/Onboarding/Components/OnboardingFeatureListPage.swift` | **삭제** | 쓰는 곳이 없어진다 |
| `iOSApp/Features/Onboarding/Components/CrownArrowsOverlay.swift` | ~~수정~~ **삭제** | 화살표를 이미지에 구워 폐기 (Task 4 참고) |
| `iOSApp/Assets.xcassets/Onboarding{Crown,Swipe,Complication,Health,Share}.imageset` | 생성 | ko/en 로컬라이즈 이미지 5개 |
| `iOSApp/Features/Onboarding/OnboardingGate.swift` | **변경 없음** | `version = 1` 유지 |
| `iOSApp/iOSApp.swift` | **변경 없음** | 진입 분기 그대로 |
| `iOSApp/Features/Onboarding/Components/OnboardingScreenshotPage.swift` | **변경 없음** | 인터페이스 그대로 쓴다 |

---

### Task 1: 문자열 카탈로그 교체

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Localizable.xcstrings`

**Interfaces:**
- Produces: 키 `onboarding_swipe_title` · `onboarding_swipe_body` · `onboarding_complication_title` · `onboarding_complication_body` (Task 2 가 `String(localized:)` 로 쓴다)

먼저 한다. `String(localized:)` 는 키가 없어도 컴파일되므로 이 순서로도 빌드는 깨지지 않는다.

- [ ] **Step 1: 브랜치를 판다**

```bash
git switch -c feat/onboarding-watch-focused
```

- [ ] **Step 2: 카탈로그를 고친다**

저장소 루트에서 실행한다. `extractionState: "manual"` 이 빠지면 Xcode 가 다음 추출에서 키를 지운다.

```bash
python3 - <<'EOF'
import json, collections

path = "Apps/TennisCounter/iOSApp/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    doc = json.load(f, object_pairs_hook=collections.OrderedDict)

remove = [
    "onboarding_more_title",
    "onboarding_more_mirror_title", "onboarding_more_mirror_body",
    "onboarding_more_undo_title", "onboarding_more_undo_body",
    "onboarding_more_lock_title", "onboarding_more_lock_body",
    "onboarding_more_pause_title", "onboarding_more_pause_body",
]
for key in remove:
    doc["strings"].pop(key, None)

add = {
    "onboarding_swipe_title": (
        "Swipe Left and Right",
        "좌우로 넘겨보세요",
    ),
    "onboarding_swipe_body": (
        "Pause and end on the left. Calories, heart rate and time on the right. Your score sits in the middle.",
        "왼쪽은 일시정지와 종료, 오른쪽은 칼로리·심박·시간. 가운데가 점수입니다.",
    ),
    "onboarding_complication_title": (
        "Start in One Tap",
        "한 번 탭으로 빠르게",
    ),
    "onboarding_complication_body": (
        "Put the Ralli complication on your watch face and it opens right up. During a match the icon spins to show it's running.",
        "문자판에 Ralli 컴플리케이션을 올려두면 앱을 찾지 않고 바로 열립니다. 경기 중엔 아이콘이 돌아 진행 중임을 알려줍니다.",
    ),
}
for key, (en, ko) in add.items():
    doc["strings"][key] = collections.OrderedDict([
        ("extractionState", "manual"),
        ("localizations", collections.OrderedDict([
            ("en", {"stringUnit": {"state": "translated", "value": en}}),
            ("ko", {"stringUnit": {"state": "translated", "value": ko}}),
        ])),
    ])

doc["strings"] = collections.OrderedDict(sorted(doc["strings"].items()))
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("done")
EOF
```

- [ ] **Step 3: 결과를 확인한다**

```bash
python3 -c "
import json
d = json.load(open('Apps/TennisCounter/iOSApp/Localizable.xcstrings'))
s = d['strings']
gone = [k for k in s if k.startswith('onboarding_more')]
added = [k for k in ('onboarding_swipe_title','onboarding_swipe_body','onboarding_complication_title','onboarding_complication_body') if k in s]
print('남은 more 키 (0이어야 함):', gone)
print('추가된 키 (4개여야 함):', len(added))
for k in added:
    print(' ', k, '->', s[k]['localizations']['ko']['stringUnit']['value'][:20], '| extractionState:', s[k].get('extractionState'))
print('총 키:', len(s), '(107 - 9 + 4 = 102 여야 함)')
"
```

Expected: `남은 more 키: []` · `추가된 키: 4` · `총 키: 102` · 각 키의 `extractionState: manual`

- [ ] **Step 4: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Localizable.xcstrings
git commit -m "✨ 온보딩 문자열을 5페이지 구성에 맞춘다"
```

---

### Task 2: 페이지 5장 재구성

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/Onboarding/OnboardingView.swift`
- Delete: `Apps/TennisCounter/iOSApp/Features/Onboarding/Components/OnboardingFeatureListPage.swift`

**Interfaces:**
- Consumes: Task 1 의 문자열 키 4개. 기존 `OnboardingScreenshotPage(imageName:title:message:overlay:)` 와 `CrownArrowsOverlay()`
- Produces: 이미지 이름 `OnboardingCrown` · `OnboardingSwipe` · `OnboardingComplication` · `OnboardingHealth` · `OnboardingShare` (Task 3 이 이 이름으로 이미지셋을 만든다)

- [ ] **Step 1: `OnboardingView.swift` 를 아래 내용으로 바꾼다**

`lastPage` 가 3 에서 4 로 바뀌고, 4페이지 목록이 스와이프·컴플리케이션 두 장으로 갈린다.

```swift
import SwiftUI

/// 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 뜨는 5페이지.
///
/// 1~3 이 워치 사용법, 4~5 가 그 결과물이다. 시트가 아니라 루트 교체로 띄운다 —
/// 시트는 당겨서 닫히고 그러면 플래그가 안 남는다.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 4

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button(String(localized: "onboarding_skip"), action: onFinished)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    OnboardingScreenshotPage(
                        imageName: "OnboardingCrown",
                        title: String(localized: "onboarding_crown_title"),
                        message: String(localized: "onboarding_crown_body")
                    ) { CrownArrowsOverlay() }
                        .tag(0)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingSwipe",
                        title: String(localized: "onboarding_swipe_title"),
                        message: String(localized: "onboarding_swipe_body")
                    )
                    .tag(1)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingComplication",
                        title: String(localized: "onboarding_complication_title"),
                        message: String(localized: "onboarding_complication_body")
                    )
                    .tag(2)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingHealth",
                        title: String(localized: "onboarding_health_title"),
                        message: String(localized: "onboarding_health_body")
                    )
                    .tag(3)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingShare",
                        title: String(localized: "onboarding_share_title"),
                        message: String(localized: "onboarding_share_body")
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        onFinished()
                    }
                } label: {
                    Text(page < lastPage
                        ? String(localized: "onboarding_next")
                        : String(localized: "onboarding_start"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
```

- [ ] **Step 2: 목록 페이지 컴포넌트를 지운다**

```bash
rm Apps/TennisCounter/iOSApp/Features/Onboarding/Components/OnboardingFeatureListPage.swift
```

- [ ] **Step 3: 참조가 남아 있지 않은지 확인한다**

```bash
grep -rn "OnboardingFeatureListPage\|onboarding_more" Apps/TennisCounter/ --include="*.swift" --include="*.xcstrings"
```

Expected: 출력 없음. 하나라도 나오면 그 자리를 먼저 지운다.

- [ ] **Step 4: 빌드와 테스트**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tail -5
make lint && make format
```

Expected: `BUILD SUCCEEDED` · 기존 테스트 전부 통과 (`OnboardingGateTests` 4개 포함) · lint·format 통과

이미지 5장이 아직 없어 페이지들은 빈 자리로 보인다 — 정상이다. Task 3 에서 채운다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/Onboarding
git commit -m "✨ 온보딩을 워치 중심 5페이지로 재구성한다"
```

---

### Task 3: 이미지셋 5개

**선행:** 스크린샷 5종(ko/en)이 준비돼 있어야 한다. 만드는 방법과 규격은 스펙 §그림 참조.

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Assets.xcassets/OnboardingCrown.imageset` 외 4개

**Interfaces:**
- Consumes: Task 2 가 쓰는 이미지 이름 5개

- [ ] **Step 1: Xcode 에서 이미지셋을 만든다**

`YJApps.xcworkspace` 를 열고 `iOSApp/Assets.xcassets` 에서 **New Image Set** 5개를 만든다.
이름은 정확히 `OnboardingCrown` · `OnboardingSwipe` · `OnboardingComplication` · `OnboardingHealth` · `OnboardingShare`.

각각 선택한 뒤 Attributes inspector 에서

- **Localization** — Korean · English 체크 (언어별 슬롯이 생긴다)
- **Scales** — Single Scale

`OnboardingComplication` 을 한 벌로 끝내기로 했다면 그것만 Localization 을 켜지 않는다.

- [ ] **Step 2: 이미지를 넣는다**

각 이미지셋의 ko/en 슬롯에 해당 PNG 를 드롭한다.

- [ ] **Step 3: 들어갔는지 확인한다**

```bash
for n in Crown Swipe Complication Health Share; do
  echo "--- Onboarding$n"
  ls Apps/TennisCounter/iOSApp/Assets.xcassets/Onboarding$n.imageset/
done
```

Expected: 각 폴더에 `Contents.json` 과 PNG 파일. 로컬라이즈를 켠 이미지셋은 PNG 가 2개다.

- [ ] **Step 4: 시뮬레이터에서 그림이 나오는지 본다**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
xcrun simctl spawn "$IOS" defaults delete com.yj.TennisCounter onboardingSeenVersion
```

앱을 실행해 5장을 넘기며 **다섯 장 모두 그림이 나오는지, 크기가 들쭉날쭉하지 않은지** 본다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Assets.xcassets
git commit -m "✨ 온보딩 이미지 5장 (ko/en)"
```

---

### ~~Task 4: 크라운 화살표 위치 재조정~~ — 폐기

> **폐기.** 화살표·라벨·Rotate/Tap 그림을 Figma 이미지에 직접 구워 넣었다. 코드 오버레이가 남으면 화살표가
> 두 벌로 겹치므로 `CrownArrowsOverlay` 와 문자열 키 2개(`onboarding_crown_up`·`onboarding_crown_down`)를 지웠다.
> 아래 내용은 당시 계획의 기록이다.

**선행:** Task 3 (실제 `OnboardingCrown` 이미지가 있어야 맞출 수 있다)

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/Onboarding/Components/CrownArrowsOverlay.swift`

**왜 고치는가** — 지금 구현은 목업이 없다는 전제로 **이미지 안쪽 오른쪽 가장자리**에 고정 오프셋(`offset(y: -24)`)으로 붙인다. 목업을 쓰면 크라운이 그림 안에 실물로 그려져 있으므로, 화살표를 **그 크라운 높이에 맞춰야** 가리키는 대상이 분명해진다. 고정값 대신 이미지 높이에 대한 비율로 잡아 기기 크기와 무관하게 유지되도록 바꾼다.

- [ ] **Step 1: 비율 기반으로 바꾼다**

```swift
import SwiftUI

/// 워치 목업 위에 얹는 크라운 안내.
///
/// 라벨을 이미지에 굽지 않아야 문자열 카탈로그로 로컬라이즈된다.
/// 위치는 고정 오프셋이 아니라 이미지 높이에 대한 비율이다 — 기기마다 그림 크기가 달라진다.
struct CrownArrowsOverlay: View {
    /// 목업에서 크라운이 놓인 세로 위치 (이미지 높이 대비). 프리뷰에서 맞춘다.
    private let crownRatio: CGFloat = 0.38

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .trailing, spacing: 6) {
                arrow("arrow.up", label: String(localized: "onboarding_crown_up"), color: .green)
                arrow("arrow.down", label: String(localized: "onboarding_crown_down"), color: .orange)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
            .position(x: geo.size.width / 2, y: geo.size.height * crownRatio)
        }
    }

    private func arrow(_ symbol: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7), in: Capsule())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        Image("OnboardingCrown")
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 420)
            .padding(.horizontal, 32)
            .overlay { CrownArrowsOverlay() }
    }
}
```

- [ ] **Step 2: 프리뷰에서 `crownRatio` 를 맞춘다**

Xcode 에서 `CrownArrowsOverlay.swift` 의 프리뷰를 열고, 화살표 두 개의 가운데가 목업 크라운 높이에 오도록 `crownRatio` 를 조정한다. 목업의 크라운은 워치 본체 오른쪽, 세로 중앙보다 약간 위다.

- [ ] **Step 3: 빌드 · lint**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -3
make lint && make format
```

- [ ] **Step 4: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/Onboarding/Components/CrownArrowsOverlay.swift
git commit -m "🎨 크라운 화살표를 목업 크라운 높이에 맞춘다"
```

---

### Task 5: 확인과 마무리

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: 시뮬레이터에서 ko 로 전체 흐름을 본다**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcrun simctl spawn "$IOS" defaults delete com.yj.TennisCounter onboardingSeenVersion
```

앱을 지우고 다시 설치해 확인한다.

1. 런치 화면 → **온보딩이 뜬다**
2. 5장을 넘긴다 — 인디케이터 점이 **5개**, 1~4 페이지에 "건너뛰기", 5 페이지에서 사라짐
3. 5 페이지 버튼이 **"시작하기"** 로 바뀐다 → 누르면 메인 탭
4. 앱을 껐다 켜면 **온보딩이 안 뜬다**
5. 위 `defaults delete` 후 재실행 → 다시 뜸 → **"건너뛰기"** → 메인 탭 → 재실행하면 안 뜸

- [ ] **Step 2: en 으로 같은 흐름을 본다**

스킴 편집 → Run → Options → App Language 를 English 로 바꿔 실행한다. 다섯 장의 **영문 문구와 영문 이미지**가 나오는지 본다.

- [ ] **Step 3: `TODO.md` 를 갱신한다**

Ralli 표의 **#6 행**을 고친다. 상태를 `뼈대 완료 (PR #17) · 선행 #1·#4 완료 · 스크린샷(Task 4)만 남음` 에서 현재 상태로 바꾸고, 문서 칸에 이 플랜 링크를 더한다. 끝났다면 행에 취소선을 긋고 `**완료** (PR #n)` 으로 적는다.

"합류 후" 절의 `6번 스크린샷 3장 × ko/en (Task 4)` 행도 **5장**으로 바뀐 현실에 맞춰 고친다.

- [ ] **Step 4: 문서와 함께 커밋하고 PR 을 올린다**

스펙·플랜 문서는 **사용자 검토를 받은 뒤** 커밋한다 (루트 `CLAUDE.md`).

```bash
git add TODO.md \
        Apps/TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md \
        Apps/TennisCounter/docs/plans/ios/2026/2026-09-17-onboarding-watch-focused.md
git commit -m "📝 온보딩 5페이지 재구성 스펙·플랜"
git push -u origin feat/onboarding-watch-focused
```

PR 본문에는 5페이지 구성표와 "기능 목록 페이지를 왜 뺐는지"(스펙 §개정에서 바뀐 것)를 옮겨 적는다.

---

## 후속 (이번 PR 에 넣지 않는다)

- **설정 페이지 "사용법 다시 보기" (#8)** — `OnboardingView(onFinished: { dismiss() })` 를 시트로. 플래그는 건드리지 않는다.
- **크라운 애니메이션** — 정적 화살표가 약하면 1페이지만 회전 애니메이션으로 교체. `CrownArrowsOverlay` 만 바뀐다.
- **5페이지 그림 재검토** — 공유 시트에서는 카드가 썸네일로만 보인다. 실물을 보고 카드를 크게 보여주는 그림으로 바꿀지 판단한다.

## Self-Review

- **스펙 커버리지** — 5페이지 구성(Task 2), 목록 제거(Task 2 Step 2), 문자열 교체(Task 1), 그림 5장·로컬라이즈(Task 3), 목업 기준 화살표(Task 4), `version = 1` 유지(Global Constraints + 파일 표에 "변경 없음"), 노출 규칙·진입 위치 불변(파일 표), iOS 만(Global Constraints) ✅
- **타입 일관성** — `OnboardingScreenshotPage(imageName:title:message:overlay:)` 는 기존 시그니처 그대로 (`message` 이지 `body` 가 아니다 — `View.body` 와 겹쳐 컴파일이 안 된다) ✅. `CrownArrowsOverlay()` 인자 없음, Task 2·4 일치 ✅. 이미지 이름 5개가 Task 2 와 Task 3 에서 동일 ✅
- **문자열 키** — 제거 9 · 추가 4 · 유지 11 이 표와 Task 1 스크립트와 Task 2 코드에서 일치 ✅. 총 키 107 − 9 + 4 = 102 ✅
- **플레이스홀더 없음** — `crownRatio` 초기값 0.38 은 프리뷰에서 맞출 시작점이며, 맞추는 방법을 Step 2 에 적었다 ✅
