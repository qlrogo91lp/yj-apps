# yj-apps

[![CI](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml/badge.svg)](https://github.com/qlrogo91lp/yj-apps/actions/workflows/ci.yml)

iOS + watchOS 앱 모노레포. 공용 인프라는 `Packages/YJKit`으로 두고 앱이 이를 로컬 SPM 패키지로 참조한다.

```
yj-apps/
├─ Packages/YJKit/          공용 라이브러리 (WorkoutCore / WorkoutUI / ConnectivityCore / PersistenceCore)
├─ Apps/GolfCounter/        GolfCounter — iOS + Watch + Complication
├─ Apps/TennisCounter/      TennisCounter(Ralli) — iOS + Watch + Complication + LiveActivity
├─ .github/workflows/       CI — 변경된 앱만 빌드·테스트
└─ docs/superpowers/specs/  설계 문서
```

---

## ⚠️ 현재 모노레포 전환 진행 중

세 개의 개별 레포(`golf_counter`, `tennis_counter`, `ralli-kit`)를 통합하는 작업이 진행 중이다.
**원본 레포 3개는 아직 그대로 살아있으며 삭제하지 않았다.** 문제가 생기면 원본으로 돌아갈 수 있다.

### 진행 상황

| 단계 | 내용 | 상태 |
|---|---|---|
| 0 | 선행 조건 — 원본 레포 동기화 | ✅ 완료 |
| 1 | 히스토리 이관 (`filter-branch` 경로 재작성 후 병합) | ✅ 완료 |
| 2 | 패키지 로컬화 | ✅ 완료 |
| 3 | 워크스페이스 + 스킴 공유 | ✅ 완료 |
| 4 | 타깃·스킴 이름 정리 | ✅ 완료 |
| 5 | 툴링 구조화 | ✅ 완료 |
| 6 | 최종 검증 | 🔄 자동 검증 완료, 실기 연동 확인은 TestFlight 시점 |
| 7 | 마무리 | 🔄 CI 구축 ✅ / 원본 레포 archive ⬜ |

### 다음에 할 일 — 7단계 마무리

기존 3개 레포(golf_counter / tennis_counter / ralli-kit)를 GitHub에서 archive 한다.
**삭제는 전환 완료 + 릴리즈 1회 통과 후 재판단한다.**

미검증으로 남은 항목: **워치↔iOS 연동 동작.** TestFlight 배포 시 실기기로 확인한다.
CI는 서명 없이 시뮬레이터에서만 돌기 때문에 이 항목을 대신하지 못한다.

---

## 빌드

**최상위 `YJApps.xcworkspace` 하나만 연다.** 앱별 `.xcodeproj`를 따로 열 필요가 없다.

공유 스킴 7개: `GolfCounter` / `GolfCounter Watch App` / `GolfComplicationExtension` /
`TennisCounter` / `TennisCounter Watch App` / `RalliComplicationExtension` /
`TennisLiveActivityExtension`

```bash
# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination "id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')" test

# watchOS — 이름 대신 UDID로 지정할 것 (아래 참고)
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')" test

# 패키지 단독 (swift build 는 동작하지 않는다 — 아래 참고)
make kit-test KIT_DESTINATION="id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')"
```

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

- [모노레포 전환 설계](docs/superpowers/specs/2026-08-27-monorepo-migration-design.md) — 실행 스펙, 단계별 완료 조건
- [CI 파이프라인 설계](docs/superpowers/specs/2026-08-27-ci-pipeline-design.md) — 워크플로 구성, 러너·도구 버전 고정 근거
- [코드 스타일 툴링](docs/superpowers/specs/2026-08-27-code-style-tooling-design.md) — 개념 정리 + 미결 논의
