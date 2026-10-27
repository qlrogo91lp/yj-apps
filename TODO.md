# TODO

오랜만에 돌아왔을 때 여기부터 읽는다. 내용은 담지 않고 **어디에 문서가 있고 어디까지 됐는지**만 적는다.

- 항목이 끝나면 그 행에 `~~취소선~~` + 상태를 `완료 (커밋)` 으로 — **완료 커밋과 같은 커밋에서**
- 출시 커밋(`📝 x.y.z+n 버전 배포`)에서 취소선 행을 비운다
- 남은 항목이 없으면 `현재 대기 중인 작업 없음` 한 줄. 파일은 지우지 않는다

**2026-10-27 정리** — 세 앱 모두 10-26 에 심사를 넣었다. Ralli 1.2.0(1) · 골프 2.1.2 · 하루치 1.0.0(6) 재제출.
끝난 항목은 비웠다. 지난 상태는 git 이력이 갖는다.

## Ralli — 1.2.0 심사 중 (10-26 제출)

1.2.0 에 실린 것: Crashlytics(#7) · 무승부 종료(#17, PR #72) · 세션 상세 경기 카드(PR #73) · 온보딩 미디어(PR #67 · #68 · #71) ·
워치 기록 전송 유실 수정(PR #65) · 워크아웃 종료 순서(PR #70). 개인정보처리방침 Crashlytics 반영은 yjlogs PR #104 로 끝났다.

| # | 항목 | 상태 | 문서 |
|---|---|---|---|
| 8 | 설정 페이지 + 다른 앱 노출 | **논의 필요 — 아직 브레인스토밍 전** · 앱 안 개인정보처리방침 링크(iOS)도 여기서 넣는다 (아래 "모노레포 공통") | 아래 "남은 논의" 참고 |
| 11 | 클럽 대진표 · 실시간 중계 (Firebase) | **탐색 중** — 다음 출시 범위 아님 | [탐색 문서](Apps/TennisCounter/docs/ideas/club-live-scoring.md) — CourtMate 분석에서 출발. 백엔드·단위·기록자·게스트까지 결정, 안드로이드·매칭·ELO 는 열림 |
| 12 | 워치 크라운 포커스 복구 · 워크아웃 종료 시각 보존 | **코드 수정 완료** ([PR #32](https://github.com/qlrogo91lp/yj-apps/pull/32)) **· 실기기 확인 대기** | [작업 기록](Apps/TennisCounter/docs/logs/2026/2026-09-28-crown-focus-and-session-end-time.md) — 알림·저휘도 복귀 뒤 크라운과 종료 버튼 시각 전달 확인 필요 |
| 17 | 동점 경기 수동 무승부 종료 (iOS + 워치) | **머지 ([PR #72](https://github.com/qlrogo91lp/yj-apps/pull/72)) · 1.2.0 에 포함** · 작은 워치 실화면 배치 확인 대기 | [iOS 점수 로직](Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift) · [워치 점수 로직](Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift) |

### 열려 있는 확인

- [ ] **#5 실기기 확인 — 워치만 남음.** 조기 종료 다이얼로그가 **"경기 중단"**(워치용 짧은 표현)
      인지, HealthKit 권한 문구가 한국어인지
- [ ] **Xcode.app 에서 한 번 빌드** — `xcodebuild` 는 카탈로그를 갱신하지 않는다. Xcode 가
      추출을 다시 돌렸을 때 정리한 항목이 되살아나지 않는지 `git status` 로 확인
- [ ] **#2 실기기 확인** (한국어 기기) — 요약(3칸·전적 줄·추이 차트·최근 세션),
      기록 목록의 세션 묶음과 스와이프 삭제, 캘린더 다중 점·날짜 선택,
      기록 상세 스코어보드와 `경기 방식`·`시간` 라벨, 앱 전체가 다크로 고정되는지.
      **삭제한 경기가 앱을 다시 켜도 안 돌아오는지**
- [ ] **온보딩 미디어 실기기 확인** — 1페이지 영상 재생 · 스와이프 영상 · "동작 줄이기" 켰을 때 정지 이미지
- [ ] **1.2.0 출시 뒤 Crashlytics** — ③ Firebase dSYM 탭에 1.2.0 UUID "업로드됨" ④ Organizer › Crashes 한 번 열어보기
- [ ] **워치 저장 실패 non-fatal 콘솔 확인** — 워치에 "저장 실패" 는 떴는데(10-02) 며칠이 지나도 콘솔 `ralli-watch` 에 `Ralli.Save` code 3 이 안 올라왔다.
      다음은 `-FIRDebugEnabled` 로 업로드 로그를 본다. 절차·dSYM `62AD67DD` 누락 메모는 [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) Task 4
- [ ] **iOS 가 워치 저장 뒤에도 "경기 진행 중" 에 남는다** (10-02, 원인 미확인) — 워치는 "저장됨" 까지 갔다. 같은 경기 점수였는지,
      기록 탭에 저장됐는지부터 본다. 의심 경로: 경기 시작이 `applicationContext` 에 남아 콜드 런치 때 다시 읽힘 / `sendMessage` 실패 시 `errorHandler: nil` 이라 경기 종료가 유실.
      **10-26 재검토: PR #65 는 이 경로를 건드리지 않았다** — 폰 화면은 `receivedMatchEnd` 로만 결과로 넘어가고, 그 메시지는 여전히 `.reliable`.
      기록 손실은 없고 폰 화면만 남는다. 재현되면 폰이 저장 요청을 받을 때 진행 중 경기를 결과로 넘기는 쪽이 가장 작다
- [ ] **연속 경기 때 이전 경기의 저장 응답이 지금 경기 버튼을 "저장됨" 으로 바꿀 수 있다** (10-26, 알려진 문제 · 보류) —
      `MatchSaveResultMessage` 가 `sessionId`(운동)만 싣고 경기 ID 가 없다. 재시작 뒤에는 응답이 무시되고 기록도 결국 저장되므로,
      놓치는 건 폰 저장이 실제로 실패한 경우뿐이다. 고친다면 응답에 `matchId` 를 선택 필드로 더하고 워치가 지금 경기와 비교한다

### 남은 논의 — #8 설정 페이지 (2026-09-07 시점)

아직 아이디어 단계. 다음 세션에서 브레인스토밍부터 시작한다. 지금까지 다른 항목에서 **설정 페이지로 미뤄 둔 것들**:

- 햅틱 on/off — 진입점 `MatchHaptics.play(_:)` 첫 줄. 전체 하나 또는 3그룹(점수 / 저장 알림 / 일시정지 알림). 값을 워치 로컬에 둘지 iOS 에서 `applicationContext` 로 동기화할지 미정
- 크래시 수집 on/off — `Crashlytics.setCrashlyticsCollectionEnabled(false)`. Kit 에 래퍼 추가 필요
- "사용법 다시 보기" — `OnboardingView` 를 시트로 재사용, 플래그는 안 건드림
- 다른 앱(골프·하루치) 노출 — 어떤 형태로(App Store 링크 / 배너 / "yj 의 다른 앱" 섹션), 어느 위치에. 완전 미논의
- 열린 질문: iOS 설정 탭을 4번째 탭으로 둘지 요약 탭 우상단 기어로 둘지 / 워치에도 설정 화면을 둘지 / 모드 옵션(No-Ad 등) 설명을 여기 둘지 모드 화면 ⓘ 로 둘지

## HaruchiFit — 1.0.0 재제출 · 심사 중 (10-26, 빌드 6)

설계 근거는 [로드맵](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md) · [제품 스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) · [아키텍처](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md).

| 항목 | 상태 | 문서 |
|---|---|---|
| 워치 기록 전송 유실 수정 (세 앱, YJKit `.queued`) · 하루치 칼로리 활동 칼로리로 통일 — 원래 1.0.1 로 잡았던 것 | **1.0.0(6) 에 포함** — 빌드 6 은 [PR #63](https://github.com/qlrogo91lp/yj-apps/pull/63) · [#64](https://github.com/qlrogo91lp/yj-apps/pull/64) · [#65](https://github.com/qlrogo91lp/yj-apps/pull/65) 머지 뒤에 만들었다. 골프 2.1.2 · Ralli 1.2.0 에도 실렸다. 실기기 확인 대기 (아래) | [플랜](docs/plans/2026/2026-10-25-watch-record-delivery.md) |
| 07 설정 | **보류** — 만들 때 `정보` 그룹의 개인정보처리방침 링크(iOS)를 반드시 넣는다 | 로드맵 Phase 5 · 스펙 07절 |
| CloudKit 엔타이틀먼트 | **예정** — 프로비저닝 작업(사용자) · 로컬 폴백이 있다 | 로드맵 "언제든" |

### 워치 기록 전송 유실 수정 — 실기기 확인

**하루치** — 근력 · 유산소를 번갈아 넣은 운동을 끝내고 저장. 폰 기록에 구간이 나뉘어 있고 `kcal` 이 워치 요약 숫자와 같은지
- [ ] 폰 앱을 백그라운드로 둔 채
- [ ] 폰 앱을 완전히 종료한 채 → 운동 2개를 연달아 끝낸 뒤 폰 앱을 연다 (밀린 기록 2건이 다 들어오는지)

**골프**
- [ ] 폰 앱을 종료한 채 라운드를 끝내고 저장 → 폰 앱을 열면 라운드가 있다

**Ralli** — `CURRENT_PROJECT_VERSION = 1` 고정이라 App Store 설치본과 Xcode 설치본이 같은 번호로 보인다. Xcode 설치본인지 먼저 확인
- [ ] 운동 종료 시 폰 미러 화면이 닫히는 지연이 견딜 만한지 (플랜 D6)

### 열려 있는 것

- [ ] **피트니스 앱 운동 목록 아이콘이 자리 표시자** (10-07, 원인 미확인) — 하루치 운동 행이 앱 아이콘 대신 회색 동심원으로 뜬다
      (테니스 앱은 로고가 나온다). 앱 아이콘 연결은 Ralli 와 같다. 건강 앱 › 앱 목록의 아이콘 확인 · 앱 재설치 후 1~2분짜리 운동 재확인 ·
      두 앱의 설치 방식(TestFlight / Xcode) 비교 순으로 좁힌다
- [ ] **경과시간이 뒤처지는지** — 워크아웃 중 손목을 30초 내렸다 올렸을 때 시간이 건너뛰는지
      멈춰 있었는지. 3개 앱 공통 ([탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md))
- [ ] **잔디 농도 컷 조정** — 기록이 쌓인 뒤 농도가 실제 운동 시간과 맞는지 본다. 지금 컷은 30/60/90분 (D-M6)

## GolfCounter — 2.1.2 심사 중 (10-26 제출)

| 항목 | 상태 | 문서 |
|---|---|---|
| **iOS 온보딩 3장** (모드 전환 영상 · 크라운 스코어카드 영상 · 컴플리케이션) | **머지 ([PR #74](https://github.com/qlrogo91lp/yj-apps/pull/74)) · 2.1.2 에 포함** · 실기기 확인 대기 (2·3페이지 넘기기 · 영상 반복 · 백그라운드 복귀 재생 · 동작 줄이기 정지 이미지 · 링 위치) | [스펙](Apps/GolfCounter/docs/specs/ios/2026/2026-10-26-onboarding-design.md) · [플랜](Apps/GolfCounter/docs/plans/ios/2026/2026-10-26-onboarding.md) |
| **라운드 위치 지도** | **아이디어 (10-26) — 구현 미착수** · 워치에서 라운드 시작 위치를 1회 저장하고, 폰 상세 지도에서 기록 위치 핀과 주변 장소를 확인한다. 골프장명은 수동 입력 유지 | [기존 설계 §9](Apps/GolfCounter/docs/specs/shared/2026/2026-07-31-golfcounter-rebuild-design.md#9-mapkit-골프장-감지) — 자동 이름 감지에서 위치 지도 중심으로 방향 변경 예정 |

## YJKit

| 항목 | 상태 | 문서 |
|---|---|---|
| `MonitoringCore` (CrashReporting 프로토콜 + Crashlytics 구현) | **Ralli 만 연동** ([PR #35](https://github.com/qlrogo91lp/yj-apps/pull/35) · [PR #36](https://github.com/qlrogo91lp/yj-apps/pull/36)) — 골프·하루치 연동은 별도 (Firebase 프로젝트 앱마다 새로) | [스펙](Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md) · [YJKit 플랜](Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md) · [Ralli 플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) |
| **건강 앱에서 지운 것을 앱이 따라 지운다** (`HKDeletedObject`) | **미착수** — 브레인스토밍 전. 3개 앱이 같은 구조라 Kit 이 한 번 정한다 | 하루치 [import 스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-21-healthkit-workout-import.md) 4절에 정할 것이 적혀 있다. **Ralli #10 과 방향이 반대다** — 그쪽은 앱에서 지우면 건강 앱을 지운다 |
| **워크아웃 종료 순서** — `stopWorkout()` 이 `session.end()` 를 먼저 불러 마무리 중 앱이 멈춘다 (3개 앱 공통) | **머지 ([PR #70](https://github.com/qlrogo91lp/yj-apps/pull/70)) · 세 앱 이번 제출분에 모두 포함** — `stopActivity` → `.stopped` 대기 → 마무리 → `end()` 순서로. 실기기 확인: 경기 종료 직후 손목을 내리고 1~2분 뒤 건강 앱에 운동·종료 시각이 맞는지. 남은 것: 워크아웃 복구(`handleActiveWorkoutRecovery`) · `didFailWithError` · `startWorkout` 의 `catch {}` | [전송 유실 플랜](docs/plans/2026/2026-10-25-watch-record-delivery.md) "범위 밖" 절 |
| **리팩터링: 온보딩 틀 공통화** (가칭 `OnboardingUI`, iOS) | **대기 — 세 앱 심사 결과가 나온 뒤 새 버전으로 (10-26 결정)**. Ralli · 하루치 · 골프가 같은 틀을 앱마다 복사해 쓴다. 공통: `OnboardingGate`(세 앱 동일) · 페이지 넘기기 틀 · 4:5 그림 + 고정 높이 글 배치 · `LoopingVideo`(동작 줄이기 시 정지 이미지). 앱이 넘길 것: 배경·버튼 색, 건너뛰기 유무(하루치는 없음), 마지막 버튼 문구, 글 영역 높이(112/190) · 작은 글씨 줄, 그림. 영상·이미지는 앱 번들에 두고 경로만 넘긴다. 공용 버튼 문구는 패키지 ko/en (`WorkoutShareUI` 와 같은 방식) | 골프 [온보딩 스펙](Apps/GolfCounter/docs/specs/ios/2026/2026-10-26-onboarding-design.md) "코드 배치" · Ralli `Apps/TennisCounter/iOSApp/Features/Onboarding/` · 하루치 `Apps/HaruchiFit/iOSApp/Features/Onboarding/` |

## YJKit — 확인 필요

| 항목 | 상태 | 문서 |
|---|---|---|
| **운동 시작 위치 기록 (YJKit 공용 · 세 앱)** | **논의 정리 (10-26) · 구현 미착수** — 시작 위치를 1회 수집해 각 앱 상세 지도에 표시하고 피트니스 앱 연동도 검토. 첫 운동 시작 때 건강 권한에 `운동 경로`를 포함하고 위치 권한(`사용 중`)을 요청하는 방향. 위치 거부 시 장소 없이 운동 기록. 단일 좌표 `HKWorkoutRoute`의 피트니스 표시 확인 필요 | [Apple 답변 — 단일 위치 경로](https://developer.apple.com/forums/thread/773408) · 별도 스펙·플랜 미작성 |
| `WorkoutSessionService.elapsedSeconds` 가 벽시계가 아니라 1초 `Timer` 틱 카운터다 | **실기기 확인 대기 · 3개 앱에 걸림** | [탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md) |
| `WorkoutMetricsView` 의 `statusText` 제거 | **미착수 (10-12)** — 하루치만 쓰던 파라미터인데 워치 세션 화면이 왼쪽 상단 모드 아이콘(`feat/haruchi-watch-mode-figure`)으로 바뀌며 쓰는 앱이 없어졌다. 아이콘 방식이 확정되면 프로퍼티·init 인자·`if let` 블록·"상태 줄" 프리뷰를 같이 지운다 | `Packages/YJKit/Sources/WorkoutUI/Watch/WorkoutMetricsView.swift` |

하루치 구간 시간이 이것 때문에 실기기에서 몇 초로 잡혔다 (PR #19 로 하루치만 벽시계로 고침).
**Ralli 는 저장되는 값 자체가 틱 기반**이라 요약의 "운동시간" 과 세션 헤더가 실제보다 짧을 수
있다 — 1.1.7 에도 있는 문제라 **기존 기록만 봐도 판단된다.**

확인할 것 3가지와 고칠 때의 갈림길(일시정지를 어떻게 셀 것인가)은 위 탐색 문서에 정리했다.

**하루치는 앱 레이어에서 정지 제외로 갔다 (PR #26)** — HealthKit 이 세그먼트를 모르니 구간에서
정지를 빼는 일은 앱 몫이고, 그 시계를 두 개 둘 이유가 없다
([스펙](Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)).
**YJKit 통합과 Ralli 기존 기록 문제는 그대로 열려 있다** — 위 3가지 확인이 선행이다.

## 모노레포 공통

| 항목 | 상태 | 문서 |
|---|---|---|
| **앱 프라이버시 매니페스트** `PrivacyInfo.xcprivacy` — 세 앱 | **예정 — 이번 제출에도 빠졌다. 각 앱 다음 버전에** · 앱 자체 코드의 `UserDefaults` 사유 신고 (수집 데이터 없음). Ralli 의 Crashlytics 몫은 Firebase SDK 가 자기 매니페스트로 신고하므로 앱 쪽은 자체 코드만 적는다. 업로드를 막지는 않지만 ITMS-91053 경고 대상이다 | [하루치 출시 체크리스트](Apps/HaruchiFit/docs/plans/shared/2026/2026-10-19-release-checklist.md) 2절 |
| **"새로운 기능" 시트** — Ralli · 하루치 (YJKit 공용 후보) | **브레인스토밍 전** · 온보딩을 다시 띄우지 않고, 업데이트한 기존 사용자에게 그 버전의 새 기능만 시트 한 장(1~3개 · `계속`)으로 보여 준다. 새로 설치한 사람은 온보딩만 본다. 판정은 온보딩처럼 "마지막으로 본 번호" — 건너뛴 버전은 모아서. 사용자가 알아야 쓸 수 있는 기능이 든 버전에만 띄운다. 온보딩 번호(`OnboardingGate.version`)는 온보딩 내용을 바꿀 때만 올린다. 첫 대상은 Ralli 1.2.0 다음 버전. 정할 것: YJKit 공용으로 만들지 · Ralli 에 먼저 만들지 | — |
| **App Store 크리에이티브 에셋** — 하루치 한국어판 | **남은 것 하나** — 하루치 영어판 · Ralli 는 업로드 완료. 제작 도구 `tools/store-assets/` (README) | [Apple 가이드](https://developer.apple.com/app-store/asset-best-practices/) · [규격](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) |
| **앱 안 개인정보처리방침 링크** — iOS 앱에만 | **예정 — 설정 화면을 만들 때** (Ralli #8 · 하루치 07). 가이드라인 5.1.1(i) 이 앱 안 링크를 요구하지만 지금까지 링크 없이 통과했다. 워치에는 두지 않는다 — 한 앱으로 심사되고 워치는 웹을 못 연다 | 같은 체크리스트 1절 결정 2 |

스토어 문구는 앱마다 `Apps/<앱>/APPSTORE.md` 로 형상관리한다 ([루트 CLAUDE.md](CLAUDE.md) "스토어 문구").
`fastlane deliver` 로 올리고 내려받는 방식은 **보류했다** — 파일을 먼저 고치고 App Store Connect 에 붙여 넣는다.
[Ralli 리스팅 스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-05-20-app-store-listing-design.md)은 설계 초안으로만 남는다 — 스토어 실값과 이미 다르다.

## 규약 참고

- [루트 CLAUDE.md](CLAUDE.md) · [TennisCounter CLAUDE.md](Apps/TennisCounter/CLAUDE.md) · [YJKit README](Packages/YJKit/README.md)
- [Xcode 타깃 규약](docs/specs/2026/2026-09-03-xcode-target-conventions.md) — `INFOPLIST_KEY_*` 배열 불가, HealthKit 권한 문구, `ENABLE_USER_SCRIPT_SANDBOXING`
