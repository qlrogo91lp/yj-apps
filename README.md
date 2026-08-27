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
| 2 | 패키지 로컬화 | 🔄 **진행 중** |
| 3 | 워크스페이스 + 스킴 공유 | ⬜ |
| 4 | 타깃·스킴 이름 정리 | ⬜ |
| 5 | 툴링 구조화 | ⬜ |
| 6~7 | 최종 검증 + 마무리 | ⬜ |

### 2단계에서 다음에 할 일

`Package.swift`의 이름 변경(`RalliKit` → `YJKit`)은 끝났고 패키지 단독 빌드·테스트도 통과했다.
**남은 것은 두 앱의 Xcode 프로젝트에서 원격 패키지 참조를 로컬 참조로 바꾸는 작업이다.**

앱 하나씩(golf 먼저 권장) 다음 절차로 진행한다.

```
1. Apps/GolfCounter/GolfCounter.xcodeproj 를 Xcode로 연다
2. 프로젝트 선택 → Package Dependencies 탭
     → ralli-kit 원격 참조를 [-] 로 제거          ← 반드시 제거를 먼저
3. File → Add Package Dependencies... → [Add Local...]
     → Packages/YJKit 폴더 선택
4. 각 타깃 → General → Frameworks, Libraries, and Embedded Content
     → 아래 표대로 프로덕트를 다시 연결
5. ⌘B 로 빌드 확인
```

제거를 먼저 하는 이유: 같은 이름의 프로덕트(`WorkoutCore` 등)를 제공하는 패키지가 둘이 되면
Xcode가 어느 쪽을 쓸지 모호해진다.

#### 복원 기준 — 전환 전 프로덕트 연결

| 프로젝트 | 타깃 | 연결된 프로덕트 |
|---|---|---|
| GolfCounter | `GolfCounter` | ConnectivityCore, PersistenceCore |
| GolfCounter | `GolfCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| TennisCounter | `TennisCounter` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI |
| TennisCounter | `TennisCounter Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |

`ComplicationAppExtension`, `TennisLiveActivityExtension`, 테스트 타깃은 패키지 프로덕트를
직접 연결하지 않는다.

#### 완료 조건

- 두 앱의 전 타깃이 빌드된다
- `Packages/YJKit` 소스를 고치면 재빌드 시 **즉시 반영된다** (푸시 없이)
- pbxproj에 `XCRemoteSwiftPackageReference`가 남아있지 않다

---

## 빌드

전환 3단계에서 최상위 `YJApps.xcworkspace`가 생기기 전까지는 앱별 `.xcodeproj`를 직접 연다.

```bash
# 패키지 단독 (swift build 는 동작하지 않는다 — 아래 참고)
cd Packages/YJKit
xcodebuild -scheme YJKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> `swift build` / `swift test`는 이 패키지에서 실패한다. `Package.swift`가 macOS 플랫폼을
> 선언하지 않아 호스트 빌드 시 SwiftData API가 macOS 14 미만으로 판정되기 때문이다.
> 검증에는 반드시 iOS 시뮬레이터 destination을 쓴다.

## 문서

- [모노레포 전환 설계](docs/superpowers/specs/2026-08-27-monorepo-migration-design.md) — 실행 스펙, 단계별 완료 조건
- [CI 파이프라인 설계](docs/superpowers/specs/2026-08-27-ci-pipeline-design.md) — 전환 후 독립 진행
- [코드 스타일 툴링](docs/superpowers/specs/2026-08-27-code-style-tooling-design.md) — 개념 정리 + 미결 논의
