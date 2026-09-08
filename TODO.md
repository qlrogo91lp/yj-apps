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
트랙 A (iOS)     5 → 2 → 1 → 6 뼈대 ─┐
트랙 B (워치)     3 → 4 ─────────────┤→ 6 스크린샷 → 7
트랙 C (YJKit)   MonitoringCore ─────┘
```

- **A ↔ B ↔ C 는 겹치는 파일이 하나도 없다.** 셋을 동시에 굴려도 된다
- **트랙 내부는 순차다** — A 는 `MatchDetailSheet`·`iOSApp.swift`·Localizable 을, B 는 `ScoreViewModel` 을 공유한다
- **#7 은 맨 마지막에 단독으로.** iOS·워치 양쪽 `WorkoutSessionViewModel` + `iOSApp.swift` + pbxproj 를 다 건드려 #1·#2·#3·#6 과 전부 겹친다
- **#6 Task 4(스크린샷)가 두 트랙의 합류점.** 뼈대(Task 1~3)는 트랙 A 안에서 먼저 끝난다
- #8 은 별도 (브레인스토밍 전)

같은 파일을 건드리는 항목들 — `project.pbxproj`(1·5·7) / `TennisCounter-Info.plist`(1·2) /
`iOSApp.swift`(2·6·7) / `MatchDetailSheet.swift`(1·2) / iOS `WorkoutSessionViewModel`(1·7) /
Localizable(2·5·6) / 워치 `WorkoutSessionViewModel`(3·7)

| # | 항목 | 트랙 | 상태 | 문서 |
|---|---|---|---|---|
| 5 | String Catalog(xcstrings) 전환 | A | 플랜 완료 · 구현 대기 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-string-catalog-migration.md) |
| 2 | iOS 통계 UI 리디자인 | A | 스펙·플랜 완료 · 구현 대기 (선행: #5) | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-08-25-summary-history-redesign-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-summary-history-redesign.md) · [Notion](https://app.notion.com/p/3bacd15e48f180b3a810e95f63854aa6) |
| 1 | WorkoutShareUI 붙이기 (인스타 스토리 공유) | A | 플랜 완료 · 구현 대기 (선행: #2) | [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-workout-share-button.md) · [Kit 사용법](Packages/YJKit/README.md#workoutshareui-사용법) |
| 3 | 햅틱 (워치 전용) | B | 플랜 완료 · 구현 대기 | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-match-haptics.md) — 설정 연동은 #8 때 `MatchHaptics.play` 첫 줄에서 |
| 4 | 크라운 점수 입력 (워치, 위=나 아래=상대) | B | 플랜 완료 · 구현 대기 (선행: #3) | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-crown-scoring.md) — 온보딩(#6) 항목 하나 파생 |
| 6 | 온보딩 4페이지 (스크린샷 3 + 목록 1, iOS 만) | A → 합류 | 스펙·플랜 완료 · 구현 대기 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-onboarding.md) — 뼈대(Task 1~3)는 트랙 A 안에서, 스크린샷(Task 4)은 #1·#4 뒤 |
| 7 | Firebase Crashlytics (iOS + 워치, 익스텐션 제외) | 단독 (맨 뒤) | 스펙·플랜 완료 · 구현 대기 | [스펙](Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md) → [YJKit 플랜](Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md) (트랙 C, 지금 병렬 가능) → [Ralli 플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) |
| 8 | 설정 페이지 + 다른 앱 노출 | — | **논의 필요 — 아직 브레인스토밍 전** | 아래 "남은 논의" 참고 |

### 집 맥북에서 할 것

- [x] 통계 리디자인 작업물 찾기 — `feature/tennis-counter` 워크트리의 커밋 66a54d8 (스펙 문서 1개). 규약 경로로 이관 완료
- [x] #2 구현 플랜 작성

**트랙 A (iOS)** — 순서대로

- [ ] 5번 플랜 실행 (전부 Xcode UI + 검증)
- [ ] 2번 플랜 실행 (Task 8 Step 4 는 시뮬레이터 확인)
- [ ] 1번 플랜 실행 (Task 1 은 Xcode UI) — 선행: Meta 개발자 대시보드에서 Facebook App ID 발급 → `MatchShareButton.instagramAppID`
- [ ] 6번 뼈대 (Task 1~3)

**트랙 B (워치)** — A 와 동시 진행 가능

- [ ] 3번 플랜 실행 → 실기기에서 패턴 확인 (Task 4)
- [ ] 4번 플랜 실행 → 실기기에서 스침·포커스·손목 내림 확인 (Task 2)

**트랙 C (YJKit)** — A·B 와 무관, 지금 시작 가능

- [ ] Firebase 콘솔에 프로젝트 "Ralli" + Apple 앱 2개(iOS·워치 번들 ID) 만들고 `GoogleService-Info.plist` 2개 받기
- [ ] YJKit `MonitoringCore` 플랜 (Task 0 스파이크 → CI 통과 → PR 머지)

**합류 후**

- [ ] 6번 스크린샷 3장 × ko/en (Task 4) — #1·#4 가 끝나야 찍을 수 있다
- [ ] 7번 Ralli 연동 플랜 — 단독으로. PR 은 Kit / Ralli 따로

**아무 때나**

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

## HaruchiFit — 첫 출시 전 (Phase 1 진행 중)

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
| W2 종료 후 요약 (저장 / 버리기) | [PR #12](https://github.com/qlrogo91lp/yj-apps/pull/12) 머지 · **실기기 검증만 남음** | [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-07-haruchi-fit-w2-summary.md) |

### 예정사항 (남은 14개)

| Phase | # | 항목 | 상태 | 문서 |
|---|---|---|---|---|
| 1 워치 | W0 | 홈 시작 유형 토글 (근력 / 유산소) | **다음** · 플랜 완료 · 구현 대기 | [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-08-haruchi-fit-w0-start-kind.md) |
| 1 워치 | WC | 컴플리케이션 — 세션 상태만 | 예정 (선행: W0) · **착수 전 Xcode 에서 컴플리케이션 타깃에 `Shared` 추가** | 로드맵 Phase 1 ② |
| 2 데이터 | 3 | 잔디 집계 (일별 집계 캐시) | 예정 | 로드맵 Phase 2 · 스펙 5절 |
| 2 데이터 | 4 | HealthKit import (증분) | 예정 · **근력/유산소 매핑 표 확정이 핵심** | 로드맵 Phase 2 · 스펙 4.1·4.2 |
| 3 iOS | 5 | 탭 셸 + 디자인 토큰 | 예정 | 로드맵 Phase 3 · 스펙 3절·7절 |
| 3 iOS | 6 | 03b 기록 목록 | 예정 (선행: 5) | 로드맵 Phase 3 · 스펙 03b절 |
| 3 iOS | 7 | 04 기록 상세 (부위 태깅 · 메모) | 예정 (선행: 6) | 로드맵 Phase 3 · 스펙 04절 |
| 3 iOS | 8 | 06 공유 (`WorkoutShareUI` 그대로) | 예정 (선행: 7) | 로드맵 Phase 3 · 스펙 06절 |
| 4 잔디 | 9 | 02 홈 대시보드 | 예정 (선행: 3·5) | 로드맵 Phase 4 · 스펙 02절 |
| 4 잔디 | 10 | 03a 기록 달력 | 예정 (선행: 3·5) | 로드맵 Phase 4 · 스펙 03a절 |
| 4 잔디 | 11 | 05 통계 | 예정 (선행: 3·5) | 로드맵 Phase 4 · 스펙 05절 |
| 5 주변부 | 12 | 07 설정 | 예정 (선행: Phase 2) | 로드맵 Phase 5 · 스펙 07절 |
| 5 주변부 | 13 | 08 수동 기록 | 예정 | 로드맵 Phase 5 · 스펙 08절·4.3 |
| 5 주변부 | 14 | 01 온보딩 (HealthKit 권한) | 예정 | 로드맵 Phase 5 · 스펙 01절 |
| 언제든 | — | CloudKit 엔타이틀먼트 | 예정 · **프로비저닝 작업(사용자)** · 로컬 폴백 있어 급하지 않음 | 로드맵 "언제든" |

**Phase 1 이 끝나면 폰을 한 번도 안 열어도 흐름 A(해피패스)가 완결된다.**
Phase 2(잔디 집계 · HealthKit import) 는 화면이 없어 **눈으로 확인할 수단**을 착수 시점에 정한다.

> 플랜 문서는 **착수 직전에 하나씩** 쓴다 (로드맵 "작업 중 지킬 것"). 위 표의 "예정" 은
> 플랜이 아직 없다는 뜻이지 설계가 비어 있다는 뜻이 아니다 — 스펙은 14개 화면 전부 확정돼 있다.

### 집 맥북에서 할 것

- [x] W2 구현 — ViewModel 테스트 7개 통과. `BUNDLE_LOADER` 누락도 함께 고침. PR #12 머지
- [ ] **W2 실기기 검증 4항목** — 햅틱 5종, **버리기 후 건강 앱에서도 사라지는지** (플랜 "실기기" 절)
- [ ] W0 플랜 실행 — Task 1 은 TDD, Task 2 는 뷰라 실기기 확인
- [ ] WC 착수 전 — Xcode 에서 `HaruchiComplicationExtension` 타깃에 `Shared` 폴더 추가
      (지금은 워치 앱·iOS 앱에만 들어 있어 스냅샷 스토어를 `Shared/` 에 두면 컴파일이 안 된다)

> **아직 실기기에서 한 번도 안 돈 경로가 있다** — `HKHealthStore.delete`. 시뮬레이터에서는 실행되지
> 않고 테스트는 "지워달라고 요청했다"까지만 보장한다. 워치에서 거부되면 W2 플랜 1절 B안
> (`WorkoutCore` 에 보류 API)으로 가야 하고, 3개 앱 공유 패키지라 **그때 다시 승인받는다.**

## GolfCounter

아직 없음.

## 규약 참고

- [루트 CLAUDE.md](CLAUDE.md) · [TennisCounter CLAUDE.md](Apps/TennisCounter/CLAUDE.md) · [YJKit README](Packages/YJKit/README.md)
- [Xcode 타깃 규약](docs/specs/2026/2026-09-03-xcode-target-conventions.md) — `INFOPLIST_KEY_*` 배열 불가, HealthKit 권한 문구, `ENABLE_USER_SCRIPT_SANDBOXING`
