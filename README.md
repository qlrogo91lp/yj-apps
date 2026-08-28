# yj-apps

iOS + watchOS 앱 모노레포. 공용 인프라는 `Packages/YJKit`으로 두고 앱이 이를 로컬 SPM 패키지로 참조한다.

```
yj-apps/
├─ Packages/YJKit/          공용 라이브러리 (WorkoutCore / WorkoutUI / ConnectivityCore / PersistenceCore)
├─ Apps/GolfCounter/        GolfCounter — iOS + Watch + Complication
├─ Apps/TennisCounter/      TennisCounter(Ralli) — iOS + Watch + Complication + LiveActivity
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
| 6~7 | 최종 검증 + 마무리 | ⬜ |

### 다음에 할 일 — 6단계 최종 검증

클린 빌드(DerivedData 삭제 후) · 전 타깃 테스트 · 시뮬레이터에서 워치↔iOS 연동 확인.
이후 7단계에서 기존 3개 레포(golf_counter / tennis_counter / ralli-kit)를 archive 한다.

---

## 빌드

**최상위 `YJApps.xcworkspace` 하나만 연다.** 앱별 `.xcodeproj`를 따로 열 필요가 없다.

공유 스킴 7개: `GolfCounter` / `GolfCounter Watch App` / `GolfComplicationExtension` /
`TennisCounter` / `TennisCounter Watch App` / `RalliComplicationExtension` /
`TennisLiveActivityExtension`

```bash
# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# watchOS — 이름 대신 UDID로 지정할 것 (아래 참고)
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=$(xcrun simctl list devices available -j \
    | python3 -c 'import json,sys;print(next(d["udid"] for v in json.load(sys.stdin)["devices"].values() for d in v if "Apple Watch" in d["name"]))')" test

# 패키지 단독 (swift build 는 동작하지 않는다 — 아래 참고)
cd Packages/YJKit
xcodebuild -scheme YJKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> **워치 시뮬레이터를 이름으로 지정하면 실패한다.** `Apple Watch Series 11 (46mm)` 같은 이름이
> OS 26.4·26.5 두 기기와 겹쳐 매칭되지 않는다. `-destination "id=<UDID>"`를 쓴다.

> `swift build` / `swift test`는 이 패키지에서 실패한다. `Package.swift`가 macOS 플랫폼을
> 선언하지 않아 호스트 빌드 시 SwiftData API가 macOS 14 미만으로 판정되기 때문이다.
> 검증에는 반드시 iOS 시뮬레이터 destination을 쓴다.

## 문서

- [모노레포 전환 설계](docs/superpowers/specs/2026-08-27-monorepo-migration-design.md) — 실행 스펙, 단계별 완료 조건
- [CI 파이프라인 설계](docs/superpowers/specs/2026-08-27-ci-pipeline-design.md) — 전환 후 독립 진행
- [코드 스타일 툴링](docs/superpowers/specs/2026-08-27-code-style-tooling-design.md) — 개념 정리 + 미결 논의
