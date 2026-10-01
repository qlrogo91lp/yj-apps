# TennisCounter (Ralli)

테니스 경기 점수를 기록하고, Apple Watch와 실시간으로 동기화하며, HealthKit 워크아웃 지표(칼로리·심박수·경과시간)를 함께 추적하는 iOS + watchOS 앱입니다.

- 경기 진행: 모드 선택 → 점수 입력 → 결과 저장 (iOS·Watch 대칭 구조)
- 폰 ↔ 워치 실시간 점수·워크아웃 동기화 (WatchConnectivity)
- HealthKit 연동 워크아웃 (칼로리, BPM, 경과시간), 잠금화면 Live Activity, 워치 컴플리케이션
- 경기 기록 히스토리 + 캘린더, SwiftData 저장

## 프로젝트 구조 & 아키텍처

타겟(iOSApp / WatchApp / ComplicationApp / TennisLiveActivity)별 폴더 구조, 계층별 컴포넌트 배치 규칙, 데이터 모델, 테스트 컨벤션 등 전체 아키텍처는 **[CLAUDE.md](CLAUDE.md)**에 정리되어 있습니다. 코드가 바뀔 때마다 그 문서를 기준으로 갱신하므로, 여기서는 중복해서 적지 않습니다.

## 개발 환경

- **언어**: Swift 6 (language mode v5)
- **UI 프레임워크**: SwiftUI
- **빌드 시스템**: Xcode (`YJApps.xcworkspace`, `PBXFileSystemSynchronizedRootGroup`)
- **패턴**: 기능(Feature) 단위 폴더 구조 + MVVM
- **린트/포맷**: SwiftLint + SwiftFormat

### 빌드 & 테스트

저장소 루트에서 실행합니다. 시뮬레이터는 이름이 중복될 수 있으므로 공용 스크립트가 선택한 UDID를 사용합니다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# iOS 앱
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" \
  -destination "id=$IOS" build

# Watch 앱
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" \
  -destination "id=$WATCH" build

# iOS 테스트
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" \
  -destination "id=$IOS" test

# Watch 테스트 전용 실행
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" \
  -destination "id=$WATCH" -only-testing:RalliWatchTests test
```

전체 빌드/테스트 명령어는 [CLAUDE.md의 Build Commands](CLAUDE.md#build-commands)를 참고하세요.

### Makefile 명령어

이 명령도 저장소 루트에서 실행합니다.

```bash
make lint      # SwiftLint 실행
make format    # SwiftFormat 검사 (--lint)
make fix       # SwiftFormat 자동 수정 + SwiftLint 자동 수정
```
