# 로컬라이즈 (ko/en) 설계

작성일: 2026-08-17
참조 스펙: `2026-07-31-golfcounter-rebuild-design.md` §10 — **이 문서가 §10의 파일 형식 결정을 뒤집는다** (§2 참조)
참조 프로젝트: `../tennis-counter` (키 스타일·파일 형식의 선례)
대응 plan: `2026-08-17-common-localization.md` (미작성)

## 1. 목표와 범위

한국어로 하드코딩된 세 타깃의 사용자 노출 문자열을 한국어·영어 두 언어로 지원한다.

### 포함

- iOS·워치·컴플리케이션 세 타깃의 사용자 노출 문자열 전부
- HealthKit 권한 문구 2개 (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`)

### 범위 밖

- **앱 이름 교체** — 로드맵 ⑦은 "로컬라이즈 + 이름 교체"로 묶여 있었으나 분리한다. 표시명 최종안이 확정되지 않았고(리빌드 스펙 §0이 "GolfCounter with Watch"를 유력안으로만 두었다), 이름 결정은 제품 판단이라 문자열 번역과 성격이 다르다. **`CFBundleDisplayName = GolfCounter`는 그대로 둔다** — "GolfCounter"는 브랜드명이라 ko/en이 같으므로 이 결정으로 인해 추가로 할 일이 없다.
- **MapKit 위치 권한 문구** — plan ⑧이 위치 기능과 함께 넣는다. ⑧은 출시 이후로 미뤘다.
- App Store 등록 정보 (스크린샷·설명문)
- 실기기 검증 — ⑦·⑧이 끝난 뒤 일괄 수행하기로 사용자가 정했다

### 이미 처리된 것

ralli-kit `WorkoutUI`가 en/ko `Localizable.strings`를 패키지 리소스로 제공한다. "일시정지"·"계속하기"·"운동 종료" 세 문자열은 이 작업 대상이 아니다 (`2026-08-09-rallikit-adoption-and-counter-paging-design.md` §부수 효과).

## 2. 리빌드 스펙 §10 정정 — `.xcstrings` → `.lproj`

리빌드 스펙 §10은 이렇게 적었다:

> **String Catalog(`.xcstrings`)** 기반 ko/en. tennis의 lproj 방식 대신 신규 표준 채택 (Xcode 15+).

**이 결정을 뒤집는다.** 형식은 tennis-counter와 같은 `.lproj/Localizable.strings`를 쓴다.

이유는 두 가지다.

1. **형제 프로젝트와 같은 방식으로 관리하고 싶다는 사용자 판단.** tennis-counter가 이미 `.lproj` + 상징 키로 운영되고 있고, 두 앱을 같은 방식으로 다루는 편이 낫다.
2. **`.xcstrings`를 택했던 근거가 이번 설계에서 사라졌다.** 신식 형식의 실질적 이점은 복수형 내장 지원인데, §5에서 복수형을 쓰지 않기로 했으므로 그 이점이 적용되지 않는다.

plan 실행 시 리빌드 스펙 §10의 해당 문장을 이 문서를 참조해 정정한다.

## 3. 키 규칙

tennis-counter와 동일하게 **상징 키(symbolic key)** 를 쓴다. 소스의 한국어 리터럴을 키로 삼지 않는다.

```
"home_start_button" = "%lld홀 시작";        (ko)
"home_start_button" = "Start %lld Holes";   (en)
```

- 형식: `snake_case`, 화면/영역 prefix (`home_`, `summary_`, `stats_`, `scorecard_`, `history_`, `complication_`)
- `.strings` 파일은 tennis처럼 `/* 화면명 */` 주석으로 구획을 나눈다

호출 패턴은 두 가지뿐이다. 60여 곳에서 제각기 다른 방식이 나오지 않도록 이 둘로 고정한다.

```swift
// 1. 고정 문자열
Text(String(localized: "history_empty_title"))

// 2. 숫자가 들어가는 문자열 — %lld 자리표시자 + String(format:)
Text(String(format: String(localized: "home_start_button"), holeCount))
```

`Int`에는 `%lld`를 쓴다 (`%d`가 아니다 — 64비트에서 `Int`는 `Int64`다). 자리표시자가 둘 이상이면 두 언어에서 **순서가 같아야 한다**; 순서를 바꿔야 하는 문구가 나오면 `%1$lld`·`%2$lld` 형태를 쓴다.

리터럴 키 대신 상징 키를 쓰는 이유는 **ko와 en의 문구 구조가 1:1로 대응하지 않기 때문**이다 (§4). 리터럴을 키로 삼으면 한국어 문구를 고칠 때마다 영어 번역이 끊긴다.

## 4. 영어 문구 방침 — 공간에 따라 다르게

한국어 단위는 1글자(`타`·`홀`·`퍼트`)지만 영어는 `strokes`·`holes`·`putts`다. 워치 40mm와 컴플리케이션은 이미 공간이 빠듯해 축약 표기를 쓰고 있다.

**단순 번역이 아니라 각 플랫폼의 영문 골프 관습을 따른다.**

| 화면 | 한국어 | 영어 | 근거 |
|------|--------|------|------|
| iOS 통계 카드 | `평균 타수` | `Avg. Strokes` | 공간 여유 있음 — 문장/단어로 |
| iOS 홀 행 | `5타 · 2퍼트` | `5 · 2p` | 영문 스코어카드는 타수에 단위를 안 붙인다 |
| 워치 스코어카드 행 | `5타(2p)` | `5 (2p)` | 같은 이유 + 40mm 공간 |
| 워치 파 선택 | `3번 홀` | `Hole 3` | 헤더라 공간 있음 |
| 컴플리케이션 | `13타` | `13` | 가장 좁음 — 숫자만 |

**결과적으로 ko와 en의 구조가 다른 키가 생긴다.** 이건 버그가 아니라 의도이므로, 해당 키에는 `.strings` 주석으로 이유를 남긴다:

```
/* 영문 스코어카드 관습: 타수에 단위를 붙이지 않는다 */
"scorecard_row_score" = "%lld타(%lldp)";   (ko)
"scorecard_row_score" = "%lld (%lldp)";    (en)
```

이미 언어 중립인 표기는 건드리지 않는다 — `ComplicationState.holeText`(`"H3"`)와 `ScoreFormat.relativeToPar`(`"+1"`/`"E"`/`"-1"`)는 골프 표기라 두 언어에서 같다.

## 5. 복수형(`.stringsdict`)을 쓰지 않는다

영어는 `1 round` / `3 rounds`로 명사가 바뀌지만 한국어는 안 바뀐다. `.lproj` 형식에서 이걸 처리하려면 `Localizable.stringsdict`라는 XML 파일을 언어별로 따로 둬야 한다.

**숫자가 들어가는 문자열을 전수 조사한 결과, 복수형이 실제로 문제되는 곳은 통계 탭 캡션 2개뿐이었다.**

| 문자열 | count == 1이 현실적인가 |
|--------|------------------------|
| 라운드 카드 `18홀` → `18H` | 약식 표기라 무관 |
| 라운드 합계 `90타 · 32퍼트` | 라운드 합계라 1이 사실상 없음 |
| 홀 행 `5타 · 2퍼트` → `5 · 2p` | 1퍼트는 흔하지만 **약식 표기가 회피** |
| 통계 `총 12라운드` | **첫 라운드에서 1** ⚠️ |
| 통계 `18홀 라운드 3개 기준` | **첫 18홀 라운드에서 1** ⚠️ |

남은 두 곳은 **문구를 라벨 형식으로 바꿔 회피한다.** 둘 다 통계 카드 아래 캡션이라 라벨 형식이 어색하지 않다.

```
"Based on 3 full rounds"   ← 복수형 필요
"Full rounds: 3"           ← 채택

"12 rounds total"          ← 복수형 필요
"Rounds: 12"               ← 채택
```

`.stringsdict` 4개 파일(en/ko × 2타깃)과 XML 관리 부담이 전부 사라진다. 잃는 것은 캡션 두 개가 문장 대신 라벨로 읽힌다는 점뿐이다.

**향후 주의:** 새 문자열에 숫자 + 영어 명사가 붙는 조합이 생기면 이 결정을 다시 검토해야 한다. 그때는 문구 회피가 어려울 수 있고, 그 시점에 `.stringsdict`를 도입하는 편이 지금 미리 만드는 것보다 낫다.

## 6. View 밖 문자열 — 모델은 언어 중립 값만 노출한다

사용자 노출 문자열 두 개가 View 밖에서 만들어진다.

| 위치 | 값 |
|------|-----|
| `WatchApp/Features/Home/HomeViewModel.swift:24` `startButtonLabel` | `"\(holeCount)홀 시작"` |
| `Shared/Models/ComplicationState.swift:26` `strokesText` | `"\(totalStrokes)타"` |

그리고 테스트 3곳이 이 값을 하드코딩으로 검증한다 (`HomeViewModelTests:66,69`, `ComplicationStateTests:42`).

여기에 `String(localized:)`를 그대로 넣으면 **테스트가 시뮬레이터 언어 설정에 따라 통과하거나 실패하게 된다.** 영어로 실행되면 `"18홀 시작"` 대신 `"Start 18 Holes"`가 나와 깨진다.

**규칙: 언어에 따라 달라지는 텍스트는 View가 만들고, 모델·ViewModel은 숫자와 언어 중립 표기만 노출한다.**

`ComplicationState`를 보면 이 경계가 이미 자연스럽게 존재한다.

| 프로퍼티 | 값 | 언어 의존 | 처리 |
|---|---|---|---|
| `holeText` | `"H3"` | 중립 | 그대로 |
| `relativeToParText` | `"+1"` / `"E"` | 중립(골프 표기) | 그대로 |
| `strokesText` | `"13타"` | **한국어** | **제거, View로 이동** |

따라서:

- `ComplicationState.strokesText` 제거 → `ComplicationApp.swift:71`이 `totalStrokes`로 직접 포맷
- `HomeViewModel.startButtonLabel` 제거 → `HomeView.swift:17`이 `holeCount`로 직접 포맷
- 관련 테스트 단언 3줄 삭제

**테스트를 지워도 잃는 것이 없다.** 이 단언들이 검증하던 것은 번역표의 내용이고, 그건 테스트할 가치가 없다. 숫자 자체(`holeCount`·`totalStrokes`)는 다른 테스트가 이미 덮고 있다. CLAUDE.md의 "View는 테스트하지 않는다"와도 일치한다.

**기각한 대안:** 프로퍼티를 유지하고 그 안에서 `String(localized:)`를 호출하는 방법. CLAUDE.md의 "ViewModel → UI 프레임워크 import 금지"에는 걸리지 않지만(Foundation이다), 테스트를 로케일 고정하거나 느슨하게 바꿔야 하고, 그러면 지금보다 약한 테스트가 남는다.

## 7. 파일 구조

```
iOSApp/en.lproj/Localizable.strings
iOSApp/ko.lproj/Localizable.strings
iOSApp/en.lproj/InfoPlist.strings           ← HealthKit 권한 문구
iOSApp/ko.lproj/InfoPlist.strings
WatchApp/en.lproj/Localizable.strings
WatchApp/ko.lproj/Localizable.strings
WatchApp/en.lproj/InfoPlist.strings         ← HealthKit 권한 문구
WatchApp/ko.lproj/InfoPlist.strings
ComplicationApp/en.lproj/Localizable.strings
ComplicationApp/ko.lproj/Localizable.strings
```

**`Shared/`는 `.lproj`를 갖지 않는다.** `Shared/`의 유일한 사용자 문자열이던 `ComplicationState.strokesText`가 §6에서 제거되므로, 여러 타깃 번들에 같은 키를 복제하는 문제가 애초에 생기지 않는다.

`knownRegions`에는 이미 `en, Base, ko`가 등록되어 있다. `developmentRegion`은 `en`으로 두고 바꾸지 않는다 — 상징 키를 쓰면 소스 리터럴이 키가 아니므로 개발 언어 설정이 번역표에 영향을 주지 않는다.

## 8. 대상 문자열 인벤토리 (근사)

| 타깃 | 사용자 노출 문자열 | 비고 |
|------|-----------------|------|
| `iOSApp` | ~42 | 기록·상세·편집·통계 4개 영역 |
| `WatchApp` | ~17 | 홈·파 선택·카운팅·스코어카드·요약 |
| `ComplicationApp` | ~1 | §6에서 이동해 오는 것 포함 |
| InfoPlist | 2 | HealthKit 권한 (iOS·워치 양쪽 타깃에 설정돼 있음) |

이 중 숫자 보간이 들어간 것이 약 20개다. plan이 파일 단위로 정확히 열거한다.

## 9. 검증

- 세 타깃 빌드 + iOS·워치 테스트 전부 통과
- **시뮬레이터 언어를 영어로 바꿔 주요 화면 스크린샷** — 40mm 워치에서 영어가 잘리지 않는지가 핵심 확인 사항이다. 스킴의 App Language 설정 또는 `-AppleLanguages "(en)"` 실행 인자를 쓴다
- 한국어에서 기존과 동일하게 보이는지 확인 (회귀 없음)
- `make lint` / `make format` 위반 0

## 10. 리스크 — `.lproj`가 동기화 그룹에서 인식되는지 먼저 확인한다

이 프로젝트는 `PBXFileSystemSynchronizedRootGroup`을 쓰고 있어 **지금까지 pbxproj를 한 번도 수정하지 않았다** (파일 생성만으로 타깃에 반영됨). 그런데 `.lproj` 폴더가 이 동기화 그룹에서 자동으로 로컬라이즈 리소스로 잡히는지는 확실하지 않다 — 로컬라이즈는 전통적으로 pbxproj의 variant group으로 등록되던 것이다.

**plan의 첫 태스크를 "`.lproj` 하나를 만들어 실제로 인식되는지 확인"으로 잡는다.** 문자열 60여 개를 전부 옮긴 뒤에 인식이 안 되는 걸 발견하면 되돌리는 비용이 크다.

인식되지 않으면 pbxproj 수정이 필요하고, 그건 이 프로젝트에서 예외적인 일이므로 plan의 구조가 달라진다. 그 경우 사용자에게 보고하고 진행 방향을 다시 정한다.

## 11. 완료 조건

- 세 타깃의 사용자 노출 문자열이 ko/en 모두에서 올바르게 표시된다
- HealthKit 권한 대화상자가 시스템 언어에 따라 한국어/영어로 뜬다
- 워치 40mm에서 영어 문구가 잘리거나 겹치지 않는다
- 모델·ViewModel에 언어 의존 문자열이 남아 있지 않다
- 리빌드 스펙 §10이 실제 채택한 형식(`.lproj`)과 일치한다
- 세 타깃 빌드 성공, 테스트 전부 통과, `make lint`·`make format` 위반 0
