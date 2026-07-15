# RalliKit SPM 추출 — Plan 1·2 완료 현황 및 실기기 회귀 체크리스트

## 작업일: 2026-07-13 ~ 2026-07-16

> Ralli(테니스 카운터)의 인프라(HealthKit·WatchConnectivity·SwiftData+CloudKit)를 별도 SPM 패키지
> **RalliKit**으로 추출하는 작업의 진행 현황 정리. 세션을 이어받는 사람/에이전트가 다른 표면(데스크탑 앱 등)에서
> 참조할 수 있도록 지금까지 결정·완료·잔여 작업을 기록한다.
>
> 원본 설계: [[../ideas/workout-kit-spm-feasibility.md]] (타당성 검토, 상태: 설계 확정)
> Plan 1: `docs/superpowers/plans/2026-07-13-ralli-kit-workout-core.md`
> Plan 2: `docs/superpowers/plans/2026-07-14-ralli-kit-connectivity-core.md`

---

## 레포 구조

- **ralli-kit** (신규): `~/Workspace/Projects/ralli-kit`, 원격 `git@github.com:qlrogo91lp/ralli-kit.git` (private).
  현재 `main` 브랜치, 로컬 커밋 즉시 푸시하는 관례로 진행 중.
- **tennis-counter**: 기존 레포. RalliKit은 **로컬 패키지 참조**로 연결돼 있음 (Xcode Add Local Package,
  `project.pbxproj`에 `XCLocalSwiftPackageReference "../ralli-kit"`). **원격 참조로 아직 전환 안 함** —
  릴리즈 전 필수 전환 작업 (아래 "릴리즈 전 체크리스트" 참조).

## RalliKit 패키지 현재 구성

| Product | 내용 | 상태 |
|---|---|---|
| `WorkoutCore` | HealthKit 워크아웃 세션(`WorkoutSessionService`), 종목 설정 주입(`WorkoutConfiguration`), 결과(`WorkoutResult`) | ✅ 완료 (Plan 1) |
| `ConnectivityCore` | 워치↔폰 전송(`ConnectivityService`), 메시지 프로토콜(`ConnectivityMessage`), 전송경로(`Delivery`), 라우팅(`MessageRouter`) | ✅ 완료 (Plan 2) |
| `PersistenceCore` | SwiftData + CloudKit 컨테이너/서비스 | ⬜ 미착수 (Plan 3 — 아직 계획서도 없음) |

## Plan 1 — WorkoutCore (완료, PR #16 머지됨)

- `Shared/Services/HealthKitService.swift`(싱글톤) → RalliKit `WorkoutSessionService`(DI, `WorkoutConfiguration` 주입)로 추출.
- 테니스 Watch 앱만 소비 (iOS는 HealthKit 직접 측정 안 함).
- 실행 중 발견한 계획 외 이슈: `#Preview`가 DEBUG 전용 API를 참조해 **Watch Release 빌드(아카이브)가 실패** — 최종 리뷰가 실제 Release 빌드로 실증, `#if DEBUG` 래핑으로 수정. → **이후 모든 플랜은 스왑/마이그레이션 태스크에 Release 빌드 검증을 필수로 포함**하도록 교훈 반영.
- 머지 커밋: tennis-counter `6412a36` (PR #16, 일반 머지).

## Plan 2 — ConnectivityCore (완료, PR #17 머지됨)

- `Shared/Services/WatchConnectivityService.swift`(전송·폴백·콜드런치·staleness, 413줄) → RalliKit `ConnectivityCore`로 추출.
- 메시지 구조체(`SessionStartMessage`, `ScoreState`, `MatchEndMessage`, `MatchSaveResultMessage` 등)는 앱에 잔류(`Shared/Services/ConnectivityMessages.swift`), `ConnectivityMessage` 프로토콜만 채택. 신규 타입 3종(`MatchSaveMessage`/`WorkoutEndMessage`/`MatchResetMessage`) 추가.
- 앱 레이어 `MatchConnectivity`(`Shared/Services/MatchConnectivity.swift`)가 코어의 1회성 핸들러 배달을 기존 sticky `@Published received*` 패턴으로 복원 — View/VM 마이그레이션은 이름 치환 수준(`WatchConnectivityService.shared` → `MatchConnectivity.shared`).
- **의도된 동작 변경 5가지** (전부 검증·문서화됨):
  1. 모든 발신에 `type`/`sentAt` 자동 스탬프 (구버전 앱과 와이어 호환 유지 — additive)
  2. workoutEnd 60초 stale 필터: 앱 하드코딩 → 코어 `onReceive(maxAge:)` 선언
  3. sessionStart 6시간 staleness 필터: 콜드런치 한정 → 모든 수신 경로로 일반화
  4. sticky `@Published` 구조 → 코어 1회성 핸들러 + 앱 래퍼가 sticky 복원
  5. (사후 발견) malformed 페이로드: 구버전은 `nil` 발행(대기 값 삭제 위험) → 신버전은 드롭(더 안전) — 도달 불가 경로, 의도적 개선으로 수용
- 최종 리뷰에서 하드닝 3건 추가: `dispatchPrecondition(.onQueue(.main))`(등록 시점 오용 방지), README 단일 인스턴스 경고, `MatchConnectivity.init` private화(WCSession delegate 탈취 방지).
- 머지 커밋: tennis-counter `5a860db` (PR #17, 일반 머지).

## 실행 방법 메모 (재사용 가능한 교훈)

- 실행 방식: `superpowers:subagent-driven-development` (태스크별 서브에이전트 + 리뷰 + 최종 전체 브랜치 리뷰).
- watchOS 시뮬레이터: `name=Apple Watch Series 11 (46mm)` **매칭 실패** — 항상 `id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1` 사용.
- 각 Plan에서 신규/변경 타겟은 **Debug + Release 둘 다** 빌드 검증 (Plan 1 교훈).
- Xcode GUI 필요 지점(로컬 패키지 product를 타겟 Frameworks에 추가)은 항상 사용자가 직접 수행 — `project.pbxproj` 자동 편집 도구 사용 금지 (`PBXFileSystemSynchronizedRootGroup` 프로젝트라 파일 추가/삭제만 자동, 패키지 의존성 추가는 수동).

---

## ⚠️ 남은 작업 — 실기기 2대 회귀 (릴리즈 전 필수, 브랜치 머지 게이트는 아님)

Plan 1·2 최종 리뷰 판단: 두 Plan 모두 **머지 자체는 안전**(와이어 포맷 하위 호환, 롤백 단위 명확)하지만, **시뮬레이터로는 재현 불가능한 버그**(콜드런치, WCSession 큐잉, HealthKit 워크아웃 세션)가 있어 **TestFlight/App Store 릴리즈 전에 실기기 2대(iPhone + Apple Watch)로 반드시 확인**해야 한다. Plan 3(PersistenceCore) 작업까지 마친 뒤 한 번에 모아서 진행해도 무방 — 아래 체크리스트를 그때 함께 수행한다.

### Plan 1 확인 (HealthKit/WorkoutCore)
- [ ] 워치에서 운동 시작 → 심박수·칼로리 실시간 표기
- [ ] 운동 일시정지/재개 → 타이머·수치 정상 동작
- [ ] 운동 종료 → `WorkoutResult`(시간·칼로리·평균심박) 정상 산출

### Plan 2 확인 (ConnectivityCore) — 각 항목이 과거 버그 픽스 하나씩을 회귀 검증
- [ ] **실시간 미러링**: 워치에서 운동+매치 시작 → 폰이 자동으로 매치 화면 진입(sessionStart), 워치 점수 입력이 폰에 즉시 반영
- [ ] **큐잉 폴백**: 폰을 잠그거나 멀리 둔 상태(미도달)에서 워치 점수 진행 → 폰 복귀 시 최신 점수 반영
- [ ] **저장 왕복**: 워치에서 경기 종료 → 저장 버튼 → 폰 히스토리에 기록 + 워치에 저장 완료 표시
- [ ] **workoutEnd stale 필터**: 워치 운동 종료 → 폰도 세션 종료. 이후 폰 앱 종료했다가 61초+ 뒤 재실행 → 종료 신호가 다시 적용되지 않음
- [ ] **콜드런치 채택**: 폰에서 매치 진행 중 워치 앱 강제 종료 → 워치 앱 재실행 → 진행 중 세션 자동 재진입
- [ ] **matchReset**: 드라이버 쪽 뒤로가기 → 미러가 모드 선택으로 복귀
- [ ] **주변부**: Complication 점수 표시, iOS Live Activity 갱신 정상

문제 발견 시: 증상 기록 후 `superpowers:systematic-debugging`으로 진입. 롤백 단위는 각 Plan의 스왑 커밋(Plan 1: `3b4f027`/`a4cb39c`, Plan 2: `dedc862`/`1cfd30a`).

## 릴리즈 전 체크리스트 (TestFlight/App Store 제출 전)

1. 위 실기기 회귀 전부 통과
2. **테니스 프로젝트의 RalliKit 참조를 로컬 → 원격으로 전환** (`branch: "main"` 또는 semver 태그) — 지금은 로컬 참조라 "어느 시점 ralli-kit 코드가 들어갔는지" 기록이 없음. 전환 후 로컬 오버라이드는 반드시 제거 (남기면 태그를 올려도 Xcode가 조용히 무시함).
3. Defer된 하이지니 항목 처리 여부 판단 (아래 참조 — 필수는 아님)

## Defer된 하이지니 항목 (후속 커밋 후보, Plan 3 착수 전 일괄 처리 권장)

- `WorkoutSessionService.timerPausedAt` — write-only 데드코드 (원본 유래)
- `WorkoutConfiguration`/`WorkoutResult`에 `Sendable`/`Equatable` 부여
- `MessageRouter`의 `maxAge` 경계값(`now - sentAt == maxAge`) 테스트 추가
- `ConnectivityService.route()`의 `sentAt as? Double` 캐스트 — Int 스탬프 발신자 대비 노트 (현재는 도달 불가 경로)
- 서비스에 `deinit { timer?.invalidate() }` 추가 검토

## 다음 단계

**Plan 3: PersistenceCore** (SwiftData + CloudKit 컨테이너/서비스 추출) — 아직 계획서 작성 전. 착수 시 `docs/superpowers/plans/`에 신규 파일로 작성 예정. iOS 타겟에만 신규 링크 필요(워치는 로컬 저장소 없음).
