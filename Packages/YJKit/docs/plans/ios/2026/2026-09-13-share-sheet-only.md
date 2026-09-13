# WorkoutShareUI — 인스타 스토리 경로 제거, 공유 시트만 남기기

- 날짜: 2026-09-13
- 브랜치: `refactor/share-sheet-only` (PR 하나 — 커밋은 Kit / Ralli / 하루치로 나눈다)
- 선행 문서: [인스타 스토리 공유 스펙](../../../specs/ios/2026/2026-08-24-instagram-story-share-design.md) · [플랜](2026-08-25-instagram-story-share.md)

## 왜

Meta 개발자 계정 발급에 실패했다. 2023년 1월부터 `instagram-stories://` 딥링크는 Facebook App ID
없이는 콘텐츠를 넘기지 않는다. 지금 코드는 App ID가 빈 문자열이면 공유 시트로 폴백하므로
**동작은 이미 공유 시트**다. 남은 것은 실제 동작과 어긋나는 흔적들이다.

- 버튼 라벨 "스토리에 공유"
- Ralli 온보딩 문구 "카드는 스티커라 사진 위에 자유롭게 놓을 수 있습니다"
- 두 앱 Info.plist 의 `instagram-stories` 스킴 등록
- 쓰이지 않는 스티커 렌더 · 딥링크 · 페이스트보드 코드

코드를 두고 빈 값으로 두는 안(A)도 있었으나, 걷어내는 쪽(B)을 골랐다. 다음 작업인 카드 대비
(배경색을 Kit 이 소유) 가 신경 쓸 곳이 전체 이미지 한 장으로 줄어든다. App ID 를 나중에 받으면
git 에서 되살린다.

## PR 을 하나로 묶는 이유

`WorkoutShareButton` 생성자에서 `instagramAppID` 가 빠지면 Ralli 가 즉시 빌드 실패한다. 로컬 SPM
패키지라 Kit 만 먼저 머지할 수 없다.

## 바꿀 파일

### YJKit — `Packages/YJKit/`

| 파일 | 할 일 |
|---|---|
| `Sources/WorkoutShareUI/Share/InstagramStoryShare.swift` | 삭제 |
| `Sources/WorkoutShareUI/Share/InstagramStoryLink.swift` | 삭제 |
| `Tests/WorkoutShareUITests/InstagramStoryLinkTests.swift` | 삭제 |
| `Sources/WorkoutShareUI/WorkoutShareButton.swift` | `instagramAppID` 제거. 탭 → 이미지 렌더 → 공유 시트 한 경로 |
| `Sources/WorkoutShareUI/Card/WorkoutShareCard.swift` | `Mode` · `.sticker` 분기 제거. 그라디언트 전체 배경 + 카드 한 종류 |
| `Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift` | `stickerImage` 제거, `image(model:style:)` 하나 |
| `Sources/WorkoutShareUI/Render/StoryGradient.swift` | `hexPair` 제거, `colors(from:)` 만 |
| `Sources/WorkoutShareUI/Render/ShareCanvas.swift` | `stickerSize` → `cardSize` |
| `Tests/WorkoutShareUITests/WorkoutShareRendererTests.swift` | 스티커 테스트 제거, 1080×1920 만 |
| `Tests/WorkoutShareUITests/ShareCanvasTests.swift` | 이름 반영, 인스타 안전 영역 테스트 제거 |
| `Tests/WorkoutShareUITests/StoryGradientTests.swift` | `colors` 기준으로 재작성 |
| `Sources/WorkoutShareUI/Resources/{ko,en}.lproj/Localizable.strings` | `share_button` → "공유" / "Share" |
| `README.md` | WorkoutShareUI 절 갱신, `LSApplicationQueriesSchemes` 항목 · §Facebook App ID 발급 삭제 |

### Ralli — `Apps/TennisCounter/`

| 파일 | 할 일 |
|---|---|
| `iOSApp/Components/MatchShareButton.swift` | `instagramAppID` 상수 · 인자 제거 |
| `TennisCounter-Info.plist` | `LSApplicationQueriesSchemes` 제거 |
| `iOSApp/Localizable.xcstrings` | `onboarding_share_title` · `onboarding_share_body` 에서 인스타·스티커 표현 제거 |

### 하루치 — `Apps/HaruchiFit/`

| 파일 | 할 일 |
|---|---|
| `HaruchiFit-Info.plist` | 스킴 키 · 주석 제거. 빈 `<dict/>` 로 남긴다 — 파일을 지우면 pbxproj `INFOPLIST_FILE` 도 고쳐야 한다 |

### 문서

- `TODO.md` — App ID 발급 행 취소선, #1 실기기 확인 내용 변경, 카드 대비 절에 스티커 제거 반영
- 이전 인스타 스펙 · 플랜, Xcode 타깃 규약의 `instagram-stories` 예시는 **기록이므로 고치지 않는다**

## 검증

- `make kit-test KIT_DESTINATION="id=$IOS"`
- Ralli iOS 테스트 (`TennisCounter` 스킴)
- 하루치 iOS 빌드 (`HaruchiFit` 스킴)
- `make lint` · `make format`
- 시뮬레이터에서 기록 상세 → 공유 → 공유 시트 미리보기로 카드 확인 (카드 대비 작업의 첫 단계를 겸한다)

## 실기기 확인 (남는 것)

- 공유 시트에서 인스타그램을 골랐을 때 **스토리로 올리는 선택지가 있는지** — 문서로 확인하지 못했다
