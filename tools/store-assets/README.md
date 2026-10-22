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
- **워치 스크린샷 4장** — 피그마에서 3x 로 내보낸다 (1266×1542). 저장소에는 넣지 않는다 (스토어 이미지 원본은 피그마가 갖는다).
  `tools/store-assets/inputs/` 에 `watch-{home,workout,control,result}-global.png` 로 둔다. `inputs/` 는 git 이 무시한다.

## 순서 (하루치 검색 결과 영어판)

모든 명령은 `tools/store-assets/` 에서 실행한다.

```bash
# 1. 시계를 4:16 으로 통일 → inputs/watch-*-416.png
python3 watch-images/unify-clock.py inputs inputs

# 2. 시안 → 프레임 추출용 페이지 (out/ 은 git 이 무시한다)
python3 video/build-render.py mockups/haruchi-search-en.html out/haruchi-en

# 3. 헤드리스 크롬으로 프레임 360장 (약 16초, 500MB)
python3 video/capture.py out/haruchi-en

# 4. mp4 로 묶기 (무음 AAC 트랙 포함)
swift -swift-version 5 video/encode.swift out/haruchi-en/frames out/haruchi-search-en.mp4 30

# 5. 확인 — 0 · 3.2 · 6 · 7.9초 프레임을 꺼낸다. 확대해서 글자가 깨지지 않는지 본다
swift -swift-version 5 video/grab.swift out/haruchi-search-en.mp4 out
```

`mockups/haruchi-search-en.html` 은 브라우저로 열면 움직이는 시안으로 보인다 (`inputs/` 가 있어야 워치가 나온다).
화면 구성(캡션 · 탭 위치 · 타이밍)은 이 파일 안의 `haruchiSearch3` 함수가 갖는다.

## 파일

| 경로 | 하는 일 |
|---|---|
| `mockups/` | 캔버스로 그리는 움직이는 시안 |
| `video/build-render.py` | 시안 → 프레임 추출 페이지 |
| `video/capture.py` | 크롬이 그린 프레임을 PNG 로 받는다 |
| `video/encode.swift` | PNG → H.264 mp4 (AVFoundation. ffmpeg 불필요) |
| `video/grab.swift` | 완성된 mp4 에서 프레임을 꺼내 화질 확인 |
| `watch-images/unify-clock.py` | 워치 스크린샷의 시계 통일 |
| `watch-images/measure.py` | 워치 화면·버튼 좌표 재기 (시안의 `SCR` · `TAP` 값을 새로 잴 때) |

## 한계

- 폰 화면은 코드로 그린 것이라 앱 화면이 바뀌면 시안을 손으로 맞춘다.
- 영어판만 있다. 한국어판은 한국어 워치 스크린샷과 `ko` 캡션이 필요하다 (`build-render.py` 의 3번째 인자 `ko`).
- 워치 화면의 "Strength 0 min" 등 스크린샷에 찍힌 문구는 그대로 쓴다.
