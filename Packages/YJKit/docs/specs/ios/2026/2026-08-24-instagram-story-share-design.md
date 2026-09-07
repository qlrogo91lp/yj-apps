# 인스타그램 스토리 공유 — 설계

작성일: 2026-08-24

## 목표

워크아웃 결과를 인스타그램 스토리에 올릴 수 있게 한다. 애플 기본 피트니스 앱의 공유는 정보가 빈약하다 —
운동 시간과 칼로리 정도에서 끝난다. YJKit은 `WorkoutResult`에 시간·활동 kcal·총 kcal·평균 심박·거리·걸음수를
이미 들고 있으므로, 이 중 핵심 지표를 담은 카드를 스토리 규격으로 렌더해 넘긴다.

두 앱(테니스·골프)이 공유하는 신규 라이브러리 타깃으로 만든다. 앱마다 카드 디자인이 갈리는 것을 막는 것이
별도 타깃으로 빼는 주된 이유다.

## 범위

포함:

- 신규 타깃 `WorkoutShareUI` (product 1개, target 1개, testTarget 1개)
- `WorkoutResult` → 스티커 PNG / 전체 PNG 렌더
- 인스타그램 스토리 딥링크 공유, 실패 시 iOS 공유 시트 폴백
- 앱별 강조색과 로고 주입

제외:

- 심박 그래프·스플릿·심박존 등 시계열 지표. `WorkoutCore`가 순간값만 수집하므로 별도 작업이 필요하다.
- 앱 고유 지표(테니스 스코어, 골프 타수)를 카드에 얹는 것.
- 공유 전 미리보기 화면.
- watchOS 공유. 워치에서는 인스타그램 공유 경로가 없다.

## 사용자 흐름

1. 앱의 워크아웃 결과 화면에서 공유 버튼을 누른다.
2. 인스타그램이 설치되어 있으면 스토리 편집기가 열린다. 배경은 앱 강조색에서 파생한 그라디언트, 그 위에 지표 카드가 스티커로 올라간다.
3. 사용자가 배경을 자기 사진·영상으로 바꾸고, 카드를 끌어서 배치하거나 핀치로 크기를 조절한다.
4. 인스타그램이 없거나 딥링크가 실패하면 iOS 공유 시트가 뜬다. 이때는 카드에 배경이 합성된 1080×1920 이미지를 넘긴다.

스티커 방식을 고른 이유는 사용자가 자기 사진 위에 지표를 얹을 수 있어서다. 배경 방식은 카드가 스토리 전체를
차지해 디자인 통제는 쉽지만 사용자 사진이 들어갈 자리가 없다.

## 공개 API

앱이 보는 것은 이게 전부다.

```swift
import WorkoutShareUI

WorkoutShareButton(
    result: workoutResult,
    style: WorkoutShareStyle(accentColor: .tennisGreen, logo: Image("AppLogo")),
    instagramAppID: "1234567890"
)
```

```swift
public struct WorkoutShareStyle {
    public let accentColor: Color
    public let logo: Image?
    public init(accentColor: Color, logo: Image? = nil)
}

public struct WorkoutShareButton: View {
    public init(result: WorkoutResult, style: WorkoutShareStyle, instagramAppID: String)
}
```

버튼 라벨·지표 라벨·레이아웃은 패키지가 소유한다. 앱은 문자열을 관리하지 않는다 — 기존 `WorkoutUI` 규칙과 같다.

`instagramAppID`를 파라미터로 받는 이유: Meta 개발자 대시보드에서 발급하는 앱별 식별자이고, 라이브러리가 알 수 없다.
`Info.plist`의 `LSApplicationQueriesSchemes` 설정도 같은 이유로 앱 책임이다.

## 모듈 구조

```
Sources/WorkoutShareUI/
  WorkoutShareButton.swift          // 유일한 public 진입점
  WorkoutShareStyle.swift           // public — accentColor, logo
  Card/
    WorkoutShareCard.swift          // internal SwiftUI 뷰 (스티커/전체 2모드)
    WorkoutShareCardModel.swift     // WorkoutResult → 표시 행 배열
  Render/
    WorkoutShareRenderer.swift      // ImageRenderer → UIImage
    StoryGradient.swift             // accentColor → 배경 그라디언트 hex 쌍
  Share/
    InstagramStoryLink.swift        // URL 생성 + 페이스트보드 딕셔너리 구성 (부수효과 없음)
    InstagramStoryShare.swift       // 페이스트보드 쓰기 + 앱 열기
    ShareSheet.swift                // UIActivityViewController 래퍼
  Resources/{en,ko}.lproj/Localizable.strings
```

타깃 전체를 `#if os(iOS)`로 감싼다. `WorkoutUI`가 iOS 전용 뷰를 격리하는 방식과 같다.

각 파일이 하나씩만 책임진다. `InstagramStoryLink`와 `InstagramStoryShare`를 나눈 것은 부수효과 격리 목적이다 —
실제 페이스트보드에 쓰거나 인스타그램을 띄우지 않고도 "무엇을 넘기는지"를 검증할 수 있다.

## 카드 내용

지표는 최대 3개다. 스티커는 사용자가 축소할 수 있으므로 적게 넣고 크게 보여주는 쪽이 유리하다.

| 순서 | 지표 | 출처 | 생략 조건 |
|---|---|---|---|
| 1 | 시간 | `durationSeconds` | 없음 — 항상 표시 |
| 2 | 활동 칼로리 | `caloriesBurned` | 값이 0이면 행 제외 |
| 3 | 평균 심박 | `averageHeartRate` | `nil`이면 행 제외 |

값이 없을 때 `--`를 보여주지 않고 **행 자체를 뺀다.** `--`는 측정 실패를 드러낼 뿐이고 스토리에 올릴 이미지에
들어갈 이유가 없다. 칼로리 0도 같은 규칙을 적용한다 — HealthKit이 종목에 따라 활동 에너지를 수집하지 않으면
0으로 남기 때문에, 0은 "칼로리를 안 태웠다"가 아니라 "수집되지 않았다"는 뜻이다.

`WorkoutShareCardModel`은 이 규칙을 순수 함수로 구현한다.

```swift
struct WorkoutShareCardModel: Equatable {
    struct Row: Equatable {
        let label: String
        let value: String
        let unit: String?
    }
    let rows: [Row]          // 1~3행
    init(result: WorkoutResult)
    // unit은 "kcal"·"bpm" 리터럴이다. 시간 행은 nil — 값에 콜론 포맷이 이미 단위를 담고 있다.
}
```

시간 포맷은 `WorkoutMetrics.formatSeconds`를 재사용한다 (1시간 미만 `42:18`, 이상 `1:30:00`).
칼로리와 심박은 정수로 반올림한다.

## 렌더링

**pt 캔버스 270 너비 × `ImageRenderer.scale = 4`** 로 통일한다. 나누어떨어지는 값이라 폰트 크기를 pt로
잡아도 반올림 오차가 생기지 않는다.

### 스티커 (배경 투명)

행 수와 로고 유무에 따라 높이가 변한다.

- 카드 상하 패딩 16pt씩 = 32pt
- 행 높이 42pt
- 로고 스트립(구분선 포함) 32pt, `logo`가 `nil`이면 0

| 구성 | pt | px (@4) |
|---|---|---|
| 3행 + 로고 | 270 × 190 | 1080 × 760 |
| 2행 + 로고 | 270 × 148 | 1080 × 592 |
| 1행 + 로고 | 270 × 106 | 1080 × 424 |
| 로고 없음 | 위에서 각 −32pt | 각 −128px |

3행 기준 1.42:1이다. Meta 권장 스티커 규격 640×480(4:3)에 가깝게 두면서 3행이 답답하지 않게 하는 절충이다.
인스타그램이 스티커를 어느 크기로 배치하는지는 문서에 없으므로 실기기에서 확인하고 조정한다.

각 행은 좌측 라벨(작게)과 우측 값(크게) 구조다. 하단 로고는 구분선 아래 중앙 정렬.

### 전체 이미지 (공유 시트 폴백용)

270 × 480 pt @4 = **1080 × 1920 px**. 같은 카드를 그라디언트 배경 위 세로 중앙에 놓는다.
스토리 안전 영역(상단 250px·하단 340px을 제외한 가운데 1080×1330 = 270×332.5pt) 안에 카드 최대 높이 190pt가
들어가므로 인스타그램 UI에 가리지 않는다.

### 그라디언트

`StoryGradient`가 `accentColor`에서 두 색을 뽑는다. 위는 accent 그대로, 아래는 각 RGB 채널에 0.6을 곱한 값이다
(알파는 무시하고 불투명으로 취급한다).

```swift
enum StoryGradient {
    static func hexPair(from accent: Color) -> (top: String, bottom: String)
}
```

이 hex 쌍을 딥링크에서는 `backgroundTopColor`/`backgroundBottomColor`로 넘기고, 폴백 이미지에서는 실제 배경으로
그린다. 두 경로가 같은 색으로 보이게 하는 장치다.

### 렌더 시점과 개수

탭 시점에 **한 장만** 만든다. 인스타그램이 있으면 스티커 PNG만, 없으면 전체 PNG만. 딥링크는 배경을 색으로
넘기므로 배경 이미지가 필요 없다. 1080×1920 한 장이 상당한 메모리를 차지하므로 두 장을 동시에 들고 있지 않는다.

`ImageRenderer`는 `@MainActor`라 메인 스레드에서 돈다. 텍스트 몇 줄짜리 카드는 밀리초 단위이므로 스피너는 두지
않고, 중복 탭만 막기 위해 렌더 중 버튼을 disabled로 둔다.

포맷은 PNG로 통일한다. 스티커는 투명도가 필요해 PNG가 필수이고, 전체 이미지도 그라디언트와 텍스트뿐이라
용량 문제가 없다.

## 공유 경로

```
탭
 └─ InstagramStoryShare.isAvailable ?
     ├─ true  → 스티커 PNG 렌더 → 페이스트보드에 3개 키 쓰기 (만료 5분)
     │           → instagram-stories://share?source_application=<appID> 열기
     │           → open 실패 시 폴백으로 진행
     └─ false → 전체 PNG 렌더 → 공유 시트 표시
```

페이스트보드 키는 Meta 규격을 따른다.

| 키 | 값 |
|---|---|
| `com.instagram.sharedSticker.stickerImage` | 스티커 PNG `Data` |
| `com.instagram.sharedSticker.backgroundTopColor` | `#RRGGBB` |
| `com.instagram.sharedSticker.backgroundBottomColor` | `#RRGGBB` |

`UIPasteboard.general.setItems(_:options:)`에 `.expirationDate`로 5분을 건다.

`isAvailable`은 `canOpenURL`로 판단한다. `Info.plist`에 `LSApplicationQueriesSchemes`가 없으면 무조건 `false`를
돌려주므로, **앱이 설정을 빼먹어도 크래시나 무동작이 아니라 공유 시트로 폴백한다.** 인스타그램 미설치도 같은
경로를 탄다. 설정 누락과 미설치를 구분할 필요가 없다.

폴백은 `.sheet`로 `UIActivityViewController` 래퍼를 띄운다. 렌더가 탭 이후에 일어나므로 `ShareLink`(구성 시점에
아이템이 필요)가 아니라 `@State`에 이미지를 담고 `.sheet(item:)`으로 여는 방식을 쓴다.

## 실패 처리

`ImageRenderer.uiImage`가 `nil`을 반환하는 것은 사실상 병리적인 경우지만, 조용히 아무 일도 일어나지 않으면
사용자는 버튼이 고장난 줄 안다. `os.Logger`로 남기고 DEBUG에서는 `assertionFailure`로 즉시 드러나게 한다.
릴리스에서는 무동작 — 알럿을 띄울 상황은 아니다.

`instagramAppID`가 빈 문자열이면 `InstagramStoryLink.storyURL`이 `nil`을 반환해 폴백으로 넘어간다.
앱의 설정 실수가 조용히 통과하지 않게 하는 장치다.

## 로컬라이징

`Resources/{en,ko}.lproj/Localizable.strings`, `String(localized:bundle: .module)` — `WorkoutUI`와 같은 방식.

| 키 | ko | en |
|---|---|---|
| `share_button` | 스토리에 공유 | Share to story |
| `share_metric_duration` | 시간 | Time |
| `share_metric_calories` | 활동 | Active |
| `share_metric_heart_rate` | 심박 | Avg HR |

## 테스트

이 저장소의 테스트는 iOS 시뮬레이터 destination으로 실행한다. 명령은 모노레포 루트에서 돌린다.

```bash
make kit-test
```

(`swift test`는 현재 `PersistenceCore`의 macOS 가용성 문제로 실패한다. 이번 작업과 무관한 기존 문제다.)

테스트 타깃 `WorkoutShareUITests`. 테스트 파일도 `#if os(iOS)`로 감싼다.

**`WorkoutShareCardModelTests`**

- 3개 다 유효 → 3행, 순서는 시간 → 활동 → 심박
- `averageHeartRate == nil` → 2행
- `caloriesBurned == 0` → 해당 행 제외
- 칼로리 0이면서 심박 `nil` → 1행 (시간만)
- 1시간 미만 `42:18`, 1시간 이상 `1:30:00`
- 칼로리 반올림 `312.7 → "313"`

**`StoryGradientTests`**

- `hexPair`가 `#` 포함 6자리 hex 두 개를 반환
- 흰색 입력 → top `#FFFFFF`, bottom `#999999` (255 × 0.6 = 153)
- 검정 입력 → top·bottom 모두 `#000000` (곱셈이라 더 어두워질 여지가 없다)

**`InstagramStoryLinkTests`**

- `storyURL(appID: "123")` → `instagram-stories://share?source_application=123`
- `storyURL(appID: "")` → `nil`
- 페이스트보드 아이템이 정확히 3키를 담는다
- `setItems` 형태에 맞는 원소 1개짜리 `[[String: Any]]`이다

**유닛테스트로 못 잡는 것**

`#Preview`로 카드를 시각 확인한다 — 스티커/전체 × 1~3행 × 로고 유무.

실기기 확인 3건:

1. 딥링크로 스토리 편집기가 실제로 열리는가
2. 인스타그램이 스티커를 어느 크기로 배치하는가 (필요 시 캔버스 비율 조정)
3. 붙여넣기 프롬프트("다른 앱에서 붙여넣기")가 뜨는가

3번은 iOS 16부터 앱별 페이스트보드 권한이 생기면서 가능해진 시나리오이고, 문서로 확답이 나오지 않는다.
만약 뜬다면 프롬프트 자체를 없앨 방법은 없다(사용자 설정 영역). 그 경우 공유 시트를 기본 경로로 바꾸는 선택지를
검토한다.

## Package.swift 변경

기존 항목은 건드리지 않고 셋을 추가한다.

- product `.library(name: "WorkoutShareUI", targets: ["WorkoutShareUI"])`
- target `WorkoutShareUI` — `dependencies: ["WorkoutCore"]`, `resources: [.process("Resources")]`, `swiftLanguageMode(.v5)`
- testTarget `WorkoutShareUITests` — `dependencies: ["WorkoutShareUI"]`, `swiftLanguageMode(.v5)`

## README에 추가할 소비자 책임

기존 `WorkoutUI` 절의 체크리스트 형식을 따른다.

- [ ] **`Info.plist`에 `LSApplicationQueriesSchemes` → `instagram-stories`를 추가한다.** 빠지면 크래시가 아니라 항상 공유 시트로 폴백된다 — 조용히 동작이 달라지므로 확인할 것.
- [ ] **Meta 개발자 대시보드에서 Facebook App ID를 발급해 `instagramAppID`로 주입한다.** Meta 문서상 2022년 10월부터 필수다.
- [ ] **`WorkoutResult`는 워크아웃 누적값으로 넘긴다.** 기존 규칙과 같다.
- [ ] **`accentColor`에서 배경 그라디언트가 파생된다.** 너무 밝은 색을 주면 흰 텍스트와 대비가 떨어진다.
- [ ] **iOS 전용이다.** 워치 타깃에서 임포트해도 심볼이 없다.
