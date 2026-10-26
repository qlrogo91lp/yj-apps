# store-assets

App Store 크리에이티브 에셋(제품 페이지 헤더 · 검색 결과) 영상을 만드는 도구. 앱 코드가 아니고 Xcode 프로젝트에 속하지 않는다 —
앱 폴더 밖이라 `PBXFileSystemSynchronizedRootGroup` 자동 스캔 대상이 아니다. 터미널에서만 실행한다.

## 규격 (App Store Connect — 검색 결과)

| 항목 | 값 |
|---|---|
| 크기 | 3:2, 1920×1280 ~ 3840×2560 (이 도구는 2880×1920) |
| 프레임 | 30 또는 60fps |
| 길이 | 5~30초, 반복 재생 (이음매 없게) |
| 형식 | .mov / .m4v / .mp4 |
| 소리 | 음소거 고정 — 소리 없이 읽혀야 한다 |

가격·URL·수상 표기 금지, 4+ 등급 기준. 헤더는 21:9(3840×1646). 출처는 루트 `TODO.md` 의 크리에이티브 에셋 행.

## 준비물

- macOS + Xcode (Swift), Google Chrome, Python 3 + Pillow (`pip3 install --user Pillow`)
- 화면 스크린샷을 쓰는 시안이면 그 이미지 — 피그마에서 3x 로 내보낸다. 저장소에는 넣지 않는다
  (스토어 이미지 원본은 피그마가 갖는다). `tools/store-assets/inputs/` 에 둔다. `inputs/` · `out/` 은 git 이 무시한다.

## 순서

모든 명령은 `tools/store-assets/` 에서 실행한다. 새 영상마다 바뀌는 건 **시안 HTML 과 명령 인자뿐** — 스크립트는 고치지 않는다.

```bash
# 0. (워치 스크린샷을 쓸 때만) 시계를 기준 이미지의 시각으로 통일 → inputs/<이름>-clock.png
python3 watch-images/unify-clock.py --ref inputs/<기준>.png --out inputs inputs/<이미지>.png ...

# 1. 시안 → 프레임 추출 페이지. --seconds 는 장면의 반복 주기와 같아야 이음매가 없다
python3 video/build-render.py mockups/ralli-header.html out/ralli-header \
  --scene ralliHeaderWatch --size 3840x1646 --seconds 8.8 --images inputs/watch-match-global.png
#    이미지를 쓰지 않는 시안이면 --images 를 뺀다

# 2. 헤드리스 크롬으로 프레임 PNG
python3 video/capture.py out/ralli-header

# 3. mp4 로 묶기 (무음 AAC 트랙 포함)
swift -swift-version 5 video/encode.swift out/ralli-header/frames out/ralli-header.mp4 30

# 4. 확인 — 0 · 3.2 · 6 · 7.9초 프레임을 꺼내 확대해 본다
swift -swift-version 5 video/grab.swift out/ralli-header.mp4 out
```

시안 HTML 은 브라우저로 열면 움직이는 시안으로 보인다. 시안이 지킬 약속은 `video/build-render.py` 맨 위 주석에 있다
(`const scenes = { ... };` 선언, 장면 함수 `(ctx, W, H, t, lang)`, 이미지 경로 `../inputs/`).

## 시안

| 파일 | 장면 | 크기 · 길이 | 상태 |
|---|---|---|---|
| `mockups/ralli-header.html` | **`ralliHeaderWatch`** — 코트 + 워치. 워치를 탭하면 코트 점수가 따라 바뀐다 (40:40 ↔ AD). 입력 `inputs/watch-match-global.png` | 3840x1646 · 8.8초 | **확정 (10-25)** |
| 〃 | `ralliHeader` — 코트만 (처음 시안, 비교용) | 3840x1646 · 8.8초 | 쓰지 않음 |
| `mockups/ralli-search-en.html` | `ralliSearch` — 워치 하나. 화면 탭과 크라운(위 ME · 아래 OPP)으로 번갈아 점수를 넣는다. 입력 `inputs/watch-match-global.png` | 2880x1920 · 8.8초 | **확정 (10-25)** |
| `mockups/ralli-onboarding-crown.html` | `ralliOnboardingCrown` — 검색 결과 장면에서 캡션을 뺀 것. 앱 온보딩 1페이지에 쓴다. 입력 `inputs/watch-match-{en,ko}.png` (`--lang ko\|en`) | 1200x1500 (4:5) · 8.8초 | **적용 (10-25)** |
| `mockups/golf-header.html` | `golfHeader` — 골프 코스 + 실제 워치. 샷·퍼팅 후 탭하면 숫자와 초록·주황 링이 채워진다. 입력 `inputs/golf-watch.png` · `inputs/golf-swing-icon.png` | 3840x1646 · 10초 | **시안 승인 (10-26)** · mp4 출력 전 |
| `mockups/golf-search.html` | `golfSearch` — 왼쪽 문구 + 크게 보이는 실제 워치. 타수 입력 → 퍼팅 전환 → 퍼팅 입력. 헤더와 같은 입력 이미지, 한국어·영어 전환 (`--lang ko\|en`) | 2880x1920 · 10초 | **제작 완료 (10-26)** · 한국어·영어 MP4 |
| `mockups/golf-onboarding.html` | `golfOnboardingMode` — 검색 장면에서 왼쪽 문구를 뺀 워치 하나. 타수 입력 → 퍼팅 전환(모드 버튼 탭을 크게) → 퍼팅 입력. 앱 온보딩 1페이지에 쓴다. 입력 `inputs/golf-watch.png` · `inputs/golf-swing-icon.png` | 1200x1500 (4:5) · 10초 | **적용 (10-26)** · 언어 공통 한 벌 |

워치 숫자는 스크린샷 한 장(30:15) 위에 코드로 다시 그린다. 워치 시스템 글꼴 `"SF Compact"` 를 캔버스에서 쓸 수 있어 원본과 같게 나온다.
배경이 단색인 자리(ME/OPP · Undo · 연결 끊김 아이콘)는 배경색으로 덮는다 — 헤더는 전부, 검색 결과는 실제 화면이라 아이콘만. 좌표는 시안의 `WI`(화면) · `CROWN`(크라운)에 있다.

하루치 헤더 · 검색 결과(영어판)는 업로드를 마쳐 시안을 지웠다. 검색 결과 시안은 커밋 `03da6f7` 의
`tools/store-assets/mockups/haruchi-search-en.html` 로 되살릴 수 있다
(`git show 03da6f7:tools/store-assets/mockups/haruchi-search-en.html > mockups/haruchi-search-en.html`).

골프 워치 목업은 **원본 비율·외곽·스트랩을 그대로** 쓴다. 배경을 오려내거나 스트랩 끝을 흐리게 하지 않는다.
검은 배경에 원본을 직접 그리고 화면 안 숫자·링·입력 모드만 덧그린다. `golf-swing-icon.png`는 앱과 같은
`figure.golf` 시스템 심벌이다. 검색 시안은 헤더에서 승인한 워치 렌더링을 그대로 사용한다.

## 파일

| 경로 | 하는 일 |
|---|---|
| `mockups/` | 캔버스로 그리는 움직이는 시안 |
| `video/build-render.py` | 시안 → 프레임 추출 페이지 (장면 · 크기 · 길이를 인자로) |
| `video/capture.py` | 크롬이 그린 프레임을 PNG 로 받는다 |
| `video/encode.swift` | PNG → H.264 mp4 (AVFoundation. ffmpeg 불필요) |
| `video/grab.swift` | 완성된 mp4 에서 프레임을 꺼내 화질 확인 |
| `watch-images/unify-clock.py` | 워치 스크린샷의 시계 통일 |
| `watch-images/measure.py` | 워치 화면·버튼 좌표 재기 (시안의 화면 영역 · 탭 위치를 잴 때) |

## 한계

- 화면을 코드로 그린 부분(폰 등)은 앱 화면이 바뀌면 시안을 손으로 맞춘다.
- 스크린샷에 찍힌 문구·숫자는 그대로 나온다. 바꾸려면 다시 찍는다.

## 앱 안에서 재생할 영상 (온보딩)

스토어 영상과 달리 **소리 트랙이 없어야** 하므로 인코더에 `no-audio` 를 붙인다. 결과는
`Apps/TennisCounter/iOSApp/Resources/Onboarding/onboarding-crown-{en,ko}.mp4` 로 복사한다.

```bash
for L in ko en; do
  python3 video/build-render.py mockups/ralli-onboarding-crown.html out/onb-$L \
    --scene ralliOnboardingCrown --size 1200x1500 --seconds 8.8 --lang $L \
    --images inputs/watch-match-en.png inputs/watch-match-ko.png
  python3 video/capture.py out/onb-$L
  swift -swift-version 5 video/encode.swift out/onb-$L/frames out/onboarding-crown-$L.mp4 30 no-audio
done
```

정지 이미지(`OnboardingCrown` 에셋 · 시스템 "동작 줄이기" 를 켠 사용자에게 보인다)는 같은 프레임 중 96번(3.2초, 크라운 화살표가 보이는 순간)을
`out/onb-$L/frames/f00096.png` 에서 꺼내 `crown-$L.png` 로 바꾼다.

## GolfCounter 검색 영상 출력본

승인된 `mockups/golf-search.html`에서 출력한 최종 파일:

- 한국어: `out/golf-search-ko.mp4`
- 영어: `out/golf-search-en.mp4`
- 공통: 2880×1920 · 30fps · 10초 · H.264 + 무음 AAC. App Store 업로드 전.

재출력은 위 제작 순서에서 장면 `golfSearch`, 크기 `2880x1920`, 길이 `10`,
언어 `--lang ko` 또는 `--lang en`, 입력 `inputs/golf-watch.png inputs/golf-swing-icon.png`를 사용한다.

### GolfCounter 온보딩 영상

```bash
python3 video/build-render.py mockups/golf-onboarding.html out/onb-golf-mode \
  --scene golfOnboardingMode --size 1200x1500 --seconds 10 \
  --images inputs/golf-watch.png inputs/golf-swing-icon.png
python3 video/capture.py out/onb-golf-mode
swift -swift-version 5 video/encode.swift out/onb-golf-mode/frames out/onboarding-mode.mp4 30 no-audio
```

결과는 `Apps/GolfCounter/iOSApp/Resources/Onboarding/onboarding-mode.mp4` 로 복사한다. 정지 이미지(`OnboardingMode`)는 `grab.swift` 가
뽑은 6.0초 프레임(퍼팅 모드로 바뀐 뒤)이다.
