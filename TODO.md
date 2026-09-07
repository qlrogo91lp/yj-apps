# TODO

오랜만에 돌아왔을 때 여기부터 읽는다. 내용은 담지 않고 **어디에 문서가 있고 어디까지 됐는지**만 적는다.

- 항목이 끝나면 그 행에 `~~취소선~~` + 상태를 `완료 (커밋)` 으로 — **완료 커밋과 같은 커밋에서**
- 출시 커밋(`📝 x.y.z+n 버전 배포`)에서 취소선 행을 비운다
- 남은 항목이 없으면 `현재 대기 중인 작업 없음` 한 줄. 파일은 지우지 않는다

작업 브랜치 `feat/ralli` (메인 체크아웃, 워크트리 없음).

## Ralli — 다음 출시 (현재 1.1.7 (26))

2026-09-07 상태 점검 기준. 순서 합의: **1 → 5 → 3 → 4 → 7 → 6** (온보딩은 #1·#4 스크린샷이 필요해 맨 뒤). 2·8 은 별도.

| # | 항목 | 상태 | 문서 |
|---|---|---|---|
| 1 | WorkoutShareUI 붙이기 (인스타 스토리 공유) | 플랜 완료 · 구현 대기 | [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-workout-share-button.md) · [Kit 사용법](Packages/YJKit/README.md#workoutshareui-사용법) |
| 5 | String Catalog(xcstrings) 전환 | 플랜 완료 · 구현 대기 | [플랜](Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-string-catalog-migration.md) |
| 3 | 햅틱 (워치 전용) | 플랜 완료 · 구현 대기 | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-match-haptics.md) — 설정 연동은 #8 때 `MatchHaptics.play` 첫 줄에서 |
| 7 | Firebase Crashlytics (iOS + 워치, 익스텐션 제외) | 설계 합의 · 문서 작성 중 | 스펙 `Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md` → YJKit 플랜 `Packages/YJKit/docs/plans/shared/2026/2026-09-07-monitoring-core.md` → Ralli 플랜 `Apps/TennisCounter/docs/plans/shared/2026/2026-09-07-crashlytics-integration.md` (선행: YJKit 플랜) |
| 2 | iOS 통계 UI 리디자인 | **집 맥북 로컬 워크트리 확인** | [Notion: 통계 페이지 기능 개선 (1.1.6 이후)](https://app.notion.com/p/3bacd15e48f180b3a810e95f63854aa6) |
| 4 | 크라운 점수 입력 (워치, 위=나 아래=상대) | 플랜 완료 · 구현 대기 (선행: #3 햅틱) | [플랜](Apps/TennisCounter/docs/plans/watch/2026/2026-09-07-crown-scoring.md) — 온보딩(#6) 항목 하나 파생 |
| 6 | 온보딩 4페이지 (스크린샷 3 + 목록 1, iOS 만) | 스펙·플랜 완료 · 구현 대기 (선행: #1·#4) | [스펙](Apps/TennisCounter/docs/specs/ios/2026/2026-09-07-onboarding-design.md) · [플랜](Apps/TennisCounter/docs/plans/ios/2026/2026-09-07-onboarding.md) — 뼈대(Task 1~3)는 먼저, 스크린샷(Task 4)만 뒤로 |
| 8 | 설정 페이지 + 다른 앱 노출 | 아이디어 단계 | 진입점 메모: 햅틱 on/off(`MatchHaptics.play`), 크래시 수집 on/off(`setCrashlyticsCollectionEnabled`) |

### 집 맥북에서 할 것

- [ ] `git fetch && git checkout feat/ralli`
- [ ] 통계 리디자인 작업물 찾기: `git worktree list` / `git branch -vv` / `git log --oneline --all --not --remotes`
- [ ] 1번 플랜 실행 (Task 1 은 Xcode UI)
- [ ] 5번 플랜 실행 (전부 Xcode UI + 검증)
- [ ] 3번 플랜 실행 → 실기기에서 패턴 확인 (Task 4)
- [ ] 4번 플랜 실행 → 실기기에서 스침·포커스·손목 내림 확인 (Task 2)
- [ ] 7번 — Firebase 콘솔에 프로젝트 "Ralli" + Apple 앱 2개(iOS·워치 번들 ID) 만들고 `GoogleService-Info.plist` 2개 받기
- [ ] 7번 — YJKit 플랜(스파이크 → CI 통과) → Ralli 플랜 순서로. PR 은 Kit / Ralli 따로
- [ ] Meta 개발자 대시보드에서 Facebook App ID 발급 → `MatchShareButton.instagramAppID`
- [ ] 6번 — 뼈대(Task 1~3) 먼저, #1·#4 끝난 뒤 스크린샷 3장 × ko/en (Task 4)
- [ ] Xcode Organizer › Crashes 에서 Ralli 1.1.7 한 번 열어보기 (분석 공유 켠 사용자 표본만 보임)

## YJKit

| 항목 | 상태 | 문서 |
|---|---|---|
| `MonitoringCore` (CrashReporting 프로토콜 + Crashlytics 구현) | 설계 합의 · 문서 작성 중 | 위 Ralli #7 과 같은 스펙·플랜. 골프·하루치 연동은 별도 |

## GolfCounter · HaruchiFit

아직 없음. 하루치 로드맵은 [여기](Apps/HaruchiFit/docs/plans/shared/2026/2026-09-07-haruchi-fit-roadmap.md).

## 규약 참고

- [루트 CLAUDE.md](CLAUDE.md) · [TennisCounter CLAUDE.md](Apps/TennisCounter/CLAUDE.md) · [YJKit README](Packages/YJKit/README.md)
- [Xcode 타깃 규약](docs/specs/2026/2026-09-03-xcode-target-conventions.md) — `INFOPLIST_KEY_*` 배열 불가, HealthKit 권한 문구, `ENABLE_USER_SCRIPT_SANDBOXING`
