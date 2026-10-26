# TODO

오랜만에 돌아왔을 때 여기부터 읽는다. 내용은 담지 않고 **어디에 문서가 있고 어디까지 됐는지**만 적는다.

- 항목이 끝나면 그 행에 `~~취소선~~` + 상태를 `완료 (커밋)` 으로 — **완료 커밋과 같은 커밋에서**
- 출시 커밋(`📝 x.y.z+n 버전 배포`)에서 취소선 행을 비운다
- 남은 항목이 없으면 `현재 대기 중인 작업 없음` 한 줄. 파일은 지우지 않는다

`feat/ralli` 은 PR #11 로 머지되어 더 쓰지 않는다. 새 작업은 항목별 브랜치를 판다.
트랙 A·B 를 동시에 굴리려면 워크트리 2개가 필요하다 — 순차로 가면 메인 체크아웃 하나로 충분하다.

## Ralli — 현재 1.1.9 (출시됨) · 다음 출시 대기 항목

2026-10-02 갱신. 파일 충돌을 실제로 따져 트랙으로 나눴다.

```
트랙 A (iOS)     5̶ → 2̶ → 1̶ ──┐            ← 전부 완료 (실기기 확인 포함)
트랙 B (워치)     3̶ → 4̶ ──────┤→ 6̶ 코드·이미지 → 7   ← 6 은 실기기 확인까지 완료
트랙 C (YJKit)   MonitoringCore ┘            ← 집에서 (Firebase 콘솔 선행)
트랙 D (iOS)     9̶ 세션 중심 재편            ← 실기기 확인까지 완료

다음 차례: 트랙 C·#7 은 집에서 몰아서. #8 은 아직 브레인스토밍 전.
```

- **A ↔ B ↔ C 는 겹치는 파일이 하나도 없다.** 셋을 동시에 굴려도 된다
- **트랙 내부는 순차다** — A 는 `MatchDetailSheet`·`iOSApp.swift`·Localizable 을, B 는 `ScoreViewModel` 을 공유한다
- **#7 은 맨 마지막에 단독으로.** iOS·워치 양쪽 `WorkoutSessionViewModel` + `iOSApp.swift` + pbxproj 를 다 건드려 #1·#2·#3·#6 과 전부 겹친다
- **#6 Task 4(스크린샷)가 두 트랙의 합류점.** 뼈대(Task 1~3)는 트랙 A 안에서 먼저 끝난다
- #8 은 별도 (브레인스토밍 전)

같은 파일을 건드리는 항목들 (끝난 5·2 는 뺐다) — `project.pbxproj`(1·7) /
`TennisCounter-Info.plist`(1) / `iOSApp.swift`(6·7) / iOS `WorkoutSessionViewModel`(1·7) /
Localizable(6·10) / 워치 `WorkoutSessionViewModel`(3·7) / iOS `History/`(9·10)

| # | 항목 | 트랙 | 상태 | 문서 |
|---|---|---|---|---|
| ~~5~~ | ~~String Catalog(xcstrings) 전환~~ | A | **완료** (PR #15) · 실기기 확인만 남음 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-string-catalog-migration.md) — 하드코딩 정리까지 범위가 늘었다 (§추출 문제) |
| ~~2~~ | ~~iOS 통계 UI 리디자인~~ | A | **완료** (PR #16) · 실기기 확인만 남음 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-08-25-summary-history-redesign-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-summary-history-redesign.md) · [Notion](https://app.notion.com/p/3bacd15e48f180b3a810e95f63854aa6) |
| ~~1~~ | ~~WorkoutShareUI 붙이기 (공유 시트)~~ | A | **완료** (PR #20 → 인스타 경로 제거 → `feat/share-card-sticker` 카드 개편) · 실기기 확인 완료 | [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-workout-share-button.md) · [제거 플랜](Packages/YJKit/docs/plans/ios/2026/2026-09-13-share-sheet-only.md) · [Kit 사용법](Packages/YJKit/README.md#workoutshareui-사용법) |
| ~~3~~ | ~~햅틱 (워치 전용)~~ | B | **완료** (PR #18) · 실기기 확인 완료 | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-match-haptics.md) — 설정 연동은 #8 때 `MatchHaptics.play` 첫 줄에서. 포인트 `.click`이 약하게 느껴지나 유지하기로 결정 |
| ~~4~~ | ~~크라운 점수 입력 (워치, 위=나 아래=상대)~~ | B | **완료** (버그 수정 PR, 실기기 확인 완료) | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-crown-scoring.md) — PR #22 구현이 회전량 기반이라 실기기에서 오작동, 디텐트 방식으로 재구현. 온보딩(#6) 항목 하나 파생 |
| ~~6~~ | ~~온보딩 **5페이지** (워치 중심, iOS 만)~~ | A → 합류 | **완료** (PR #25) · 실기기 확인 완료 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md) (09-18 개정) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-17-onboarding-watch-focused.md) — 4페이지에서 5페이지로 재편, 기능 목록 페이지 제거. 워치 3장은 Figma 목업 합성, 공유 그림은 인스타 스티커 화면 |
| ~~7~~ | ~~Firebase Crashlytics (iOS + 워치, 익스텐션 제외)~~ | 단독 (맨 뒤) | **완료** (Kit [PR #35](https://github.com/qlrogo91lp/yj-apps/pull/35) · Ralli [PR #36](https://github.com/qlrogo91lp/yj-apps/pull/36)) · 실기기 확인 완료. plist 는 git 밖, CI 는 Noop 으로 돈다. 워치는 크래시를 못 잡아 non-fatal 만 | [스펙](Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md) → [YJKit 플랜](Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md) (트랙 C, 지금 병렬 가능) → [Ralli 플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) |
| 8 | 설정 페이지 + 다른 앱 노출 | — | **논의 필요 — 아직 브레인스토밍 전** · 앱 안 개인정보처리방침 링크(iOS)도 여기서 넣는다 (아래 "모노레포 공통") | 아래 "남은 논의" 참고 |
| ~~9~~ | ~~iOS 기록·요약 **세션 중심 재편**~~ | D | **완료** · 실기기 확인 완료 | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-18-session-centric-history.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-18-session-centric-history.md) — `WorkoutSessionRecord` 신설이 포함된다. #2 스펙을 개정한다 |
| ~~10~~ | ~~기록 삭제 시 **건강 앱 워크아웃도 삭제**~~ | E (YJKit+iOS) | **완료** ([PR #29](https://github.com/qlrogo91lp/yj-apps/pull/29)) · 실기기 확인 완료 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-21-healthkit-workout-deletion.md) — YJKit `WorkoutDeletionService` 신설. 건강 앱에서 먼저 지운 경우 Ralli 기록은 유지한다 |
| 11 | 클럽 대진표 · 실시간 중계 (Firebase) | — | **탐색 중** — 다음 출시 범위 아님 | [탐색 문서](Apps/TennisCounter/docs/ideas/club-live-scoring.md) — CourtMate 분석에서 출발. 백엔드·단위·기록자·게스트까지 결정, 안드로이드·매칭·ELO 는 열림 |
| 12 | 워치 크라운 포커스 복구 · 워크아웃 종료 시각 보존 | B + YJKit | **코드 수정 완료** ([PR #32](https://github.com/qlrogo91lp/yj-apps/pull/32)) **· 실기기 확인 대기** | [작업 기록](Apps/TennisCounter/docs/logs/2026/2026-09-28-crown-focus-and-session-end-time.md) — 알림·저휘도 복귀 뒤 크라운과 종료 버튼 시각 전달 확인 필요 |
| ~~13~~ | ~~iOS 건강 쓰기 권한 문구를 삭제 연동 문구로 맞춤~~ | E | **완료** ([PR #34](https://github.com/qlrogo91lp/yj-apps/pull/34)) | — |
| ~~14~~ | ~~매치 화면의 `WorkoutSessionViewModel` 의존 끊기 (iOS + 워치)~~ | — | **완료** ([PR #37](https://github.com/qlrogo91lp/yj-apps/pull/37)) · 수동 확인 대기 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-10-06-match-view-dependency-cut.md) — Notion 폴더 재정비 논의의 B안. 폴더 이동(A안)·`MatchFlowView` 분리는 별도 판단 |
| ~~15~~ | ~~매치 폴더를 `WorkoutSession/` 하위로 이동 (iOS + 워치, A안)~~ | — | **완료** ([PR #39](https://github.com/qlrogo91lp/yj-apps/pull/39)) | [플랜 2단계](Apps/TennisCounter/docs/plans/shared/2026/2026-10-06-match-view-dependency-cut.md) — 코드 변경 없음, 폴더 rename 32건 + 구조 문서·규칙 예시 갱신 |
| 16 | **개인정보처리방침에 Crashlytics 반영 (yjlogs)** — #7 이 든 버전을 **배포하기 전에** | — | **예정** — 지금 방침은 "no analytics SDKs, no third-party tracking" 이라 Crashlytics(크래시 리포트를 Firebase 로 전송)와 어긋난다. #7 버전은 아직 배포 전이라 지금은 틀리지 않았다. 크래시 데이터 문단 추가 · 해당 문장 수정 · 시행일 갱신. ASC 앱 개인정보는 10-02 에 이미 반영 | yjlogs `apps/web/src/app/(main)/apps/ralli/privacy/page.tsx` |
| 17 | **동점 경기 수동 무승부 종료 (iOS + 워치)** | — | **구현·자동 검증 완료 · 사용자 검토 대기 (10-26, `feat/ralli-manual-draw`)** — 첫 0:0을 제외하고 세트·게임·포인트 동점일 때 나가기 팝업에 `무승부로 종료` 추가. 원세트 결과에 게임 점수 표시, 무승부 전적·캘린더 구분, 폰↔워치 종료 결과 및 저장 데이터 동기화. 작은 워치 실화면 배치는 확인 대기 | [iOS 점수 로직](Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift) · [워치 점수 로직](Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift) |

### 집 맥북에서 할 것

- [x] 통계 리디자인 작업물 찾기 — `feature/tennis-counter` 워크트리의 커밋 66a54d8 (스펙 문서 1개). 규약 경로로 이관 완료
- [x] #2 구현 플랜 작성

**트랙 A (iOS)** — 순서대로

- [x] 5번 플랜 실행 — 전환 + 하드코딩 정리. iOS 76키(신규 5) · 워치 27키. PR #15
- [x] 2번 플랜 실행 — Task 8개, 테스트 154개 통과. 삭제가 저장소에 반영되지 않는 버그를 잡았다. PR #16
- [x] 1번 플랜 실행 (Task 1~6) — 두 화면에 버튼, 테스트 162개 통과. PR #20
- [x] ~~Meta App ID 발급(사용자)~~ — **개발자 계정 발급 실패로 포기.** 인스타 딥링크 경로를 걷어내고 공유 시트만 남겼다 ([제거 플랜](Packages/YJKit/docs/plans/ios/2026/2026-09-13-share-sheet-only.md))
- [x] **1번 실기기 확인** (Task 7) — 인스타 스토리 공유 확인. 이어서 카드를 개편했다 (`feat/share-card-sticker`):
      피트니스 앱 스타일 2×2 + 원형 로고 머리줄, **스티커로 복사**(배경 없는 스티커) 추가,
      공유 시트는 인스타가 투명을 검게 채워 네모 카드로, 버튼은 원형 아이콘으로 기록 상세 우상단
- [x] 6번 뼈대 (Task 1~3) — 게이트·페이지 4장·앱 진입 분기. 시뮬레이터에서 노출/미노출 확인. PR #17

**트랙 B (워치)** — A 와 동시 진행 가능

- [x] 3번 플랜 실행 — 이벤트 9종, 워치 테스트 81개 통과. PR #18
- [x] **3번 실기기 패턴 확인** (Task 4) — 되돌리기·게임·세트 경계 구분 확인. 포인트는 체감이
      약해 `.directionUp`을 시도했으나 어색해 `.click` 유지. 저장 ACK·폰 일시정지 햅틱은 미확인
- [x] 4번 플랜 실행 — 위=나·아래=상대, 빠른 다중 디텐트 처리, 포커스 복구. PR #22
- [x] **4번 실기기 확인** (Task 2) — 디텐트 방식으로 재구현 후 정상 동작 확인. 최초 구현(회전량
      누적)은 한 번 돌리면 세트 스코어가 4까지 오르는 버그가 있어 별도 버그 수정으로 처리

**트랙 C (YJKit)** — A·B 와 무관, 지금 시작 가능

- [x] Firebase 콘솔에 프로젝트 "Ralli" + Apple 앱 2개(iOS·워치 번들 ID) 만들고 `GoogleService-Info.plist` 2개 받기 —
      지난주 시도에서 삭제 대기로 남은 iOS 앱이 번들 ID 를 붙잡고 있어 복원해서 썼다. plist 는 Ralli 연동 PR 에서 커밋
- [x] YJKit `MonitoringCore` 플랜 Task 0~3 — [PR #35](https://github.com/qlrogo91lp/yj-apps/pull/35) CI 통과 (전체 약 10분 30초, Firebase 해석 +1분 20초).
      저장소가 공개라 plist 를 git 에서 빼고 `configureFirebase()` → `start()`(plist 없으면 Noop)로 바꿨다.
      **머지 완료** (09-28)
- [x] YJKit `MonitoringCore` 플랜 (Task 0 스파이크 → CI 통과 → PR 머지) — PR #35

**합류 후**

- [x] **6번 스크린샷 5장** — 워치 3장은 3x 로 재내보내 넣었다. 스와이프는 영어·컴플리케이션은 한국어 한 장,
      공유는 인스타 스티커 화면. 그림 자리는 `OnboardingScreenshotPage` 가 비율 0.80 박스로 고정한다
- [x] 6번 시뮬레이터에서 ko/en 5장 넘겨보기 — 크기가 흔들리지 않는지, 워치 3장이 선명한지
- [x] ~~6번 크라운 화살표 위치 조정~~ — 화살표를 이미지에 구워 코드 오버레이를 지웠다 (플랜 Task 4 폐기)
- [x] 7번 Ralli 연동 — [PR #36](https://github.com/qlrogo91lp/yj-apps/pull/36). 실기기 확인: ✅ iOS 크래시가 `iOSApp.swift:105` 로 심볼 붙어 올라옴 (10-01) /
      ✅ 워치 → Firebase non-fatal 경로 (임시 버튼). **워치는 크래시를 못 잡는다** — watchOS 가 크래시 핸들러를 허용하지 않는다
      (스펙 "워치 크래시" 행), 워치 크래시는 Xcode Organizer. 경위는 [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) Task 4·실행 기록

**아무 때나**

- [x] **App Store Connect 앱 개인정보에 Crash Data · Other Diagnostic Data 추가** — 완료 (10-02). 사용 목적 앱 기능, 사용자 연결 아니요, 추적 아니요
- [x] **#9 실기기·워치 확인** — 2경기 저장 뒤 5분 후 종료해 카드 시간이 종료 시각까지인지, 평균 심박이 채워지는지,
      경기 없는 운동이 `경기 없음`으로 보이는지, 구 기록이 시간·칼로리와 `–` 심박으로 보이는지,
      배포 뒤 구/신 레코드 혼합 CloudKit 동기화가 정상인지 확인
- [x] **#10 실기기 확인** — 워치에서 만든 운동을 Ralli 기록에서 삭제했을 때 건강 앱 워크아웃도 지워지는지,
      HealthKit 쓰기 권한 허용·거부와 이미 건강 앱에서 지운 경우에도 Ralli 기록 삭제가 정상 완료되는지 확인
- [ ] **#5 실기기 확인 — 워치만 남음.** 조기 종료 다이얼로그가 **"경기 중단"**(워치용 짧은 표현)
      인지, HealthKit 권한 문구가 한국어인지. iOS 쪽은 #2 가 그 화면을 다시 만들어 아래 항목이 흡수했다
- [ ] **Xcode.app 에서 한 번 빌드** — `xcodebuild` 는 카탈로그를 갱신하지 않는다. Xcode 가
      추출을 다시 돌렸을 때 정리한 항목이 되살아나지 않는지 `git status` 로 확인
- [ ] **#2 실기기 확인** (한국어 기기) — 요약(3칸·전적 줄·추이 차트·최근 세션),
      기록 목록의 세션 묶음과 스와이프 삭제, 캘린더 다중 점·날짜 선택,
      기록 상세 스코어보드와 `경기 방식`·`시간` 라벨, 앱 전체가 다크로 고정되는지.
      **삭제한 경기가 앱을 다시 켜도 안 돌아오는지** — 이번에 고친 버그다
- [ ] **다음 출시 = Crashlytics 첫 탑재 버전** (1.1.9 는 `🔖 1.1.9+1` 이 PR #35·#36 머지보다 먼저라 빠졌다). 아카이브 때:
      ① 아카이브하는 맥의 `iOSApp/`·`WatchApp/` 에 `GoogleService-Info.plist` — 없으면 dSYM 스크립트가 아카이브를 실패시킨다
      ② Organizer Privacy Report 에 Firebase 항목 ③ 출시 뒤 Firebase dSYM 탭에 그 버전 UUID "업로드됨" ④ Organizer › Crashes 한 번 열어보기
- [ ] **워치 저장 실패 non-fatal 콘솔 확인** — 워치에 "저장 실패" 는 떴는데(10-02) 며칠이 지나도 콘솔 `ralli-watch` 에 `Ralli.Save` code 3 이 안 올라왔다.
      다음은 `-FIRDebugEnabled` 로 업로드 로그를 본다. 절차·dSYM `62AD67DD` 누락 메모는 [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md) Task 4
- [ ] **iOS 가 워치 저장 뒤에도 "경기 진행 중" 에 남는다** (10-02, 원인 미확인) — 워치는 "저장됨" 까지 갔다. 같은 경기 점수였는지,
      기록 탭에 저장됐는지부터 본다. 의심 경로: 경기 시작이 `applicationContext` 에 남아 콜드 런치 때 다시 읽힘 / `sendMessage` 실패 시 `errorHandler: nil` 이라 경기 종료가 유실.
      **10-26 재검토: PR #65 는 이 경로를 건드리지 않았다** — 폰 화면은 `receivedMatchEnd` 로만 결과로 넘어가고, 그 메시지는 여전히 `.reliable`.
      기록 손실은 없고 폰 화면만 남아 1.2.0 은 그대로 낸다. 재현되면 폰이 저장 요청을 받을 때 진행 중 경기를 결과로 넘기는 쪽이 가장 작다
- [ ] **연속 경기 때 이전 경기의 저장 응답이 지금 경기 버튼을 "저장됨" 으로 바꿀 수 있다** (10-26, 알려진 문제 · 보류) —
      `MatchSaveResultMessage` 가 `sessionId`(운동)만 싣고 경기 ID 가 없다. 재시작 뒤에는 응답이 무시되고 기록도 결국 저장되므로,
      놓치는 건 폰 저장이 실제로 실패한 경우뿐이다. 고친다면 응답에 `matchId` 를 선택 필드로 더하고 워치가 지금 경기와 비교한다
- [x] ~~**`saveFromWatchPersistsMatch` 테스트 오염 수정** — 싱글턴 `MatchPersistenceService.shared` 에
      인메모리 컨테이너를 꽂았던 테스트가 끝난 뒤 다른 테스트가 그 컨텍스트를 조회해
      `NSInternalInconsistencyException: "No eligible connection available"` 로 죽는다. 단독 실행은 통과.
      싱글턴 대신 주입으로 바꾸는 쪽이 근본적이다 (`@Suite(.serialized)` 는 증상만 덮는다).
      **원인은 이름 없는 기본 인메모리 설정이다** — 저장소 이름을 `default` 로 공유하고 iCloud 권한이 있으면 CloudKit 미러링이 켜진다.
      `saveCurrentMatchReturnsMatchOnSuccess`·`HistoryViewModelTests` 도 같은 이유로 죽는다 (2026-09-29 확인).
      `HealthKitDeletionTests` 픽스처가 처방이다 — 고유 이름 + `cloudKitDatabase: .none` + 컨테이너 보관. 같은 설정으로 바꾸면 대부분 풀린다~~ 완료 (PR #38)
- [x] `~/orca/workspaces/yj-apps/` 워크트리 3개 정리 — 워크트리·브랜치 모두 제거 완료

### 남은 논의 — #8 설정 페이지 (2026-09-07 시점)

아직 아이디어 단계. 다음 세션에서 브레인스토밍부터 시작한다. 지금까지 다른 항목에서 **설정 페이지로 미뤄 둔 것들**:

- 햅틱 on/off — 진입점 `MatchHaptics.play(_:)` 첫 줄. 전체 하나 또는 3그룹(점수 / 저장 알림 / 일시정지 알림). 값을 워치 로컬에 둘지 iOS 에서 `applicationContext` 로 동기화할지 미정
- 크래시 수집 on/off — `Crashlytics.setCrashlyticsCollectionEnabled(false)`. Kit 에 래퍼 추가 필요
- "사용법 다시 보기" — `OnboardingView` 를 시트로 재사용, 플래그는 안 건드림
- 다른 앱(골프·하루치) 노출 — 어떤 형태로(App Store 링크 / 배너 / "yj 의 다른 앱" 섹션), 어느 위치에. 완전 미논의
- 열린 질문: iOS 설정 탭을 4번째 탭으로 둘지 요약 탭 우상단 기어로 둘지 / 워치에도 설정 화면을 둘지 / 모드 옵션(No-Ad 등) 설명을 여기 둘지 모드 화면 ⓘ 로 둘지

### ~~남은 논의 — #9~~ → 결정은 [세션 중심 재편 스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-18-session-centric-history.md)으로 옮겼다

## YJKit

| 항목 | 상태 | 문서 |
|---|---|---|
| `MonitoringCore` (CrashReporting 프로토콜 + Crashlytics 구현) | **구현 완료** ([PR #35](https://github.com/qlrogo91lp/yj-apps/pull/35) · Ralli 연동 [PR #36](https://github.com/qlrogo91lp/yj-apps/pull/36)) | 위 Ralli #7 과 같은 문서. 골프·하루치 연동은 별도 (Firebase 프로젝트 앱마다 새로) |
| **건강 앱에서 지운 것을 앱이 따라 지운다** (`HKDeletedObject`) | **미착수** — 브레인스토밍 전. 3개 앱이 같은 구조라 Kit 이 한 번 정한다 | 하루치 [import 스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-21-healthkit-workout-import.md) 4절에 정할 것이 적혀 있다. **Ralli #10 과 방향이 반대다** — 그쪽은 앱에서 지우면 건강 앱을 지운다 |
| **워크아웃 종료 순서** — `stopWorkout()` 이 `session.end()` 를 먼저 불러 마무리 중 앱이 멈춘다 (3개 앱 공통) | **구현 (10-26, `fix/workout-stop-order`)** — `stopActivity` → `.stopped` 대기 → 마무리 → `end()` 순서로. Ralli 다음 출시에 싣는다. 실기기 확인: 경기 종료 직후 손목을 내리고 1~2분 뒤 건강 앱에 운동·종료 시각이 맞는지. 남은 것: 워크아웃 복구(`handleActiveWorkoutRecovery`) · `didFailWithError` · `startWorkout` 의 `catch {}` | [전송 유실 플랜](docs/plans/2026/2026-10-25-watch-record-delivery.md) "범위 밖" 절 |
| **리팩터링: 온보딩 틀 공통화** (가칭 `OnboardingUI`, iOS) | **대기 — 세 앱 모두 현재 출시분 심사가 끝난 뒤 새 버전으로 (10-26 결정)**. Ralli · 하루치 · 골프(2.1.2) 가 같은 틀을 앱마다 복사해 쓴다. 공통: `OnboardingGate`(세 앱 동일) · 페이지 넘기기 틀 · 4:5 그림 + 고정 높이 글 배치 · `LoopingVideo`(동작 줄이기 시 정지 이미지). 앱이 넘길 것: 배경·버튼 색, 건너뛰기 유무(하루치는 없음), 마지막 버튼 문구, 글 영역 높이(112/190) · 작은 글씨 줄, 그림. 영상·이미지는 앱 번들에 두고 경로만 넘긴다. 공용 버튼 문구는 패키지 ko/en (`WorkoutShareUI` 와 같은 방식) | 골프 [온보딩 스펙](Apps/GolfCounter/docs/specs/ios/2026/2026-10-26-onboarding-design.md) "코드 배치" · Ralli `Apps/TennisCounter/iOSApp/Features/Onboarding/` · 하루치 `Apps/HaruchiFit/iOSApp/Features/Onboarding/` |
| ~~`WorkoutShareUI` 공유 카드 배경색을 Kit 이 소유~~ | **완료** (`feat/share-card-sticker`) — 짙은 회색 카드 + 지표별 고정 색. 앱은 원형 로고 `badgeColor` 만 넘김 | 아래 "카드 대비" · [Kit 사용법](Packages/YJKit/README.md#workoutshareui-사용법) |

### 카드 대비 (2026-09-09)

공유 카드는 배경이 `accentColor` 그라디언트고 텍스트가 **전부 흰색**인데, 사이에 대비를 보정하는
장치가 하나도 없다. 앱이 밝은 색을 주면 그대로 안 읽힌다.

| 앱 | `brand` | 흰 텍스트 대비 |
|---|---|---|
| GolfCounter | 짙은 초록 | 13.4 : 1 ✔ |
| Ralli | 형광 라임 | **1.45 : 1** ✘ (카드 최상단 행) |
| 하루치 핏 | 주황 | **2.22 : 1** ✘ |

3개 중 2개가 실패한다. 하루치는 로드맵 Phase 3 #6 이 "`WorkoutShareUI` 그대로 사용"이라
지금 안 고치면 그때 같은 문제를 겪는다. PR #20 은 `.brand` 그대로 머지했다 — 색은 별건으로 뺐다.

브레인스토밍에서 **`accentColor` 파라미터를 완전히 제거하고 Kit 이 배경색을 소유**하는 쪽을 골랐다
(`WorkoutShareStyle(logo:)` 만 남음). 앱이 색을 못 주므로 대비 사고가 구조적으로 막히고, 앱별
정체성은 로고로만 드러난다. **다만 화면을 보고 다시 판단하기로 했다** — 확정 아님.

**2026-09-16 해결.** 실기기에서 시안을 고르며 그라디언트를 걷어내고 짙은 회색 카드(`#1C1D1B`)에
값 색(시간 라임 · 칼로리 호박 · 심박 산호)을 Kit 이 고정했다. 흰 글씨 17 : 1. 앱 정체성은 원형 로고
배경색(`badgeColor`)으로만 드러난다. 결정은 대화 중 시안 페이지로 확정해 스펙 문서 대신 README 와 PR 에 남겼다.
로컬 SPM 이라 Kit 만 먼저 머지할 수 없어 PR 은 하나로 묶었다.

## HaruchiFit — 1.0.0 출시됨 · 1.0.1 대기

설계 근거는 [로드맵](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md) · [제품 스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) · [아키텍처](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md).
1.0.0 에 들어간 항목은 출시로 정리했다 (10-25). 지난 상태는 git 이력이 갖는다.

| 항목 | 상태 | 문서 |
|---|---|---|
| **1.0.1** 워치 기록 전송 유실 수정 (하루치 · 골프 · Ralli, YJKit `.queued`) · 하루치 칼로리 활동 칼로리로 통일 | **머지 완료 (10-25, [PR #63](https://github.com/qlrogo91lp/yj-apps/pull/63) · [#64](https://github.com/qlrogo91lp/yj-apps/pull/64) · [#65](https://github.com/qlrogo91lp/yj-apps/pull/65))** · 실기기 확인 대기 (아래) — 다음: 버전 올림 · 출시 노트. 골프 · Ralli 수정은 각 앱의 다음 출시에 실린다 | [플랜](docs/plans/2026/2026-10-25-watch-record-delivery.md) |
| 07 설정 | **보류** — 만들 때 `정보` 그룹의 개인정보처리방침 링크(iOS)를 반드시 넣는다 | 로드맵 Phase 5 · 스펙 07절 |
| CloudKit 엔타이틀먼트 | **예정** — 프로비저닝 작업(사용자) · 로컬 폴백이 있다 | 로드맵 "언제든" |

### 1.0.1 실기기 확인

**하루치** — 근력 · 유산소를 번갈아 넣은 운동을 끝내고 저장. 폰 기록에 구간이 나뉘어 있고 `kcal` 이 워치 요약 숫자와 같은지
- [ ] 폰 앱을 백그라운드로 둔 채
- [ ] 폰 앱을 완전히 종료한 채 → 운동 2개를 연달아 끝낸 뒤 폰 앱을 연다 (밀린 기록 2건이 다 들어오는지)

**골프**
- [ ] 폰 앱을 종료한 채 라운드를 끝내고 저장 → 폰 앱을 열면 라운드가 있다

**Ralli** — `CURRENT_PROJECT_VERSION = 1` 고정이라 App Store 설치본과 Xcode 설치본이 둘 다 "1.1.9 (1)" 로 보인다. Xcode 설치본인지 먼저 확인
- [x] ~~폰 앱을 백그라운드로 둔 채 → 워치 "저장됨" 또는 "폰에서 저장 대기" → 폰 앱을 열면 기록 1건~~ — 검증 생략 (10-26): 보내는 쪽은 시스템 큐, 받는 쪽은 `WatchMatchSaverTests` 가 덮는다
- [x] ~~폰 앱을 완전히 종료한 채 → 경기 2개 저장 → 폰 앱을 열고 바로 새 경기를 시작해도 2건 다 남는다~~ — 같은 이유로 생략
- [ ] 운동 종료 시 폰 미러 화면이 닫히는 지연이 견딜 만한지 (플랜 D6)

### 열려 있는 것

- [ ] **피트니스 앱 운동 목록 아이콘이 자리 표시자** (10-07, 원인 미확인) — 하루치 운동 행이 앱 아이콘 대신 회색 동심원으로 뜬다
      (테니스 앱은 로고가 나온다). 앱 아이콘 연결은 Ralli 와 같다. 건강 앱 › 앱 목록의 아이콘 확인 · 앱 재설치 후 1~2분짜리 운동 재확인 ·
      두 앱의 설치 방식(TestFlight / Xcode) 비교 순으로 좁힌다
- [ ] **경과시간이 뒤처지는지** — 워크아웃 중 손목을 30초 내렸다 올렸을 때 시간이 건너뛰는지
      멈춰 있었는지. 3개 앱 공통 ([탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md))
- [ ] **잔디 농도 컷 조정** — 기록이 쌓인 뒤 농도가 실제 운동 시간과 맞는지 본다. 지금 컷은 30/60/90분 (D-M6)

## YJKit — 확인 필요

| 항목 | 상태 | 문서 |
|---|---|---|
| ~~HealthKit 권한 시트 정리 (3개 워치 앱)~~ | **완료** ([PR #48](https://github.com/qlrogo91lp/yj-apps/pull/48)) · 수동 확인 생략 | [플랜](Packages/YJKit/docs/plans/shared/2026/2026-10-11-healthkit-permission-trim.md) |
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

## GolfCounter

| 항목 | 상태 | 문서 |
|---|---|---|
| **iOS 온보딩 3장** (모드 전환 영상 · 크라운 스코어카드 영상 · 컴플리케이션) | **구현 완료 (`feat/golf-onboarding`) · PR 대기 · 2.1.2 에 싣는다** — 건강 앱 페이지는 뺐다 (10-26). 실기기 확인 대기 | [스펙](Apps/GolfCounter/docs/specs/ios/2026/2026-10-26-onboarding-design.md) · [플랜](Apps/GolfCounter/docs/plans/ios/2026/2026-10-26-onboarding.md) |
| **라운드 위치 지도** | **아이디어 (10-26) — 구현 미착수** · 워치에서 라운드 시작 위치를 1회 저장하고, 폰 상세 지도에서 기록 위치 핀과 주변 장소를 확인한다. 골프장명은 수동 입력 유지 | [기존 설계 §9](Apps/GolfCounter/docs/specs/shared/2026/2026-07-31-golfcounter-rebuild-design.md#9-mapkit-골프장-감지) — 자동 이름 감지에서 위치 지도 중심으로 방향 변경 예정 |

## 모노레포 공통

| 항목 | 상태 | 문서 |
|---|---|---|
| ~~**수출 규정 키** `ITSAppUsesNonExemptEncryption = NO` — 세 앱 iOS · 워치 타깃~~ | **완료 (10-19, `chore/export-compliance-key`)** · TestFlight 업로드에서 질문이 안 뜨는 것 확인 (10-20, 하루치) — 업로드마다 뜨는 수출 규정 질문을 없앤다. 표준 암호화만 쓰므로 면제 | [하루치 출시 체크리스트](Apps/HaruchiFit/docs/plans/shared/2026/2026-10-19-release-checklist.md) 2절 |
| **앱 프라이버시 매니페스트** `PrivacyInfo.xcprivacy` — 세 앱 | **예정 — 각 앱의 다음 배포 전** · 앱 자체 코드의 `UserDefaults` 사유 신고 (수집 데이터 없음). Ralli 의 Crashlytics 몫은 Firebase SDK 가 자기 매니페스트로 신고하므로 앱 쪽은 자체 코드만 적는다. 지금 세 앱 모두 없는데 심사는 통과했다 — 업로드를 막지는 않지만 ITMS-91053 경고 대상이다 | 같은 체크리스트 2절 |
| **"새로운 기능" 시트** — Ralli · 하루치 (YJKit 공용 후보) | **브레인스토밍 전** · 온보딩을 다시 띄우지 않고, 업데이트한 기존 사용자에게 그 버전의 새 기능만 시트 한 장(1~3개 · `계속`)으로 보여 준다. 새로 설치한 사람은 온보딩만 본다. 판정은 온보딩처럼 "마지막으로 본 번호" — 건너뛴 버전은 모아서. 사용자가 알아야 쓸 수 있는 기능이 든 버전에만 띄운다. 온보딩 번호(`OnboardingGate.version`)는 온보딩 내용을 바꿀 때만 올린다. 첫 대상은 Ralli 다음 버전. 정할 것: YJKit 공용으로 만들지 · Ralli 에 먼저 만들지 | — |
| **App Store 기본 언어를 영어로** — Ralli · 골프 | **예정 — 다음 배포 때** · **Ralli · 골프 모두 기본 언어가 한국어다** (10-20 확인). 이름은 고치지 않는다 — 기본 언어만 바꾸면 목록에도 기존 영어 이름이 나온다. 사용자 언어에 맞는 현지화가 없으면 App Store 는 기본 언어로 보여 주므로, 영어 · 한국어가 아닌 기기(독일 · 일본 등)에는 한국어 이름 · 설명이 보일 가능성이 크다 (Apple 문서 기준, 실기기 미확인). App Store Connect 앱 정보 → 기본 언어 → 영어(미국). 영어 현지화는 이미 있어 바로 고를 수 있고, 한국 사용자에게는 계속 한국어가 보인다. 하루치는 처음부터 영어 기본 | — |
| **App Store 크리에이티브 에셋** (제품 페이지 헤더 · 검색 결과) — Ralli · 하루치 | **하루치 완료 — 헤더(21:9 · 28.8초) · 검색 결과(영어판 · 12초) 업로드 (10-25)**. **Ralli 완료 (10-25)** — 헤더(코트 + 워치, 8.8초) · 검색 결과(영어, 탭·크라운 점수 입력, 8.8초) mp4, 업로드 대기. 제작 도구 `tools/store-assets/` (README). 남은 것: 하루치 한국어판 · **예정 — 다음 배포 때 (10-21 기록)** · iOS 27 부터 생긴 자리. 헤더 21:9 · 검색 결과 3:2 · 둘을 겸하는 공용 16:9 PNG(5244×2950). 이미지·영상 모두 가능(영상 5~30초, 음소거 반복 재생이라 소리 없이 읽혀야 한다). 검색 결과는 선택 — 없으면 지금처럼 스크린샷·프리뷰가 나온다. 4+ 등급 기준 · 가격·URL·수상 표기 금지. ASC 새 버전 제출 또는 Asset Library 로 올린다. 정할 것: 이미지로 갈지 영상으로 갈지 · 공용 한 장으로 갈지 · `APPSTORE.md` 에 에셋 절을 둘지 | [Apple 가이드](https://developer.apple.com/app-store/asset-best-practices/) · [규격](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) |
| **Ralli 온보딩 미디어** — 1 크라운 영상 · 3 컴플리케이션 강조 · 4 건강 상태바 제거 | **적용 (10-25, `feat/ralli-onboarding-media`)** · 실기기 확인 대기: 1페이지 영상 재생 · "동작 줄이기" 켰을 때 정지 이미지. **2 스와이프는 워치 스크린샷 대기** — 컨트롤 · 지표 화면 × 한국어 · 영어 4장이 오면 세 화면을 넘기는 영상으로 | 도구 `tools/store-assets/README.md` |
| **앱 안 개인정보처리방침 링크** — iOS 앱에만 | **예정 — 설정 화면을 만들 때** (Ralli #8 · 하루치 07). 가이드라인 5.1.1(i) 이 앱 안 링크를 요구하지만 지금까지 링크 없이 통과했다. 워치에는 두지 않는다 — 한 앱으로 심사되고 워치는 웹을 못 연다. 하루치 1.0 도 링크 없이 통과했다 | 같은 체크리스트 1절 결정 2 |
| ~~**App Store 문구 깃 관리** — 앱마다 `Apps/<앱>/APPSTORE.md` 하나~~ | **완료** (`chore/store-metadata`) — 문구만 텍스트로 형상관리하고 반영은 수동. 세 앱 모두 파일을 만들었다. **Ralli·골프의 키워드는 비어 있다** — 공개되지 않아 App Store Connect 에서 옮겨 적어야 한다 (부제·프로모션 텍스트·스크린샷 캡션은 10-22 공개 스토어에서 채웠다) | [루트 CLAUDE.md](CLAUDE.md) "스토어 문구" · 배경 [CI 스펙](docs/specs/2026/2026-08-27-ci-pipeline-design.md) §비범위 · §후속 과제 |

`fastlane deliver` 로 올리고 내려받는 방식은 **보류했다** — API 키 관리 없이 문구 형상관리부터 시작한다.
파일을 먼저 고치고 App Store Connect 에 붙여 넣는다. 도구는 필요해지면 다시 본다.

Ralli·골프의 이름·설명·출시 노트는 2026-10-12 공개 스토어 실값이다. [Ralli 리스팅 스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-05-20-app-store-listing-design.md)은
설계 초안으로만 남는다 — 스토어 실값과 이미 다르다 (이름 · 설명의 공유 줄).

## 규약 참고

- [루트 CLAUDE.md](CLAUDE.md) · [TennisCounter CLAUDE.md](Apps/TennisCounter/CLAUDE.md) · [YJKit README](Packages/YJKit/README.md)
- [Xcode 타깃 규약](docs/specs/2026/2026-09-03-xcode-target-conventions.md) — `INFOPLIST_KEY_*` 배열 불가, HealthKit 권한 문구, `ENABLE_USER_SCRIPT_SANDBOXING`
