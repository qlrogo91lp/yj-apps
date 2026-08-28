# 코드 스타일 툴링 — 개념 정리와 미결 논의

작성일: 2026-08-27
상태: **논의 문서 — 결론 없음**
선행 조건: `2026-08-27-monorepo-migration-design.md` 전환 완료

---

이 문서는 두 부분으로 나뉜다.

- **1부 — 레퍼런스**: SwiftFormat과 SwiftLint가 무엇이고 왜 쓰는지. 결정 사항이 아니라 참고용 설명이다.
- **2부 — 미결 논의**: 전환에서 의도적으로 제외한 판단 항목들. 각 항목은 근거 데이터와 선택지만
  기록하고 **결론은 내리지 않는다.** 나중에 하나씩 논의해 결정한다.

전환 문서에서 이 항목들을 분리한 이유는, 전환의 성공 기준이 **"구조만 바뀌고 동작은 그대로"** 이기
때문이다. 코드 내용을 바꾸는 판단이 전환 커밋에 섞이면 문제 발생 시 원인을 가릴 수 없게 된다.

---

# 1부 — 레퍼런스

## 1.1 SwiftFormat — 코드를 자동으로 고쳐 쓰는 도구

**포매터(formatter)** 다. 코드의 **모양**을 규칙에 맞게 **직접 수정한다.**

들여쓰기, 공백, 줄바꿈 위치, import 순서, 불필요한 괄호나 `self.` 제거처럼 **사람이 판단할 필요가
없는 것**을 기계가 통일한다. 목적은 "무엇이 옳은가"를 정하는 것이 아니라 **논쟁을 없애는 것**이다.
팀이든 혼자든, 파일마다 스타일이 다르면 diff를 읽을 때 진짜 변경과 스타일 변경이 섞여 보인다.

```swift
// 실행 전
let x = [ 1,2,3 ]
if (a == b) { return }

// 실행 후
let x = [1, 2, 3]
if a == b { return }
```

설정 파일은 `.swiftformat`이며, 현재 두 앱 모두 `--swiftversion` 한 줄만 들어 있다.

## 1.2 SwiftLint — 코드를 검사만 하는 도구

**린터(linter)** 다. 코드를 **읽고 문제를 지적하지만, 기본적으로 고치지는 않는다.**

포매터가 다루지 않는 **의미 있는 판단**을 다룬다.

- 이름 규칙 — 타입 이름 길이, 변수 이름 최소·최대 길이
- 크기 제한 — 한 줄 길이, 파일 길이, 타입 본문 길이
- **위험한 패턴** — 강제 언래핑(`!`), `filter {}.count` 대신 `count(where:)` 권장 등

핵심 차이는 여기다. SwiftFormat은 "이렇게 쓰든 저렇게 쓰든 결과는 같으니 통일하자"를 다루고,
SwiftLint는 **"이건 나중에 문제가 될 수 있다"** 를 다룬다. 그래서 SwiftLint의 지적은 무조건 고칠
대상이 아니라 **판단할 대상**이다.

실제 예가 `golf_counter/.swiftlint.yml`에 있다.

```yaml
opt_in_rules:
  # maxHole(String)을 Int로 강제 언래핑하는 기존 패턴을 드러내기 위해 켜둔다.
  # warning 레벨이라 make lint는 통과하며, 모델을 Int/HoleType으로 바꿀 때 함께 사라진다.
  - force_unwrapping
```

규칙을 끄는 대신 **일부러 켜서 기술 부채를 눈에 보이게 유지하고 있다.** 이것이 린터의 용도다.

설정 파일은 `.swiftlint.yml`이다.

## 1.3 역할 분담 요약

| | SwiftFormat | SwiftLint |
|---|---|---|
| 하는 일 | 코드를 **고친다** | 코드를 **검사한다** |
| 다루는 것 | 모양 (공백·줄바꿈·순서) | 판단 (이름·크기·위험 패턴) |
| 결과 | 항상 통일된 형태 | 경고/에러 목록 |
| 지적에 대한 대응 | 그냥 실행하면 해결 | **읽고 판단해야 함** |
| 설정 파일 | `.swiftformat` | `.swiftlint.yml` |

겹치는 영역이 조금 있다. SwiftLint에도 `--fix`로 자동 수정되는 규칙이 일부 있고, SwiftFormat에도
`preferCountWhere`처럼 판단에 가까운 규칙이 있다. 겹칠 때는 **한쪽에서만 켜서** 두 도구가 서로의
결과를 되돌리지 않게 한다.

## 1.4 Makefile 명령어

두 앱의 `Makefile`은 현재 완전히 동일하다.

```make
lint:                          # 검사만. 문제를 보고한다
	swiftlint

format:                        # 검사만. 포맷이 어긋난 파일을 보고한다
	swiftformat --lint .

fix:                           # 실제로 고친다
	swiftformat .
	swiftlint --fix
```

이름이 헷갈리기 쉽다. **`format`은 고치지 않고 검사만 한다.** 실제로 고치는 것은 `fix`다.
`--lint` 플래그가 "수정하지 말고 보고만" 이라는 뜻이다.

CI에서는 `lint`와 `format`을 쓴다 (검사만 하고 코드를 바꾸지 않아야 하므로).

---

# 2부 — 미결 논의

각 항목은 **근거 데이터 + 선택지**만 기록한다. 결론은 나중에 논의해 정한다.

## 논의 1 — SwiftFormat `--swiftversion` 5.0 vs 6.0

### 현황

```
golf_counter/.swiftformat    --swiftversion 5.0
tennis_counter/.swiftformat  --swiftversion 6.0
```

두 앱이 서로 다르다. 그런데 **실제 컴파일러 설정은 양쪽 모두 `SWIFT_VERSION = 5.0`** 이다.
즉 tennis 쪽 설정이 실제와 어긋나 있다.

### 실측 데이터 (2026-08-27, SwiftFormat 0.61.1)

동일한 코드를 두 버전으로 lint한 결과:

```
tennis:  5.0 → 1/73 파일 지적     6.0 → 1/73 파일 지적     (판정 완전히 동일)
golf:    5.0 → 1/64 파일 지적     6.0 → 3/64 파일 지적     ← 차이 발생
```

golf에서 6.0일 때만 걸리는 항목:

```
Shared/Models/ScoreAggregate.swift:20        (preferCountWhere)
Shared/Models/ScoreAggregate.swift:21        (preferCountWhere, trailingSpace, blankLinesAtEndOfScope)
iOSApp/Features/Stats/StatsViewModel.swift:74  (preferCountWhere)
```

### 쟁점

`preferCountWhere`는 `filter { ... }.count` → `count(where:)` 로 **코드를 다시 쓰는 규칙**이다.
`count(where:)`가 Swift 6.0 표준 라이브러리 추가분이라 이 규칙이 6.0에서만 켜진다.

이것은 공백 정리가 아니라 **로직 표현의 변경**, 즉 포매팅이 아니라 리팩터링에 가깝다. 전환 문서에서
이 결정을 뺀 이유가 여기 있다.

### 선택지

| | 내용 | 영향 |
|---|---|---|
| A | 5.0으로 통일 | 코드 변경 0. 실제 `SWIFT_VERSION = 5.0`과 일치 |
| B | 6.0으로 통일 | golf 코드 3곳 재작성. 언어 모드는 여전히 5 — **설정과 실제가 다시 어긋난다** |
| C | 현상 유지 | 앱마다 다른 상태가 지속. 새 앱 추가 시 기준이 없음 |

**논의 2와 함께 결정해야 한다.** 포매터 버전은 언어 모드를 따라가는 것이 원칙이다.

## 논의 2 — 언어 모드를 Swift 6로 올릴 것인가

### 현황

```
두 앱 pbxproj      SWIFT_VERSION = 5.0
YJKit Package.swift  swiftLanguageMode(.v5)   (전 타깃)
로컬 툴체인          Swift 6.3.3 / Xcode 26.6
```

툴체인은 이미 Swift 6이지만 **언어 모드는 전부 v5**로 고정되어 있다. 즉 Swift 6의 엄격한 동시성
검사(strict concurrency)를 받지 않고 있다.

### 쟁점

Swift 6 언어 모드로 올리면 `Sendable`, actor 격리 위반이 **경고가 아니라 컴파일 에러**가 된다.
이 앱들은 워치↔iOS 통신, HealthKit 워크아웃 세션, SwiftData 등 동시성이 실제로 얽히는 코드가 있어
전환 비용이 작지 않을 수 있다.

반면 언제까지 v5에 머무를 수는 없다. 미루면 부채가 쌓인다.

### 선택지

| | 내용 |
|---|---|
| A | 계속 v5 유지. 이 문서를 재검토 시점으로 삼음 |
| B | `YJKit`부터 v6로 전환 (범위가 좁고 순수 로직 위주) → 이후 앱으로 확대 |
| C | 전 타깃 동시 전환 |

B가 점진적이지만, 실제 공수는 코드를 열어봐야 안다. **별도 조사가 필요하다.**

## 논의 3 — golf의 `force_unwrapping` opt-in을 언제 걷을 것인가

### 현황

`golf_counter/.swiftlint.yml`에 의도적으로 켜져 있으며, 주석에 조건이 명시되어 있다.

> "maxHole(String)을 Int로 강제 언래핑하는 기존 패턴을 드러내기 위해 켜둔다.
> warning 레벨이라 make lint는 통과하며, **모델을 Int/HoleType으로 바꿀 때 함께 사라진다.**"

### 쟁점

이것은 스타일 설정이 아니라 **추적 중인 기술 부채**다. 규칙을 끄는 것이 해결이 아니라, 모델의
`maxHole` 타입을 `String`에서 `Int`나 `HoleType`으로 바꾸는 것이 해결이다.

### 확인 필요

- 실제 위반 건수와 위치
- 모델 타입 변경 시 SwiftData 스키마 마이그레이션이 필요한지 (**CloudKit 사용 중이므로 주의**)

## 논의 4 — 기존 SwiftFormat 실패 (앱당 1건)

### 현황

전환과 무관하게 **두 레포 모두 현재 `make format`이 실패한다.** 걸리는 규칙은 서로 다르다.

```
tennis: iOSApp/Features/History/Components/MatchDetailSheet.swift:16
          (trailingCommas)
golf:   WatchApp/Features/Round/Counting/CountingSizing.swift:11
          (blankLinesAtStartOfScope)
```

둘 다 순수 포매팅 규칙이며 로직과 무관하다. 논의 1의 `preferCountWhere`와 달리 판단이 필요 없다.

### 쟁점

`make fix` 한 번이면 해결되지만, 그 커밋을 언제 어디에 넣을지가 문제다. 전환 커밋에 섞으면 소스
diff 0 원칙이 깨진다.

### 선택지

- 전환 완료 직후 **독립 커밋**으로 정리
- 논의 1(swiftversion 통일)과 함께 한 번에 재포맷

## 논의 5 — 배포 타깃 `26.4` 혼재 → **해소됨, 조치 불필요**

### 조사 결과 (2026-08-28)

`26.4`는 **테스트 타깃에만** 설정되어 있었다.

```
GolfCounterTests / RalliTests            IPHONEOS_DEPLOYMENT_TARGET = 26.4
GolfCounterWatchTests / RalliWatchTests  WATCHOS_DEPLOYMENT_TARGET  = 26.4
```

Xcode가 테스트 타깃을 만들 때 넣은 기본값이며, **배포되는 앱·확장은 전부 17.0 / 10.0**이다.
사용자 지원 OS 범위에 아무 영향이 없다. 테스트 타깃과 함께 남아 있는 `MARKETING_VERSION = 1.0`도
같은 성격이다.

**조치 없이 그대로 둔다.**

## 논의 7 — 지원 대상 기기(Supported Destinations) 정리

### 현황 (2026-08-28)

```
GolfCounter                  SDK=iphoneos  기기=iPhone
GolfCounter Watch App        SDK=watchos   기기=Apple Watch
ComplicationAppExtension ×2  SDK=watchos   기기=Apple Watch
TennisCounter                SDK=iphoneos  기기=iPhone
TennisCounter Watch App      SDK=watchos   기기=Apple Watch
TennisLiveActivityExtension  SDK=iphoneos  기기=iPhone+iPad   ← 유일한 불일치
테스트 타깃 4개                             기기=iPhone+iPad   (배포 무관)

SUPPORTS_MACCATALYST                  = NO   (이미 꺼짐)
SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO   (이미 꺼짐)
SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD  = 미설정
```

Mac 관련은 이미 정리되어 있고 앱 타깃은 iPhone 전용이다. 정리할 것이 거의 없다.

### 쟁점

**`TennisLiveActivityExtension`만 iPhone+iPad다.** 호스트 앱 `TennisCounter`는 iPhone 전용이고
Live Activity는 iPhone에서만 동작하므로 iPad 지원은 무의미하다. 다만 **배포되는 확장**이라 변경 시
검증이 필요하다.

**Vision Pro 노출 여부는 빌드 설정만으로 판단할 수 없다.**
`SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD`가 명시되어 있지 않고, visionOS 스토어 가용성은
App Store Connect 설정에서도 관리된다. 실제 노출 상태는 App Store Connect에서 확인해야 한다.

### 선택지

- A: `TennisLiveActivityExtension`을 iPhone 전용으로 맞춤 (호스트 앱과 일치)
- B: 현상 유지 — 동작에 문제가 없고 iPad에 설치될 일도 없음
- 테스트 타깃 4개는 배포 무관이므로 어느 쪽이든 무해

### 확인 필요

- App Store Connect에서 두 앱의 Vision Pro 가용성 상태

## 논의 6 — 새 앱을 위한 툴링 템플릿

### 현황

전환 후 구조에서는 루트 `.swiftlint.yml`을 앱별 설정이 `parent_config`로 상속한다.

```
yj-apps/.swiftlint.yml                     공통 규칙
  ├─ Apps/GolfCounter/.swiftlint.yml       parent_config + included + force_unwrapping
  └─ Apps/TennisCounter/.swiftlint.yml     parent_config + included + type_name 예외
```

### 쟁점

앱이 3~5개가 되면 "새 앱을 추가할 때 무엇을 복사해야 하는가"가 반복 질문이 된다. 템플릿이나 스캐폴딩
스크립트가 필요한 시점이 온다.

### 확인 필요

- 4번째 앱 추가 시점에 재검토
- 루트 공통 규칙에 무엇까지 올릴지는 앱이 늘어난 뒤에 판단하는 편이 정확하다

---

## 부록 — 측정 재현 방법

논의 1의 실측을 재현하려면:

```bash
printf '' > /tmp/empty.swiftformat

# 설정 파일 영향을 배제하고 버전만 비교
swiftformat --lint --config /tmp/empty.swiftformat --swiftversion 5.0 \
  Apps/GolfCounter/iOSApp Apps/GolfCounter/WatchApp Apps/GolfCounter/Shared

swiftformat --lint --config /tmp/empty.swiftformat --swiftversion 6.0 \
  Apps/GolfCounter/iOSApp Apps/GolfCounter/WatchApp Apps/GolfCounter/Shared
```

측정 환경: SwiftFormat 0.61.1, SwiftLint 0.64.1, Xcode 26.6, Swift 6.3.3
