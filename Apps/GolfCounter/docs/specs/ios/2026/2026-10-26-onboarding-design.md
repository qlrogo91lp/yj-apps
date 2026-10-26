# iOS 온보딩 설계

2026-10-26 작성 · 검토 대기.
참고: Ralli 온보딩 [스펙](../../../../../TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md) ·
코드 `Apps/TennisCounter/iOSApp/Features/Onboarding/`.

## 목적

**사용자가 워치에서 GolfCounter 를 제대로 쓰게 만든다.** Ralli 와 같은 목표다.

GolfCounter 는 입력이 전부 워치에서 일어나고 폰은 기록·통계만 본다. 새 사용자가 막히는 곳은 두 군데다.

1. **폰 앱만 열고 멈춘다** — 기록 탭이 비어 있는데 무엇을 해야 하는지 모른다. 라운드는 워치에서 시작한다는 걸 모른다.
2. **퍼팅 모드 전환을 모른다** — 카운터 화면 오른쪽 위의 원형 버튼(초록 `figure.golf` = 스윙, 주황 `flag.fill` = 퍼팅)이
   글자 없이 색·아이콘뿐이라 모드 버튼인지 알아차리기 어렵다. 모르면 타수만 세고 퍼팅 수가 비는 라운드가 된다.

**2 가 가장 중요하다.** 사용자는 치기 전에 그 샷의 모드를 고른다 — 퍼팅하기 전에 버튼을 누른다.
이 동작을 영상으로 보여 주는 것이 이 온보딩의 핵심이다. 1 은 따로 페이지를 두지 않고 1페이지 문구에 녹인다.

설득이 아니라 안내다. 3초 훑고 닫아도 "워치에서 탭, 퍼팅 전엔 버튼" 은 남아야 한다.

## 페이지 — 4장

| # | 내용 | 그림 |
|---|---|---|
| 1 | **점수 올리기 + 퍼팅 모드 전환.** 라운드는 워치에서 시작한다는 안내를 문구에 포함 | **반복 영상** — 탭으로 타수 → 오른쪽 위 버튼으로 퍼팅 전환 → 탭으로 퍼팅 |
| 2 | **크라운으로 스코어카드 보기** | **반복 영상** — 카운터 화면에서 크라운을 돌리면 홀별 스코어카드(9홀씩)로 내려간다 |
| 3 | **컴플리케이션** — 문자판에서 한 번 탭으로 연다 | 정지 이미지 + Ralli 와 같은 흰 펄스 링 |
| 4 | **건강 앱에 기록된다** | 정지 이미지 — 피트니스 앱의 GolfCounter 골프 워크아웃 상세 |

**1~2 가 워치 사용법, 3 이 빠른 진입, 4 가 결과물** 순서다. Ralli 와 같은 흐름이다.

**넣지 않는 페이지**
- **공유** — 사용자가 뺐다 (Ralli 5페이지에 해당)
- **좌우 스와이프** (컨트롤 ↔ 카운터 ↔ 지표) — 사용자가 고른 건 크라운 쪽이다
- **"라운드는 워치에서 시작" 단독 페이지** — 1페이지 문구로 흡수
- 기능 목록 페이지 — Ralli 에서 "별로 없어도 되는 페이지" 로 뺀 것과 같은 이유

### 문구 초안 (사용자 확인 필요)

| # | 제목 ko / en | 본문 ko / en |
|---|---|---|
| 1 | 손목으로 타수 기록 / Count strokes on your wrist | 라운드는 워치에서 시작해요. 칠 때마다 화면을 톡, 퍼팅 전엔 오른쪽 위 버튼으로 퍼팅 모드로 바꾸세요. / Start your round on Apple Watch. Tap after every shot — before you putt, switch to putting with the top-right button. |
| 2 | 크라운으로 스코어카드 / Turn the crown for your scorecard | 카운터 화면에서 크라운을 돌리면 홀별 타수와 퍼팅이 9홀씩 보여요. / From the counter, turn the Digital Crown to see strokes and putts for every hole, nine at a time. |
| 3 | 한 번 탭으로 바로 시작 / Start with one tap | 문자판에 GolfCounter 컴플리케이션을 올려두면 앱을 찾지 않고 바로 열려요. / Add the GolfCounter complication to your watch face and open it in one tap. |
| 4 | 건강 앱에 기록돼요 / Saved to Health | 라운드마다 골프 운동으로 저장돼요. 칼로리·심박·시간이 건강 앱에 쌓여요. / Every round is saved as a golf workout, with calories, heart rate and time in Health. |

본문에 "컴플리케이션" 을 그대로 쓰는 이유는 Ralli 와 같다 — 한국어 워치 설정의 공식 용어라 문자판에서 같은 단어를 찾게 된다.
"치기 전" 동작을 문구가 정확히 말해야 한다 — **누른 뒤의 샷이 퍼팅으로 기록된다.** "그린에 올라가면" 처럼 위치로 말하지 않는다.

## 형식 — Ralli 와 같다

- `TabView(.page)` 4장, 하단 페이지 인디케이터
- 1~3 페이지: 우상단 **건너뛰기**, 하단 **다음** / 4 페이지: 하단 **시작하기**
- 건너뛰기·시작하기 모두 플래그를 저장한다. 강제로 다시 보여 주지 않는다
- 검정 배경 + 브랜드 색 버튼 (`Color.brand` #00520A 위에 `Color.brandForeground`)
- 영상 페이지는 그 페이지가 보일 때만 재생한다 (`isActive`). 시스템 "동작 줄이기" 가 켜져 있으면 영상 대신 정지 이미지

**[내 판단] 골프 앱은 다크 고정이 아니다** (Ralli 는 `UIUserInterfaceStyle = Dark`). 영상·목업 배경이 검정이라
온보딩 화면에만 `.preferredColorScheme(.dark)` 를 걸어 라이트 모드에서도 검정 배경 + 흰 글자로 보이게 한다. 앱 전체는 건드리지 않는다.

## 노출 규칙 — Ralli 와 같다

```
OnboardingGate.version = 1           // 내용이 바뀌면 올린다
UserDefaults "onboardingSeenVersion" // 기본 0
표시 조건: seenVersion < version
닫을 때:  seenVersion = version
```

| 사용자 | 저장값 | 결과 |
|---|---|---|
| 새 설치 | 0 | 뜸 |
| 2.1.1 이하에서 업데이트 | 0 | **뜸 — 사용자 결정 (10-26).** 기존 사용자도 퍼팅 모드를 모를 수 있다 |
| 이번 버전에서 봄 | 1 | 안 뜸 |

저장소는 `UserDefaults.standard`, iCloud 동기화 없음. 삭제 후 재설치하면 다시 뜬다.

## 진입 위치

`GolfCounterApp` — `LaunchScreenView` 직후, `MainTabView` 앞. 시트로 띄우지 않는다 (당겨 닫으면 플래그가 안 남는다).

```
isLaunching → LaunchScreenView
    ↓
seenVersion < version → OnboardingView(onFinished: seenVersion = version)
    ↓
MainTabView
```

## 플랫폼 — iOS 만

워치에는 온보딩을 두지 않는다. Ralli 와 같은 이유 — 화면이 좁고, 워치 사용법은 폰 1~3페이지가 보여 준다.

## 코드 배치

Ralli 의 온보딩을 **골프 앱 안으로 복사**한다. 이번에는 YJKit 으로 올리지 않는다 — **사용자 결정 (10-26).**
세 앱(Ralli · 하루치 · 골프)이 같은 틀을 쓰므로 공통화는 하되, 세 앱 모두 현재 출시분 심사가 끝난 뒤 별도 리팩터링으로
새 버전에 싣는다 (루트 `TODO.md` YJKit 절 "온보딩 틀 공통화"). 그때 옮기기 쉽도록 Ralli 코드에서 구조를 바꾸지 않고 복사한다.

```
Apps/GolfCounter/iOSApp/
├─ Features/Onboarding/
│  ├─ OnboardingView.swift          4페이지
│  ├─ OnboardingGate.swift          version = 1
│  └─ Components/
│     ├─ LoopingVideo.swift         Ralli 그대로
│     ├─ OnboardingScreenshotPage.swift   Ralli 그대로 (그림 박스 비율 0.80 · cornerRadius 24)
│     └─ OnboardingComplicationRing.swift 링 위치만 골프 이미지에 맞춘다
├─ Resources/Onboarding/            mp4
├─ Assets.xcassets/Onboarding*.imageset   정지 이미지 (동작 줄이기용 포함)
└─ {ko,en}.lproj/Localizable.strings      onboarding_* 키 — 골프는 xcstrings 가 아니라 .strings 를 쓴다
```

`iOSApp.swift` 에 `@AppStorage("onboardingSeenVersion")` 과 분기를 더한다. 버튼 문구 키(`onboarding_skip` / `_next` / `_start`)도 같이.

## 그림

### 공통

- 워치 렌더링은 **스토어 영상에서 승인한 것**을 쓴다 — `tools/store-assets/inputs/golf-watch.png` (원본 비율·외곽·스트랩 그대로, 검은 배경).
  스토어 헤더·검색 영상과 같은 워치가 온보딩에도 나온다
- 규격은 `OnboardingScreenshotPage` 의 그림 박스(비율 0.80 = **4:5**)에 맞춘다. Ralli 1페이지 영상과 같은 **1200×1500**
- 앱 안 영상은 **소리 트랙 없이** 인코딩한다 (`encode.swift ... no-audio`). 30fps
- 제작은 `tools/store-assets/` 도구로 한다. 시안 HTML 을 새로 두고 README 시안 표 · "앱 안에서 재생할 영상" 절에 추가한다

### 1 — 모드 전환 영상

**[내 판단]** 새로 찍지 않고 **승인된 `golf-search` 장면에서 왼쪽 문구를 뺀 것**을 쓴다. Ralli 1페이지(`ralliOnboardingCrown`)가
검색 결과 장면에서 캡션만 뺀 것과 같은 방식이다. 흐름(타수 입력 → 퍼팅 전환 → 퍼팅 입력)이 이 페이지가 보여 줄 것과 똑같다.

- 새 장면 `golfOnboardingMode` (1200×1500, 10초 — 검색 장면과 같은 주기)
- **모드 버튼을 누르는 순간이 눈에 띄어야 한다.** 검색 장면의 탭 표시가 4:5 크기에서도 버튼 위에 분명히 보이는지 확인한다.
  안 보이면 버튼 쪽 탭 표시만 키운다
- **한 벌로 간다.** 카운터 화면 글자(`Hole` · `Par`)는 앱에서도 영어 고정이라 ko/en 이 같다
- 정지 이미지 `OnboardingMode` — 퍼팅 모드로 바뀐 직후(주황 버튼 + 링이 보이는) 프레임

### 2 — 크라운 → 스코어카드 영상

- **입력: 사용자가 스코어카드 워치 스크린샷을 준다.** `golf-watch.png` 와 같은 라운드에서 찍은 것이면 숫자가 이어진다.
  9홀 묶음 하나면 충분하다 (영상은 카운터 → 첫 스코어카드 한 번 내려가기)
- 장면 `golfOnboardingCrown` (1200×1500). 카운터 화면이 위로 밀려나고 스코어카드가 올라오는 세로 페이지 전환 + 크라운 회전 표시
- 크라운 표시는 Ralli 크라운 영상과 같은 언어(크라운 옆 회전 화살표)로. 세부 모양은 시안에서 정한다
- **ko/en 두 벌 여부는 받은 스크린샷의 글자로 정한다.** 스코어카드 헤더에 한국어가 있으면 두 벌
- 정지 이미지 `OnboardingCrown` — 스코어카드가 다 올라온 프레임

### 3 — 컴플리케이션

- **입력: 사용자가 GolfCounter 컴플리케이션이 올라간 문자판 스크린샷을 준다**
- 같은 워치 렌더링에 끼운 정지 이미지 `OnboardingComplication`. Ralli 처럼 링은 이미지에 굽지 않고 `OnboardingComplicationRing` 이 코드로 그린다
- 언어: 문자판에 다른 컴플리케이션 글자가 섞이면 Ralli 처럼 한 장으로 감수할지 판단한다

### 4 — 건강 앱

- **입력: 사용자가 실기기 피트니스 앱의 GolfCounter 라운드 워크아웃 상세 스크린샷을 준다** — ko/en 두 벌
  (Ralli 와 같은 주의: 시스템 언어만 English 로, 지역은 대한민국 유지)
- 폰 스크린샷이라 목업 없이 그대로 `OnboardingHealth` (로컬라이즈 이미지)

### 사용자에게 받을 것

| 페이지 | 스크린샷 | 언어 |
|---|---|---|
| 2 | 워치 스코어카드 (9홀 하나) | 글자에 따라 1~2벌 |
| 3 | 워치 문자판 + GolfCounter 컴플리케이션 | 1벌 |
| 4 | 폰 피트니스 앱 골프 워크아웃 상세 | ko · en |

1페이지는 이미 있는 입력(`golf-watch.png` · `golf-swing-icon.png`)으로 만든다.
`inputs/` · `out/` 은 git 이 무시한다 — 앱에 넣는 mp4 · PNG 만 저장소에 들어간다.

## 출시

- **2.1.2 에 싣는다 — 사용자 결정 (10-26).** 2.1.2 준비 커밋(`fa4b474` 버전 · `a65c2c5` 빌드 번호)은 이미 main 에 있고
  App Store 제출 전이다. 버전 번호는 그대로 두고 온보딩을 더한다
- **4장이 다 찬 상태로만 출시한다.** 온보딩은 사람마다 한 번만 뜨고(기존 사용자 포함) 빈 페이지를 나중에 채우려면
  `version` 을 올려 모두에게 다시 띄워야 하기 때문이다. 받을 스크린샷이 늦으면 출시가 그만큼 밀린다
- 작업 순서는 플랜이 정한다 — 1페이지 영상과 화면 틀은 지금 있는 재료로 먼저 만들 수 있다
- 2.1.2 출시 노트(`Apps/GolfCounter/APPSTORE.md`)에 온보딩 한 줄 — 출시 커밋 때 쓴다

## 하지 않는 것

- 공유 페이지, 좌우 스와이프 페이지
- 워치 온보딩
- 빈 기록 화면(`EmptyRounds`) 문구 변경 — 1페이지 문구로 푼다
- HealthKit 권한 선요청 — 지금처럼 첫 라운드 시작 때
- "사용법 다시 보기" 진입점 — 설정 화면이 생길 때 같은 뷰를 재사용한다
- YJKit 공용화 (위 "코드 배치")

## 빌더에게 맡기는 것

- 시안 세부 — 탭·크라운 표시 모양, 영상 타이밍, 정지 이미지로 쓸 프레임
- `OnboardingComplicationRing` 의 위치·크기 (받은 문자판 이미지 기준)
- 문구 최종본은 초안을 사용자에게 보여 확정한다
