# CLAUDE.md

yj-apps 모노레포 공통 규약. 앱별 아키텍처·명령은 `Apps/<앱>/CLAUDE.md` 를 본다.

## 저장소 구조

```
yj-apps/
├─ Packages/YJKit/       공용 인프라 패키지 (WorkoutCore / WorkoutUI / ConnectivityCore / PersistenceCore)
├─ Apps/GolfCounter/     GolfCounter — iOS + Watch + Complication
├─ Apps/TennisCounter/   Ralli(TennisCounter) — iOS + Watch + Complication + LiveActivity
├─ YJApps.xcworkspace    이것 하나만 연다. 앱별 .xcodeproj 를 따로 열지 않는다
├─ Makefile              앱 순회 lint / format / fix
├─ .swiftlint.yml        공통 규칙 (앱별 설정이 parent_config 로 상속)
└─ docs/superpowers/specs/
```

## 작업 방식

**구현은 승인된 플랜에서 출발한다. 플랜 없이 코드를 건드리지 않는다.**

기본 흐름: 분석·브레인스토밍 → 플랜 제시 → **사용자 승인** → 구현 → 검증 → 커밋

- "분석해줘", "구조 파악해줘", "어떻게 생각해?", "이거 왜 이래?"는 전부 **분석 요청이지
  구현 요청이 아니다.** 분석 결과와 제안까지만 내놓고 멈춘다.
- 스코프나 방식을 되묻고 답을 받은 것은 **질문에 대한 답일 뿐 구현 승인이 아니다.**
  받은 답을 반영한 플랜을 다시 제시하고, 거기서 승인을 한 번 더 받는다.
- 사용자가 구현을 지시했더라도, 파일을 새로 만들거나 지우거나 두 개 이상을 고치는
  변경이면 먼저 플랜(바꿀 파일 목록 + 각 파일에서 할 일)을 보이고 승인을 받는다.
- 브랜치 생성·커밋·PR도 승인 대상이다. 플랜에 포함해서 함께 확인받는다.

물어보지 않고 바로 해도 되는 것 — 읽기·검색, 빌드·테스트·lint 실행, 한 곳짜리
오타나 컴파일 에러 수정, 직전 턴에 승인받은 플랜의 실행.

플랜은 **바꿀 파일 단위로** 적는다. 규모가 크면 `docs/superpowers/plans/`에 문서로
남기고, 작으면 대화 안에서 제시해도 된다.

## 공통 명령

```bash
make lint      # 앱별 swiftlint (검사만)
make format    # 앱별 swiftformat --lint (검사만)
make fix       # 앱별 swiftformat + swiftlint --fix (실제로 고침)
make kit-test  # Packages/YJKit 단독 테스트
```

빌드·테스트는 **워크스페이스 기준**이다. `-project` 가 아니라 `-workspace` 를 쓴다.

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "<스킴>" -destination "<대상>" build   # 또는 test
```

공유 스킴 7개 — `GolfCounter` / `GolfCounter Watch App` / `GolfComplicationExtension` /
`TennisCounter` / `TennisCounter Watch App` / `RalliComplicationExtension` / `TennisLiveActivityExtension`

> **워치 시뮬레이터는 이름 대신 UDID로 지정한다.** `name=Apple Watch Series 11 (46mm)` 는 OS 26.4·26.5
> 두 기기와 겹쳐 매칭에 실패한다. `xcrun simctl list devices available` 로 UDID를 얻어
> `-destination "id=<UDID>"` 를 쓴다.

## Packages/YJKit

인프라 계층은 로컬 SPM 패키지다. 두 앱이 `XCLocalSwiftPackageReference "../../Packages/YJKit"` 로
참조하므로 **패키지 소스를 고치면 재빌드 시 즉시 반영된다.** 푸시도, 형제 폴더 체크아웃도, local
override 붙였다 떼는 절차도 필요 없다.

프로덕트 구성과 사용법은 `Packages/YJKit/README.md` 를 본다.
앱 코드는 패키지 이름(`YJKit`)이 아니라 **프로덕트 이름**(`import WorkoutCore` 등)으로 가져다 쓴다.

| 프로젝트 | 타깃 | 링크된 프로덕트 |
|---|---|---|
| GolfCounter | `GolfCounter` | ConnectivityCore, PersistenceCore |
| GolfCounter | `GolfCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| TennisCounter | `TennisCounter` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI |
| TennisCounter | `TennisCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |

**코어는 도메인을 모른다.** 종목별 규칙·메시지·저장 정책은 앱 레이어가 소유한다.

**워크아웃 동작 계약** (3개 앱이 같은 규칙을 지켜야 숫자 의미가 갈리지 않는다)

- 화면에 넘기는 칼로리는 **워크아웃 누적값**. 경기 구간 값이 필요하면 저장 시점에 `종료값 - 시작값`으로 계산한다.
- 경과시간은 **워치가 단일 소스**. 폰은 `WorkoutAnchor.interpolatedElapsed(...)`로 보간하고 자체 타이머로 세지 않는다.
- pause는 **폰→워치 명령**. 폰은 `WorkoutPauseMessage`를 보내고 `isPaused`는 워치 앵커로만 갱신한다 (낙관적 토글 금지). 워치 미연결이면 `isPauseAvailable: false`.

## Xcode 프로젝트 파일

이 프로젝트는 **Xcode 16의 `PBXFileSystemSynchronizedRootGroup`** 방식을 사용한다.

- Swift 파일을 생성하거나 삭제하면 Xcode가 폴더를 자동 스캔해서 빌드 대상에 포함/제외한다.
- `.xcodeproj/project.pbxproj`를 직접 수정하거나 `xcodeproj` gem 등 프로젝트 파일 편집 도구를 사용할 필요가 없다.
- 파일 이동/생성/삭제는 파일시스템 조작만으로 충분하다.

## Git Workflow

- `main` 직접 push 금지 — 브랜치 + PR, 머지는 항상 일반 merge commit (`gh pr merge <n> --merge --delete-branch`)
- 예외: `docs/superpowers/specs/`·`plans/`의 스펙/플랜 문서는 코드 변경이 없으므로 브랜치+PR 없이 `main`에 직접 커밋·push 가능
- 커밋 메시지는 gitmoji prefix: ✨ feat / 🐛 fix / ♻️ refactor / 🎨 style / 📝 docs / ✅ test / 🔧 chore / 🔥 remove / ⏪ revert

## Docs 공통 규약

- `docs/superpowers/` 아래 `ideas/`(탐색) · `specs/`(확정 설계) · `plans/`(구현 계획) · `logs/`(작업 기록)
- **사용자 검토 전에는 커밋하지 않는다.** 스킬이 커밋을 지시하더라도 마찬가지다.
- 완료된 문서만 커밋한다. 작성 중인 스펙·계획은 커밋하지 않는다.
- 폴더 세부 배치는 앱마다 다르다 — 각 앱의 `CLAUDE.md` 를 본다.
- 모노레포 전환 관련 문서는 루트 `docs/superpowers/specs/` 에 있다.

## 코드 스타일 도구

`swiftlint`(검사만) 와 `swiftformat`(자동 수정) 을 쓴다. 루트 `.swiftlint.yml` 이 공통 규칙을 갖고,
앱별 `.swiftlint.yml` 이 `parent_config` 로 상속한 뒤 고유 규칙만 더한다. 리스트는 병합된다.

`.swiftformat` 은 앱별로만 둔다. 두 앱의 `--swiftversion` 이 다른 상태이며(golf 5.0 / tennis 6.0),
통일 여부는 `docs/superpowers/specs/2026-08-27-code-style-tooling-design.md` 의 미결 논의 항목이다.
