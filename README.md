# yj-apps

[![CI](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml/badge.svg)](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml)

iOS + watchOS 앱 모노레포. 공용 인프라는 `Packages/YJKit`으로 두고 앱이 이를 로컬 SPM 패키지로 참조한다.

```
yj-apps/
├─ Packages/YJKit/          공용 라이브러리 (WorkoutCore / WorkoutUI / WorkoutShareUI / ConnectivityCore / PersistenceCore / MonitoringCore)
├─ Apps/GolfCounter/        GolfCounter — iOS + Watch + Complication
├─ Apps/TennisCounter/      Ralli(TennisCounter) — iOS + Watch + Complication + LiveActivity
├─ Apps/HaruchiFit/         하루치 핏(HaruchiFit) — iOS + Watch + Complication
├─ .github/workflows/       CI — 변경된 앱만 빌드·테스트
└─ docs/                   모노레포 공통 문서 (specs/ideas/plans/logs)
```

---

## 모노레포 전환

세 개의 개별 레포(`golf_counter`, `tennis_counter`, `ralli-kit`)를 이 레포로 통합했다. 히스토리는 경로를
다시 써서 가져왔으므로 `git log Apps/GolfCounter/` 처럼 앱별 이력을 그대로 볼 수 있다.
단계별 기록은 [모노레포 전환 설계](docs/specs/2026/2026-08-27-monorepo-migration-design.md)에 있다.

---

## 명령

```bash
make lint            # 앱별 swiftlint (검사만)
make format          # 앱별 swiftformat --lint (검사만)
make fix             # 앱별 swiftformat + swiftlint --fix (실제로 고침)
make kit-test        # Packages/YJKit 단독 테스트 (iOS 시뮬레이터)
make dd-prune        # 고아 DerivedData 목록 (검사만)
make dd-prune-apply  # 고아 DerivedData 삭제 (실제로 지움)
```

> `make dd-prune` 은 **가리키던 워크트리가 사라진 DerivedData** 를 찾는다. DerivedData 폴더 이름은
> 워크스페이스 **경로 해시**라 워크트리를 지워도 산출물은 남아 수백 MB 를 차지한다. 워크트리를
> 제거할 때 같이 돌린다. 실제 삭제는 `dd-prune-apply` 에서만 일어난다.

## 빌드

**최상위 `YJApps.xcworkspace` 하나만 연다.** 앱별 `.xcodeproj`를 따로 열 필요가 없다.

공유 스킴 11개:

| 앱 | 스킴 |
|---|---|
| GolfCounter | `GolfCounter` / `GolfCounter Watch App` / `GolfComplicationExtension` |
| Ralli | `TennisCounter` / `TennisCounter Watch App` / `RalliComplicationExtension` / `TennisLiveActivityExtension` |
| 하루치 핏 | `HaruchiFit` / `HaruchiFit Watch App` / `HaruchiComplicationExtension` / `HaruchiFitWatchTests` |

```bash
# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination "id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')" test

# watchOS — 이름 대신 UDID로 지정할 것 (아래 참고)
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')" \
  -only-testing:GolfCounterWatchTests test

# 하루치 핏 워치만 워치 테스트 전용 스킴을 갖는다 (-only-testing 불필요)
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" \
  -destination "id=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')" test

# 패키지 단독 (swift build 는 동작하지 않는다 — 아래 참고)
make kit-test KIT_DESTINATION="id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')"
```

> **워치 테스트는 앱마다 거는 방식이 다르다.** GolfCounter·Ralli 의 워치 스킴에는 iOS 테스트 타깃까지
> 들어 있어 `-only-testing` 으로 워치 테스트만 골라야 한다. 하루치 핏만 워치 전용 스킴
> (`HaruchiFitWatchTests`)이 따로 있다.

> **워치 시뮬레이터를 이름으로 지정하면 실패한다.** `Apple Watch Series 11 (46mm)` 같은 이름이
> OS 26.4·26.5 두 기기와 겹쳐 매칭되지 않는다. `-destination "id=<UDID>"`를 쓴다.
> `.github/scripts/pick-simulator.sh <iOS|watchOS> <이름 정규식>`이 최신 런타임에서 기기를
> 하나 골라 UDID를 출력한다. CI와 로컬이 같은 스크립트를 쓴다.

> `swift build` / `swift test`는 이 패키지에서 실패한다. `Package.swift`가 macOS 플랫폼을
> 선언하지 않아 호스트 빌드 시 SwiftData API가 macOS 14 미만으로 판정되기 때문이다.
> 검증에는 반드시 iOS 시뮬레이터 destination을 쓴다.

## CI

PR을 열면 **변경된 앱만** 빌드·테스트한다. `Packages/YJKit`이 바뀌면 코어 변경의 파급을 잡기 위해
전 앱을 돌린다. `docs/`나 `README.md`만 바뀌면 아무 job도 돌지 않는다.

러너는 `macos-26`(Xcode 26.6 — 로컬과 동일)이고, 린트 도구는 로컬과 같은 버전으로 고정한다.
서명은 하지 않는다(`CODE_SIGNING_ALLOWED=NO`).

## 문서

- [모노레포 전환 설계](docs/specs/2026/2026-08-27-monorepo-migration-design.md) — 실행 스펙, 단계별 완료 조건
- [CI 파이프라인 설계](docs/specs/2026/2026-08-27-ci-pipeline-design.md) — 워크플로 구성, 러너·도구 버전 고정 근거
- [코드 스타일 툴링](docs/specs/2026/2026-08-27-code-style-tooling-design.md) — 개념 정리 + 미결 논의
