# TennisCounter

테니스 점수를 간편하게 기록할 수 있는 iOS + watchOS 앱입니다.

## 프로젝트 구조

```
tennis-counter/
├── Shared/                         # 공유 모듈
│   └── Models/
│       └── Score.swift             # 점수 데이터 모델 (ObservableObject)
│
├── iOSApp/                         # iOS 앱
│   ├── iOSApp.swift                # 앱 엔트리포인트 (@main)
│   ├── Views/
│   │   ├── ContentView.swift       # 메인 화면 (게임 스코어 + 포인트 카운터)
│   │   └── CounterButtonView.swift # +/- 버튼 및 포인트 표시 컴포넌트
│   ├── Assets.xcassets/            # 이미지/색상 리소스
│   └── Preview Content/            # SwiftUI 프리뷰 리소스
│
├── WatchApp/                       # watchOS 앱
│   ├── WatchApp.swift              # 앱 엔트리포인트 (@main)
│   ├── Views/
│   │   ├── ContentView.swift       # 메인 화면 (iOS와 동일한 구조, 워치 사이즈 최적화)
│   │   └── CounterButtonView.swift # +/- 버튼 컴포넌트 (워치 사이즈 최적화)
│   ├── Assets.xcassets/            # 이미지/색상 리소스
│   └── Preview Content/            # SwiftUI 프리뷰 리소스
│
├── ComplicationApp/                # watchOS 컴플리케이션 (WidgetKit)
│   ├── ComplicationAppBundle.swift # 위젯 번들 엔트리포인트 (@main)
│   ├── ComplicationApp.swift       # 컴플리케이션 위젯 (Circular, Corner, Rectangular)
│   ├── ComplicationAppControl.swift# ControlWidget (타이머 토글)
│   ├── Assets.xcassets/            # 컴플리케이션 아이콘 리소스
│   └── Info.plist
│
├── TennisCounter.xcodeproj/        # Xcode 프로젝트 설정
├── .swiftlint.yml                  # SwiftLint 설정
├── .swiftformat                    # SwiftFormat 설정
├── .gitignore
└── Makefile                        # lint / format / fix 명령어
```

## 아키텍처

### 데이터 모델

`Score` (ObservableObject) — 한 게임 내의 포인트 상태를 관리합니다.

| 프로퍼티 | 타입 | 설명 |
|---------|------|------|
| `myScore` | `Int` | 내 현재 포인트 (0, 15, 30, 40, 50) |
| `yourScore` | `Int` | 상대 현재 포인트 |
| `myIndex` | `Int` | 포인트 배열 인덱스 (0~4) |
| `yourIndex` | `Int` | 포인트 배열 인덱스 (0~4) |

포인트 배열: `[0, 15, 30, 40, 50]` — 50은 게임 승리를 의미합니다.

### 화면 구성

**ContentView** — 메인 화면
- 상단: 게임 스코어 (`myGameScore : yourGameScore`) + Reset 버튼
- 중앙: 좌/우 `CounterButtonView`로 각 선수의 포인트를 +/- 조작
- 하단: Confirm 버튼 — 한쪽이 50(Win)에 도달하면 게임 스코어를 +1하고 포인트를 초기화

**CounterButtonView** — 포인트 조작 컴포넌트
- `flag`로 선수 구분 (0: 나, 1: 상대)
- `+` / `-` 원형 버튼으로 포인트를 단계별로 증감
- 50 도달 시 "Win" 텍스트 표시

### 플랫폼별 차이

| 항목 | iOS | watchOS |
|------|-----|---------|
| 버튼 크기 | 70x70 | 35x35 |
| 폰트 크기 | 40~50pt | 20~30pt |
| 배경 | 검정 (전체화면) | 시스템 기본 |
| 텍스트 스케일링 | 없음 | `minimumScaleFactor(0.2)` |

### 컴플리케이션

watchOS 워치페이스에 앱 바로가기를 제공합니다.

- **지원 패밀리**: `accessoryCircular`, `accessoryCorner`, `accessoryRectangular`
- **ControlWidget**: 타이머 토글 컨트롤 (템플릿 상태)

## 개발 환경

- **언어**: Swift 6.0
- **UI 프레임워크**: SwiftUI
- **빌드 시스템**: Xcode (xcodeproj)
- **린트/포맷**: SwiftLint + SwiftFormat

### Makefile 명령어

```bash
make lint      # SwiftLint 실행
make format    # SwiftFormat 검사 (--lint)
make fix       # SwiftFormat 자동 수정 + SwiftLint 자동 수정
```
