# 하루치 핏 Phase 3 #3 — 탭 셸과 디자인 토큰 구현 플랜

작성일: 2026-09-23
상태: **구현 완료 — 사용자 검토·커밋 전**

## 목표와 범위

현재 `ContentView`의 임시 잔디 확인 화면을 **홈 / 기록 / 통계** 3탭 셸로 바꾸고,
[제품 스펙 3절·7절](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md)의
다크 전용 색을 iOS 앱 전체에서 쓸 수 있는 토큰으로 만든다. 기존 26주 잔디 그리드는 홈 탭에
그대로 옮긴다. HealthKit import 및 워치 저장 후 실기기에서 날짜·농도를 확인할 경로가
아직 필요하기 때문이다.

이번 작업은 [로드맵 Phase 3 #3](../../../specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)에
한정한다. 홈 대시보드(#7), 기록 목록(#4), 통계(#9), 설정(#10), 수동 추가(#11)는 각 후속
작업에서 채운다. 구현 전인 설정·추가 버튼을 작동하지 않는 상태로 미리 노출하지 않는다.

앱 아이콘은 현재 로드맵에 별도 일정이 없다. **2026-09-23 사용자 확인: 원본은 아직
전달되지 않았다.** 따라서 이번 플랜에서 아이콘은 제외한다. 원본을 받은 뒤 적용 범위와
시점을 정하고, 그전에는 아이콘을 제작하거나 에셋에 연결하지 않는다.

## 화면·상태 계약

- 탭 순서는 **홈 / 기록 / 통계**. 각 탭은 SF Symbol과 한글 라벨을 갖고, 선택 색은
  `accent`다. 탭 간 이동은 실제로 동작해야 한다.
- 각 탭이 자체 `NavigationStack`을 소유한다. 앞으로 기록 상세와 설정 화면을 붙여도
  탭별 내비게이션 상태가 독립적이다.
- 홈의 기존 `@Query` 기간 제한(26주), `GrassViewModel` 재집계, 날짜 탭 상세,
  `.refreshable { await sync.sync() }`를 유지한다. 임시 농도 색은 이번에 정의한 토큰을 쓴다.
  농도 컷과 데이터 규칙은 변경하지 않는다.
- 기록·통계는 제목과 짧은 빈 상태 문구만 보여준다. 임시 차트·가짜 데이터는 넣지 않는다.
- 앱 루트에 `.preferredColorScheme(.dark)`를 적용한다. 화면 배경은 `bg`, 카드가 필요한
  곳은 `surface`, 구분선과 텍스트는 해당 토큰을 쓴다. 시스템 탭 바는 `surface`와 `accent`로
  맞추되 전역 `UIAppearance` 변경은 쓰지 않는다.

### iOS 색 토큰

`iOSApp/HaruchiPalette.swift`에 `HaruchiPalette` 열거형의 `Color` 정적 상수로 둔다. 워치의
`BrandColor.swift`와 `Shared/`는 건드리지 않는다. 색은 스펙의 HEX를 정확히 따른다.

| 토큰 | HEX | 토큰 | HEX |
|---|---|---|---|
| `accent` | `#FF9500` | `cardio` | `#8CB4E8` |
| `hr` | `#FF453A` | `bg` | `#1C1C18` |
| `surface` | `#252521` | `surface2` | `#2C2C27` |
| `surface3` | `#35352E` | `line` | `#33332C` |
| `text` | `#F2F0EA` | `dim` | `#8E8C82` |
| `faint` | `#5C5B53` | `cell` | `#28281F` |

잔디 0단계는 `cell`, 4단계는 `accent`다. 1~3단계는 두 색을 RGB 채널별로
25%·50%·75% 보간한 `#5E4317`·`#945F10`·`#C97A08`을 사용한다. 스펙은 중간 단계의
HEX를 지정하지 않았으므로 이 값을 이번 플랜의 표현 규칙으로 고정하고 시뮬레이터에서
육안 검증한다. 이 매핑은
표현 전용이며 `GrassIntensity`의 컷(30/60/90분)을 바꾸지 않는다.

## 파일별 작업

| 파일 | 변경 | 내용 |
|---|---|---|
| `Apps/HaruchiFit/iOSApp/ContentView.swift` | 수정 | 임시 그리드를 빼고 3탭 `TabView` 셸로 교체. 루트 프리뷰에는 기존 인메모리 모델 컨테이너와 `WorkoutSyncCoordinator`를 주입한다. |
| `Apps/HaruchiFit/iOSApp/Features/Home/HomeView.swift` | 생성 | 기존 `ContentView`의 기간 제한 쿼리, 잔디 그리드·날짜 상세, 동기화 당김, 모델 변화 재집계를 이관. `NavigationStack`을 소유하고 새 색 토큰을 사용한다. |
| `Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift` | 생성 | 기록 탭의 제목과 빈 상태. Phase 3 #4의 목록 화면이 이 파일을 채운다. |
| `Apps/HaruchiFit/iOSApp/Features/Statistics/StatisticsView.swift` | 생성 | 통계 탭의 제목과 빈 상태. Phase 4 #9가 이 파일을 채운다. |
| `Apps/HaruchiFit/iOSApp/HaruchiPalette.swift` | 생성 | 스펙 7절의 12개 iOS `Color` 토큰과 잔디 단계별 표시 색을 제공한다. |
| `Apps/HaruchiFit/iOSApp/Assets.xcassets/AccentColor.colorset/Contents.json` | 수정 | 시스템 accent asset을 `#FF9500`으로 지정해 탭·시스템 컨트롤의 기본 tint도 일치시킨다. |
| `Apps/HaruchiFit/iOSApp/iOSApp.swift` | 수정 | 앱 루트에 다크 모드를 지정한다. 기존 모델 컨테이너·연결·포그라운드 동기화 배선은 유지한다. |
| `Apps/HaruchiFit/CLAUDE.md` | 구현 후 수정 | iOS가 임시 단일 화면이라는 설명을 3탭 셸과 홈의 임시 잔디 그리드로 갱신한다. |
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 구현 후 수정 | Phase 3 #3 완료 상태와 PR 번호를 기록한다. |
| `TODO.md` | 구현 후 수정 | #3 상태·PR 링크를 기록하고 #4를 다음 코드 작업으로 표시한다. 남은 작업 수를 맞추고 실기기 확인 대기 항목은 유지한다. |

`GrassViewModel.swift`, `Shared/`, `WatchApp/`, `Packages/YJKit/`, `.xcodeproj`는 이
작업에서 수정할 이유가 없다. `iOSApp`은 파일 시스템 동기화 그룹이므로 새 Swift 파일의
프로젝트 파일 수동 등록도 필요 없다.

## 실행 순서

1. **승인 후** 형제 폴더 `../yj-apps-worktrees/haruchi-tab-shell`에
   `feat/haruchi-tab-shell` 브랜치의 작업 트리를 만들고 기준 `main` 상태를 확인한다.
2. 팔레트와 accent asset을 만들고, 색 값이 스펙의 HEX와 일치하는지 확인한다.
3. 기존 그리드를 `HomeView`로 옮긴 다음 `ContentView`를 3탭 셸로 바꾼다.
   기록·통계 빈 상태와 다크 모드를 연결한다.
4. iOS 시뮬레이터에서 탭 전환, 배경·탭 바 색, 빈 상태, 26주 그리드의 스크롤·날짜 탭,
   당겨서 동기화를 확인한다. 데이터가 없는 상태도 크래시 없이 보여야 한다.
5. `make lint`, `make format`, iOS 워크스페이스 빌드를 실행한다. 변경 파일 diff를 검토하고
   `git diff --check`를 통과시킨다.
6. 앱 작업 규약·로드맵·`TODO.md`를 갱신해 사용자 검토 후 커밋한다. 브랜치를 푸시해 PR을 열고 대상
   CI 통과를 확인한 뒤 일반 merge commit으로 합친다. `main` 동기화 후 작업 트리·브랜치와
   그 작업 트리의 고아 DerivedData를 정리한다.

## 검증 명령과 완료 기준

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
make lint
make format
git diff --check
```

하루치 iOS 테스트 타깃은 아직 없으므로 새 UI용 단위 테스트는 만들지 않는다. 시뮬레이터에서
탭 이동과 기존 잔디·동기화 경로를 직접 확인한다. 워치와 공유 모델의 동작은 변경하지
않으므로 워치 테스트는 이번 변경의 필수 게이트가 아니다. PR CI가 대상 빌드와 lint를
검증한다.

완료 시 홈·기록·통계 탭이 작동하고, 홈의 기존 실데이터 확인 경로가 유지되며,
다크 팔레트의 HEX가 스펙과 일치해야 한다. PR 머지까지 마친 뒤 #4 기록 목록에 착수한다.
