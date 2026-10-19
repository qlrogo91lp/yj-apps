# 하루치 핏 1.0 출시 체크리스트

상태: 결정 2개 확정, 방침 · 지원 URL 결정 대기 (2026-10-19). 항목은 저장소의 현재 상태를 읽고 정했다 — 아래 "확인한 사실"이 근거다.
관련: [APPSTORE.md](../../../../APPSTORE.md) · [온보딩 플랜](../../ios/2026/2026-10-13-onboarding.md) · 루트 `TODO.md` "출시 준비"

표기: **[결정]** 사용자가 정해야 다음이 풀리는 것 · **[코드]** 저장소 변경(브랜치 + PR) · **[ASC]** App Store Connect · 개발자 포털 작업 · **[기기]** 실기기 · 빌드 확인

## 확인한 사실

| 항목 | 현재 |
|---|---|
| 버전 | iOS · 워치 · 컴플리케이션 모두 `MARKETING_VERSION 1.0.0`, 빌드 번호 `1`. 세 타깃이 일치한다 |
| 번들 ID · 팀 | `com.yj.HaruchiFit` · `.watchkitapp` · `.watchkitapp.ComplicationApp`, 팀 `P2TU28W32L` |
| 최소 버전 | iOS 17 (iPhone 전용) · watchOS 10 |
| 엔타이틀먼트 | HealthKit (iOS · 워치) · App Group `group.com.yj.HaruchiFit` (워치 · 컴플리케이션). **iCloud / CloudKit 없음** — 저장은 로컬 폴백이다 |
| 프라이버시 매니페스트 | **없다** (`PrivacyInfo.xcprivacy` 가 세 타깃 어디에도 없다) |
| 필수 사유 API | `UserDefaults` 를 쓴다 — 온보딩 `@AppStorage`, HealthKit 앵커 저장, 워치↔컴플리케이션 스냅샷(App Group) |
| 외부 SDK | **없다** (Firebase · 분석 · 크래시 수집 없음). 데이터가 기기 밖으로 나가지 않는다 |
| 암호화 신고 | `ITSAppUsesNonExemptEncryption` 미설정 — 빌드를 올릴 때마다 수출 규정 질문이 뜬다 |
| 건강 권한 문구 | `InfoPlist.xcstrings` 에 ko · en 있음 (`NSHealthShareUsageDescription` · `NSHealthUpdateUsageDescription`) |
| 앱 아이콘 | `HaruchiFit.icon`(아이콘 컴포저) 있음. `AppIcon.appiconset` 은 `Contents.json` 뿐 |
| 개인정보처리방침 | 이 저장소에 문서가 없다. 설정(07)이 보류라 **앱 안에 링크를 둘 자리도 없다** |
| 스토어 문구 | `APPSTORE.md` 초안 완료 (ko · en-US). 스크린샷 캡션 절은 아직 없다 |

## 1. 결정 (남은 하나 — URL — 가 풀려야 ASC 입력이 끝난다)

1. **[결정됨 · 10-19] CloudKit 은 1.0 에 넣지 않는다.** 저장은 기기 로컬 SwiftData 다.
   - 폰을 바꿀 때는 기기 백업 · 이전으로 앱 데이터가 함께 넘어간다. 잃는 경우는 **앱을 지우고 다시 설치할 때뿐**이다
   - 그때 건강 앱의 운동은 다시 가져오므로 **잔디 · 횟수 · 시간 · 칼로리는 돌아온다.** 사라지는 것은 수동 기록, 부위 · 메모,
     근력 · 유산소 구간이다 (워치 운동은 건강 앱에 근력 한 종류로 저장돼 다시 가져오면 전부 근력 한 구간이 된다)
   - 미루는 이유: CloudKit 프로덕션 스키마는 배포 뒤 필드 삭제 · 타입 변경 · 이름 변경이 안 되고 추가만 된다. 1.0 피드백으로 모델이 바뀔 시기에 그 제약을 지지 않는다.
     모델은 이미 CloudKit 제약(기본값, `.unique` 없음)에 맞춰 있어 나중에 엔타이틀먼트만 더하면 기존 로컬 기록이 올라간다
2. **[결정됨 · 10-19] 앱 안 개인정보처리방침 링크는 1.0 에 두지 않는다.** 가이드라인 5.1.1(i) 은 앱 안 링크를 요구하지만 Ralli · 골프는 링크 없이 통과했다.
   07 설정을 만들 때 `정보` 그룹에 iOS 에만 넣는다 (워치는 한 앱으로 함께 심사되고 웹 페이지를 열 수 없다).
   **반려되면** 홈 툴바 `ⓘ` → 시트(개인정보처리방침 · 문의하기 · 앱 소개 다시 보기 · 버전)로 당겨 다시 낸다
3. **[결정] 개인정보처리방침 · 지원 URL 을 어디에 둘까.** Ralli 는 이미 앱 개인정보를 입력해(10-02) 방침 URL 이 있을 것이다.
   그 페이지가 앱별인지 시리즈 공통인지 알려 주면 하루치 항목을 거기에 더한다. 없으면 공개 저장소의 GitHub Pages 나 Notion 공개 페이지가 가장 빠르다.
   **지원 URL 도 필수**라 같은 곳에 `문의` 연락처를 둔다

## 2. 코드 (결정 2 가 정해지면 한 브랜치로 묶는다)

- [ ] **[코드] `PrivacyInfo.xcprivacy` 를 iOS · 워치 · 컴플리케이션 세 타깃에 추가한다.** 업로드를 막지는 않는다 (Ralli · 골프도 없이 통과).
      `UserDefaults` 사유 — 앱 자신의 설정 `CA92.1`, App Group 공유 `1C8F.1` (워치 · 컴플리케이션). 수집 데이터 없음, 추적 없음.
      세 앱에 함께 넣는다 — 루트 `TODO.md` "모노레포 공통"
- [x] **[코드] `ITSAppUsesNonExemptEncryption = NO`** 를 iOS · 워치 빌드 설정(`INFOPLIST_KEY_`)에 추가했다 — 세 앱 한 PR (`chore/export-compliance-key`, 10-19)
- [ ] **[코드] 빌드 번호 정책:** 업로드마다 `CURRENT_PROJECT_VERSION` 을 올린다 (세 타깃 같이). 지금 `1`
- [ ] **[코드] 아이콘 확인:** 아카이브에서 iOS · 워치 · 컴플리케이션 아이콘이 모두 나오는지 Organizer 로 본다. 비어 있으면 에셋 카탈로그에 채운다

## 3. App Store Connect · 개발자 포털 (사용자)

- [ ] **[ASC] 개발자 포털:** 세 App ID 에 HealthKit, 두 타깃에 App Group 이 켜져 있는지 확인한다 (실기기 빌드가 돌았으면 자동 서명이 이미 만들었을 것)
- [ ] **[ASC] 앱 레코드 생성:** 번들 ID `com.yj.HaruchiFit`, SKU, 기본 언어, 카테고리 `건강 및 피트니스`. 이름 `Haruchi Fit – Workout Grid` · `하루치 핏 — 운동 잔디 기록` 이 사용 가능한지 이때 확인된다
- [ ] **[ASC] 문구 입력:** `APPSTORE.md` 의 ko · en-US 를 필드별로 붙여 넣는다 (이름 · 부제 · 프로모션 · 키워드 · 설명 · 출시 노트). 글자 수 한도는 파일에 적혀 있다
- [ ] **[ASC] URL 3개:** 개인정보처리방침(필수) · 지원(필수) · 마케팅(선택) — 결정 3 의 결과
- [ ] **[ASC] 앱 개인정보:** **`데이터 수집 안 함`**. 건강 데이터는 기기 안에서만 읽고 개발자에게 전송하지 않는다.
      Ralli 와 달리 크래시 · 진단 수집이 없다. (나중에 CloudKit 을 켜도 사용자 본인 iCloud 저장은 개발자 수집이 아니라 응답이 바뀌지 않는다)
- [ ] **[ASC] 연령 등급 설문 · 가격(무료 여부) · 판매 국가 · 콘텐츠 권한**
- [ ] **[ASC] 심사 정보:** 연락처, 심사 메모(아래 초안), 로그인 없음 → 데모 계정 불필요
- [ ] **[ASC] 스크린샷:** 별도 트랙이다 (4절). 업로드 규격은 ASC 의 현재 요구 크기를 그때 확인한다 — iPhone 은 필수 크기가 있고,
      워치 앱을 포함하므로 **Apple Watch 스크린샷도 필요**하다

### 심사 메모 초안 (영어, 심사자가 읽는다)

> Haruchi Fit records strength and cardio segments on Apple Watch and shows them as an activity grid on iPhone. No account, sign-in, ads, or tracking. All data stays on the device.
>
> To test without an Apple Watch: finish the 3-page onboarding, tap Continue and allow Health access (or deny — the app still works), then tap "+" on the Home tab to add a manual workout. Workouts recorded in other apps appear automatically after Health access is granted. Tap any workout to add body parts and a note.
>
> Health data is only read (and written by the watch app for the workouts it records); it is never transmitted off the device.

확정되면 `APPSTORE.md` 맨 아래 `심사 메모` 절로 옮긴다 (스토어에 들어가는 문구는 그 파일이 원본이다).

## 4. 스크린샷 (별도 트랙 — 사용자가 피그마로 제작)

- [ ] **구성안:** 몇 장, 어떤 순서, 캡션(ko · en-US). 메시지 위계는 `APPSTORE.md` 와 같다 — ①운동하면 잔디가 자란다 ②근력·유산소 구간 ③워치만으로 완결 ④보조
- [ ] 캡션이 정해지면 `APPSTORE.md` 맨 아래 절로 추가한다 (제가 한다)
- [ ] 소재는 온보딩 2장의 워치 캡처와 겹친다 — 같은 시뮬레이터 캡처를 재사용할 수 있다

## 5. 빌드 · 제출

- [ ] **[기기] Xcode 27.1 환경 복구:** 이 Mac 은 CoreSimulator 구버전으로 `xcodebuild` 가 막힌다. `! xcodebuild -runFirstLaunch` (관리자 인증)
- [ ] **[기기] `main` 에서 `HaruchiFit` 빌드 · `HaruchiFitWatchTests` 전체 통과 확인** — 온보딩 PR 머지 뒤 통계 수정 2건은 빌드를 못 돌렸다
- [ ] **[기기] 루트 `TODO.md` "집 맥북에서 할 것" 의 실기기 확인 묶음을 Release 구성으로 한 번에 돈다** (워치 → 폰 → 홈 → 기록 → 통계 → 공유, 온보딩 새 설치)
- [ ] **[기기] 새 설치 시나리오:** 앱 삭제 → 설치 → 온보딩 → 건강 권한 허용 / 거부 각각 → 수동 기록 추가 → 워치 운동 → 잔디 반영
- [ ] **[ASC] 아카이브 → TestFlight 업로드** (Xcode Organizer, iOS 스킴이 워치 앱을 내장한다). 내부 테스트는 베타 앱 심사 없이 바로 된다
- [ ] **[기기] TestFlight 빌드로 기능 테스트** — 사용자가 하기로 한 단계
- [ ] **[ASC] 심사 제출 → 출시 방식(수동 / 자동) 선택**

## 6. 출시 뒤

- [ ] 출시 노트를 다음 버전 때 덮어쓴다 (`APPSTORE.md`)
- [ ] `TODO.md` 의 취소선 행을 비운다 (루트 규약)
- [ ] CloudKit 을 다음 버전 후보로 `TODO.md` 에 남긴다
