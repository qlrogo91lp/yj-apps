# TODO

오랜만에 돌아왔을 때 여기부터 읽는다. 내용은 담지 않고 **어디에 문서가 있고 어디까지 됐는지**만 적는다.

- 항목이 끝나면 그 행에 `~~취소선~~` + 상태를 `완료 (커밋)` 으로 — **완료 커밋과 같은 커밋에서**
- 출시 커밋(`📝 x.y.z+n 버전 배포`)에서 취소선 행을 비운다
- 남은 항목이 없으면 `현재 대기 중인 작업 없음` 한 줄. 파일은 지우지 않는다

`feat/ralli` 은 PR #11 로 머지되어 더 쓰지 않는다. 새 작업은 항목별 브랜치를 판다.
트랙 A·B 를 동시에 굴리려면 워크트리 2개가 필요하다 — 순차로 가면 메인 체크아웃 하나로 충분하다.

## Ralli — 다음 출시 (현재 1.1.7 (26))

2026-09-07 상태 점검 기준. 파일 충돌을 실제로 따져 **2 트랙 병렬**로 재편했다.

```
트랙 A (iOS)     5̶ → 2̶ → 1 → 6 뼈대 ─┐   ← 5·2 완료, 다음은 1
트랙 B (워치)     3 → 4 ─────────────┤→ 6 스크린샷 → 7
트랙 C (YJKit)   MonitoringCore ─────┘
```

- **A ↔ B ↔ C 는 겹치는 파일이 하나도 없다.** 셋을 동시에 굴려도 된다
- **트랙 내부는 순차다** — A 는 `MatchDetailSheet`·`iOSApp.swift`·Localizable 을, B 는 `ScoreViewModel` 을 공유한다
- **#7 은 맨 마지막에 단독으로.** iOS·워치 양쪽 `WorkoutSessionViewModel` + `iOSApp.swift` + pbxproj 를 다 건드려 #1·#2·#3·#6 과 전부 겹친다
- **#6 Task 4(스크린샷)가 두 트랙의 합류점.** 뼈대(Task 1~3)는 트랙 A 안에서 먼저 끝난다
- #8 은 별도 (브레인스토밍 전)

같은 파일을 건드리는 항목들 (끝난 5·2 는 뺐다) — `project.pbxproj`(1·7) /
`TennisCounter-Info.plist`(1) / `iOSApp.swift`(6·7) / iOS `WorkoutSessionViewModel`(1·7) /
Localizable(6) / 워치 `WorkoutSessionViewModel`(3·7)

| # | 항목 | 트랙 | 상태 | 문서 |
|---|---|---|---|---|
| ~~5~~ | ~~String Catalog(xcstrings) 전환~~ | A | **완료** (PR #15) · 실기기 확인만 남음 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-string-catalog-migration.md) — 하드코딩 정리까지 범위가 늘었다 (§추출 문제) |
| ~~2~~ | ~~iOS 통계 UI 리디자인~~ | A | **완료** (PR #16) · 실기기 확인만 남음 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-08-25-summary-history-redesign-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-summary-history-redesign.md) · [Notion](https://app.notion.com/p/3bacd15e48f180b3a810e95f63854aa6) |
| 1 | WorkoutShareUI 붙이기 (인스타 스토리 공유) | A | 플랜 완료 · **Facebook App ID 발급이 선행 (사용자)** | [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-workout-share-button.md) · [Kit 사용법](Packages/YJKit/README.md#workoutshareui-사용법) |
| 3 | 햅틱 (워치 전용) | B | **구현 완료** (PR #18) · 실기기 패턴 확인만 남음 | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-match-haptics.md) — 설정 연동은 #8 때 `MatchHaptics.play` 첫 줄에서 |
| 4 | 크라운 점수 입력 (워치, 위=나 아래=상대) | B | 플랜 완료 · 구현 대기 (선행: #3) | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-crown-scoring.md) — 온보딩(#6) 항목 하나 파생 |
| 6 | 온보딩 4페이지 (스크린샷 3 + 목록 1, iOS 만) | A → 합류 | **뼈대 완료** (PR #17) · 스크린샷(Task 4)만 남음 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-onboarding.md) — 뼈대(Task 1~3)는 트랙 A 안에서, 스크린샷(Task 4)은 #1·#4 뒤 |
| 7 | Firebase Crashlytics (iOS + 워치, 익스텐션 제외) | 단독 (맨 뒤) | 스펙·플랜 완료 · 구현 대기 | [스펙](Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md) → [YJKit 플랜](Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md) (트랙 C, 지금 병렬 가능) → [Ralli 플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) |
| 8 | 설정 페이지 + 다른 앱 노출 | — | **논의 필요 — 아직 브레인스토밍 전** | 아래 "남은 논의" 참고 |

### 집 맥북에서 할 것

- [x] 통계 리디자인 작업물 찾기 — `feature/tennis-counter` 워크트리의 커밋 66a54d8 (스펙 문서 1개). 규약 경로로 이관 완료
- [x] #2 구현 플랜 작성

**트랙 A (iOS)** — 순서대로

- [x] 5번 플랜 실행 — 전환 + 하드코딩 정리. iOS 76키(신규 5) · 워치 27키. PR #15
- [x] 2번 플랜 실행 — Task 8개, 테스트 154개 통과. 삭제가 저장소에 반영되지 않는 버그를 잡았다. PR #16
- [ ] 1번 플랜 실행 (Task 1 은 Xcode UI) — **지금 다음 차례.** 선행: Meta 개발자 대시보드에서 Facebook App ID 발급 → `MatchShareButton.instagramAppID`
- [x] 6번 뼈대 (Task 1~3) — 게이트·페이지 4장·앱 진입 분기. 시뮬레이터에서 노출/미노출 확인. PR #17

**트랙 B (워치)** — A 와 동시 진행 가능

- [x] 3번 플랜 실행 — 이벤트 9종, 워치 테스트 81개 통과. PR #18
- [ ] **3번 실기기 패턴 확인** (Task 4) — 포인트·되돌리기·게임·세트·매치 종료가 촉각으로 구분되는지
- [ ] 4번 플랜 실행 → 실기기에서 스침·포커스·손목 내림 확인 (Task 2)

**트랙 C (YJKit)** — A·B 와 무관, 지금 시작 가능

- [ ] Firebase 콘솔에 프로젝트 "Ralli" + Apple 앱 2개(iOS·워치 번들 ID) 만들고 `GoogleService-Info.plist` 2개 받기
- [ ] YJKit `MonitoringCore` 플랜 (Task 0 스파이크 → CI 통과 → PR 머지)

**합류 후**

- [ ] 6번 스크린샷 3장 × ko/en (Task 4) — #1·#4 가 끝나야 찍을 수 있다
- [ ] 7번 Ralli 연동 플랜 — 단독으로. PR 은 Kit / Ralli 따로

**아무 때나**

- [ ] **#5 실기기 확인 — 워치만 남음.** 조기 종료 다이얼로그가 **"경기 중단"**(워치용 짧은 표현)
      인지, HealthKit 권한 문구가 한국어인지. iOS 쪽은 #2 가 그 화면을 다시 만들어 아래 항목이 흡수했다
- [ ] **Xcode.app 에서 한 번 빌드** — `xcodebuild` 는 카탈로그를 갱신하지 않는다. Xcode 가
      추출을 다시 돌렸을 때 정리한 항목이 되살아나지 않는지 `git status` 로 확인
- [ ] **#2 실기기 확인** (한국어 기기) — 요약(3칸·전적 줄·추이 차트·최근 세션),
      기록 목록의 세션 묶음과 스와이프 삭제, 캘린더 다중 점·날짜 선택,
      기록 상세 스코어보드와 `경기 방식`·`시간` 라벨, 앱 전체가 다크로 고정되는지.
      **삭제한 경기가 앱을 다시 켜도 안 돌아오는지** — 이번에 고친 버그다
- [ ] Xcode Organizer › Crashes 에서 Ralli 1.1.7 한 번 열어보기 (분석 공유 켠 사용자 표본만 보임)
- [x] `~/orca/workspaces/yj-apps/` 워크트리 3개 정리 — 워크트리·브랜치 모두 제거 완료

### 남은 논의 — #8 설정 페이지 (2026-09-07 시점)

아직 아이디어 단계. 다음 세션에서 브레인스토밍부터 시작한다. 지금까지 다른 항목에서 **설정 페이지로 미뤄 둔 것들**:

- 햅틱 on/off — 진입점 `MatchHaptics.play(_:)` 첫 줄. 전체 하나 또는 3그룹(점수 / 저장 알림 / 일시정지 알림). 값을 워치 로컬에 둘지 iOS 에서 `applicationContext` 로 동기화할지 미정
- 크래시 수집 on/off — `Crashlytics.setCrashlyticsCollectionEnabled(false)`. Kit 에 래퍼 추가 필요
- "사용법 다시 보기" — `OnboardingView` 를 시트로 재사용, 플래그는 안 건드림
- 다른 앱(골프·하루치) 노출 — 어떤 형태로(App Store 링크 / 배너 / "yj 의 다른 앱" 섹션), 어느 위치에. 완전 미논의
- 열린 질문: iOS 설정 탭을 4번째 탭으로 둘지 요약 탭 우상단 기어로 둘지 / 워치에도 설정 화면을 둘지 / 모드 옵션(No-Ad 등) 설명을 여기 둘지 모드 화면 ⓘ 로 둘지

## YJKit

| 항목 | 상태 | 문서 |
|---|---|---|
| `MonitoringCore` (CrashReporting 프로토콜 + Crashlytics 구현) | 스펙·플랜 완료 · 구현 대기 | 위 Ralli #7 과 같은 문서. 골프·하루치 연동은 별도 (Firebase 프로젝트 앱마다 새로) |

## HaruchiFit — 첫 출시 전 (Phase 1 완료 · Phase 2 대기)

순서와 설계 근거의 단일 출처는 [로드맵](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)이다.
선행 문서 — [제품 스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) · [아키텍처](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md).
아래 표는 **로드맵의 상태를 비추는 것**이고, 항목별 상세 근거·의존 관계는 로드맵이 갖는다.

### 진행사항 (완료)

| 항목 | 결과 | 문서 |
|---|---|---|
| 타깃 3개 생성 · CI 등록 | [PR #6](https://github.com/qlrogo91lp/yj-apps/pull/6) | [플랜](Apps/HaruchiFit/docs/plans/shared/2026/2026-09-03-haruchi-fit-target-scaffold.md) |
| `HKWorkoutActivity` 실기기 검증 | 이종 전환 불가 확정 → 폴백 (`b51f1b6`) | — |
| 스파이크 코드 제거 | [PR #7](https://github.com/qlrogo91lp/yj-apps/pull/7) | — |
| W1 모드 라벨 · 전환 행 (D-M1) | [PR #8](https://github.com/qlrogo91lp/yj-apps/pull/8) | — |
| 세그먼트 SwiftData 저장 | [PR #9](https://github.com/qlrogo91lp/yj-apps/pull/9) | — |
| W2 종료 후 요약 (저장 / 버리기) | [PR #12](https://github.com/qlrogo91lp/yj-apps/pull/12) 머지 · **실기기 검증 완료** | [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-07-haruchi-fit-w2-summary.md) |
| W0 홈 시작 유형 토글 (근력 / 유산소) | [PR #14](https://github.com/qlrogo91lp/yj-apps/pull/14) 머지 · 테스트 12개 통과 · **실기기 검증 완료** | [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-08-haruchi-fit-w0-start-kind.md) |
| WC 컴플리케이션 — 세션 상태만 | [PR #14](https://github.com/qlrogo91lp/yj-apps/pull/14) 머지 · 테스트 24개 통과 · **실기기 검증 완료** | [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-08-haruchi-fit-wc-complication.md) |

### 예정사항 (남은 12개)

| Phase | # | 항목 | 상태 | 문서 |
|---|---|---|---|---|
| 2 데이터 | 1 | 잔디 집계 (일별 집계 캐시) | **다음** · 스펙 완료 · **선행: 정지 제외** | [스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-09-grass-daily-aggregate.md) · 로드맵 Phase 2 |
| 2 데이터 | 2 | HealthKit import (증분) | 예정 · **근력/유산소 매핑 표 확정이 핵심** | 로드맵 Phase 2 · 스펙 4.1·4.2 |
| 3 iOS | 3 | 탭 셸 + 디자인 토큰 | 예정 | 로드맵 Phase 3 · 스펙 3절·7절 |
| 3 iOS | 4 | 03b 기록 목록 | 예정 (선행: 3) | 로드맵 Phase 3 · 스펙 03b절 |
| 3 iOS | 5 | 04 기록 상세 (부위 태깅 · 메모) | 예정 (선행: 4) | 로드맵 Phase 3 · 스펙 04절 |
| 3 iOS | 6 | 06 공유 (`WorkoutShareUI` 그대로) | 예정 (선행: 5) | 로드맵 Phase 3 · 스펙 06절 |
| 4 잔디 | 7 | 02 홈 대시보드 | 예정 (선행: 1·3) | 로드맵 Phase 4 · 스펙 02절 |
| 4 잔디 | 8 | 03a 기록 달력 | 예정 (선행: 1·3) | 로드맵 Phase 4 · 스펙 03a절 |
| 4 잔디 | 9 | 05 통계 | 예정 (선행: 1·3) | 로드맵 Phase 4 · 스펙 05절 |
| 5 주변부 | 10 | 07 설정 | 예정 (선행: Phase 2) | 로드맵 Phase 5 · 스펙 07절 |
| 5 주변부 | 11 | 08 수동 기록 | 예정 | 로드맵 Phase 5 · 스펙 08절·4.3 |
| 5 주변부 | 12 | 01 온보딩 (HealthKit 권한) | 예정 | 로드맵 Phase 5 · 스펙 01절 |
| 언제든 | — | CloudKit 엔타이틀먼트 | 예정 · **프로비저닝 작업(사용자)** · 로컬 폴백 있어 급하지 않음 | 로드맵 "언제든" |

**Phase 1 이 끝나 폰을 한 번도 안 열어도 흐름 A(해피패스)가 완결된다** — W2 · W0 · WC.
셋 다 실기기 검증까지 끝났다. Phase 2 착수 전에 **워치 시간에서 일시정지를 빼는 선행 작업**이 하나 끼었다 — 잔디 농도의 입력이라서다.
다음 Phase 2(잔디 집계 · HealthKit import) 는 화면이 없어 **눈으로 확인할 수단**을 착수 시점에 정한다.

> 플랜 문서는 **착수 직전에 하나씩** 쓴다 (로드맵 "작업 중 지킬 것"). 위 표의 "예정" 은
> 플랜이 아직 없다는 뜻이지 설계가 비어 있다는 뜻이 아니다 — 스펙은 14개 화면 전부 확정돼 있다.

### 집 맥북에서 할 것

- [x] W2 구현 — ViewModel 테스트 7개 통과. `BUNDLE_LOADER` 누락도 함께 고침. PR #12 머지
- [x] **W2 실기기 검증 4항목** — 햅틱 5종 확인. **버리기 후 건강 앱에서도 사라진다** —
      `HKHealthStore.delete` 가 실기기 워치에서 통과했다 (W2 플랜 1절 B안 불필요)
- [x] W0 플랜 실행 — 테스트 12개 통과. 시뮬레이터에서 토글 히트영역·좌우 여백 두 곳을 더 고쳤다
- [x] **W0 실기기 검증 5항목** — 토글 `.click` 햅틱, 재실행 시 유형 유지, W1 라벨, 요약 바 파랑, 건강 앱에 근력으로 기록 모두 확인
- [x] WC 구현 — `Shared` 가 아니라 새 `Common/` 폴더를 세 타깃에 붙였다 (`Shared` 는 `ConnectivityCore` 의존으로 불가)
- [x] **WC 실기기 검증 6항목** — 앱을 안 열어도 상태 전환, 경과시간, 일시정지 시 멈춤,
      종료 후 복귀, 탭하면 앱 열림, 재부팅 후 유지 모두 확인
      · 경과시간은 `.accessoryRectangular` 패밀리에서만 그린다 — 원형·코너는 아이콘만
- [x] **구간 시간이 "근력 0분" 으로 나온 문제** — 틱 카운터를 벽시계로 바꿨다 (PR #19).
      [작업 기록](Apps/HaruchiFit/docs/logs/2026/2026-09-09-segment-duration-tick-counter.md)
- [ ] **구간 시간 재검증** — 고친 뒤 실기기에서 40분쯤 돌려 종목별 분이 맞는지 (PR #19)
- [ ] **워치 시간에서 일시정지 제외** — 스펙·플랜 완료 · 구현 대기. 잔디 집계(#1)의 선행이다.
      [스펙](Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md) ·
      [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)
- [ ] **경과시간이 뒤처지는지** — 워크아웃 중 손목을 30초 내렸다 올렸을 때 시간이 건너뛰는지
      멈춰 있었는지. 3개 앱 공통 ([탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md))

## YJKit — 확인 필요

| 항목 | 상태 | 문서 |
|---|---|---|
| `WorkoutSessionService.elapsedSeconds` 가 벽시계가 아니라 1초 `Timer` 틱 카운터다 | **실기기 확인 대기 · 3개 앱에 걸림** | [탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md) |

하루치 구간 시간이 이것 때문에 실기기에서 몇 초로 잡혔다 (PR #19 로 하루치만 벽시계로 고침).
**Ralli 는 저장되는 값 자체가 틱 기반**이라 요약의 "운동시간" 과 세션 헤더가 실제보다 짧을 수
있다 — 1.1.7 에도 있는 문제라 **기존 기록만 봐도 판단된다.**

확인할 것 3가지와 고칠 때의 갈림길(일시정지를 어떻게 셀 것인가)은 위 탐색 문서에 정리했다.

**하루치는 앱 레이어에서 정지 제외로 간다** — HealthKit 이 세그먼트를 모르니 구간에서 정지를
빼는 일은 앱 몫이고, 그 시계를 두 개 둘 이유가 없다
([스펙](Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)).
**YJKit 통합과 Ralli 기존 기록 문제는 그대로 열려 있다** — 위 3가지 확인이 선행이다.

## GolfCounter

아직 없음.

## 규약 참고

- [루트 CLAUDE.md](CLAUDE.md) · [TennisCounter CLAUDE.md](Apps/TennisCounter/CLAUDE.md) · [YJKit README](Packages/YJKit/README.md)
- [Xcode 타깃 규약](docs/specs/2026/2026-09-03-xcode-target-conventions.md) — `INFOPLIST_KEY_*` 배열 불가, HealthKit 권한 문구, `ENABLE_USER_SCRIPT_SANDBOXING`
