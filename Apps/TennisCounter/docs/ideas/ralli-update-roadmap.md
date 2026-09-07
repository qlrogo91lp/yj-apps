# 테니스 앱 아이디어 브레인스토밍

# 🎾 Ralli 업데이트 마스터 플랜

> 기존 테니스 점수 카운터 앱(TennisCounter → Ralli로 리브랜딩)을 **싱글 모드 우선 → 멀티 모드 + Pro 도입** 순서로 단계적 업데이트하는 계획.
> 

# 📋 빠른 요약

| 항목 | 내용 |
| --- | --- |
| **앱 이름** | **Ralli (랠리)** ⭐ — Phase 1-B 출시 시점에 TennisCounter에서 변경 |
| **현재 상태** | Home → 스코어 화면 단순 구조 |
| **목표 구조** | 3-탭 (요약 / 경기 / 기록) + 워치 연동 + 멀티 + Pro |
| **출시 전략** | 영어 우선 + 한국어 동시 (전 세계 출시) |
| **DB** | SwiftData + CloudKit (Phase 1) → + Firebase (Phase 2) |
| **수익화** | 무료 (싱글) → Pro 구독 \$2.99~3.99/월 + 광고 (Phase 2) |
| **개발자 계정** | Apple Developer Program 유료 가입 ($99/년) 필수 |
| **선행 작업** | 데이터 모델 설계 → Xcode 프로젝트 셋업 |

# 🏷️ 앱 이름: Ralli (랠리)

## 결정 사항

- **공식 명칭**: Ralli
- **공식 발음**: 랠리 (영어 "Rally"와 동일)
- **변경 시점**: Phase 1-B 출시 시점 (앱 아이콘 리뉴얼 + iOS 26 디자인과 함께)
- **Bundle ID**: 기존 그대로 유지 (사용자 데이터/리뷰/별점 자산 보존)

## 결정 이유

- **테니스 용어와 일맥상통**: 랠리는 "공을 주고받는 행위" — Phase 2 멀티 모드의 "점수 공유 + 소셜" 컨셉과 완벽 매칭
- **짧고 펑키함**: 5자, 발음 쉬움, 캐주얼한 어감
- **글로벌 통용성**: 영어/한국어/일본어 모두 자연스러운 발음
- **차별화 가능**: "Rally"는 충돌 많지만 "Ralli" 표기로 검색 충돌 회피
- **TennisCounter 한계 극복**: 기능 직설형(Counter)에서 컨셉/감성형으로 전환 → 멀티/소셜 확장에도 어울림

## 검증 결과

### App Store 충돌 체크

- ✅ **테니스/스포츠 점수 카테고리에 "Ralli" 동명 앱 없음**
- 동명 앱: Ralli - AI Motivation (정신 건강), Ralli Injury Lawyers (법무) → 카테고리 완전 다름, 사용자 혼동 가능성 낮음
- 인접 우려: Rally Sports (스포츠 커뮤니티) — 카테고리 다르고 발음도 미세하게 다름

### 도메인 상태

- ❌ [ralli.app](http://ralli.app) — 선점됨 (chat plugin 서비스)
- ❌ [ralli.com](http://ralli.com) — 선점됨
- ⚠️ [letsralli.com](http://letsralli.com) — 스포츠 트레이닝 파트너 매칭 앱 (직접 경쟁 아님)
- 🔍 **사용 가능 후보**: [rallitennis.com](http://rallitennis.com), [playralli.com](http://playralli.com), [ralli.io](http://ralli.io), [getralli.com](http://getralli.com) (개별 등록 가능성 확인 필요)

### 향후 액션

- [ ]  도메인 후보 등록 가능성 실제 체크 ([rallitennis.com](http://rallitennis.com) 우선)
- [ ]  상표 검색 (USPTO, KIPRIS)
- [ ]  소셜 핸들 확보 (Twitter @ralli, Instagram @ralli 등)

## 발음 정책

### 공식 발음: "랠리"

- 영어 "Rally"와 동일 발음
- 테니스에서 일반적으로 쓰는 용어 그대로
- 한국어 사용자에게 "테니스 랠리"로 즉시 의미 전달

### 양립 수용

- 일부 한국 사용자가 "랄리"로 읽어도 OK
- 브랜드 일관성은 시각적 정체성(로고, 타이포)으로 확보
- 발음 강요 X, 시각적 표기 "Ralli" 통일

## 변경 시 마케팅 전략

### Phase 1-B 출시 시 메이저 업데이트로 발표

```
🎾 TennisCounter is now Ralli!
— New name. New design. New experience.
— iOS 26 디자인, Live Activity, HealthKit 통합
```

### 검색 트래픽 보호

- App Store Subtitle에 "Tennis Score & Match" 등 카테고리 명시
- 키워드에 "TennisCounter" 일정 기간(3-6개월) 유지
- 업데이트 노트에 "Previously known as TennisCounter" 명시
- 6개월 후 완전 전환

### Bundle ID 유지로 자동 마이그레이션

- 기존 사용자: 자동 업데이트로 새 이름 반영
- 데이터/iCloud/구독: 그대로 유지
- 별점/리뷰: 그대로 따라옴

---

# 🚀 Phase 0: 사전 준비

Phase 1 진입 전에 완료해야 하는 것들.

## 개발자 계정

- **Apple Developer Program 유료 가입** (\$99/년) — 필수
- 이유: CloudKit, HealthKit, Push 등 모두 유료 계정 필요
- 결제 후 24\~48시간 내 활성화
- 무료 계정(Personal Team)은 7일마다 재빌드 필요해 코트에서 갑자기 앱 안 켜질 위험

## 글로벌 출시 기반 세팅

**원칙: 영어 베이스 + 한국어 Localization**

- Development Language: **English (U.S.)**
- 코드 변수명, 주석, 로그, 마스터 문자열 모두 영어
- 한국어는 `ko.lproj/Localizable.strings`로 별도 추가
- App Store 메타데이터: 영어 메인 + 한국어 번역
- 출시 국가: 전 세계 (제한 없음)

**iOS 언어 결정 메커니즘**

```
사용자 iPhone 시스템 언어 설정
    ↓
앱이 지원하는 언어 목록과 매칭
    ↓
일치 언어 사용, 없으면 English 폴백
```

App Store 다운로드 지역이 아닌 **iPhone 시스템 언어**가 기준. 한국 앱스토어에서 받아도 iPhone이 영어 설정이면 영어로 표시됨.

## 데이터 모델 설계 (Phase 1 진입 전 확정)

처음부터 CloudKit 호환으로 잡아둬야 마이그레이션 비용 절감.

```swift
@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var mode: String = "single" // "single" | "multi"
    var sets: [SetRecord]? = []
    var opponentName: String?
    var caloriesBurned: Double?  // HealthKit 연동
    var durationSeconds: Int?
}
```

**CloudKit 호환 제약사항**

- iCloud 미로그인 사용자도 로컬은 동작하도록 설계
- 모든 프로퍼티가 **optional 또는 default value** 필수
- Relationship도 **optional 또는 빈 배열**로 초기화
- `@Attribute(.unique)` 같은 일부 제약은 CloudKit에서 동작 안 함

---

# 🎯 Phase 1: 싱글 모드 MVP

> **목표**: 혼자 사용하는 테니스 점수 기록 앱. Phase 1만 완성해도 App Store 출시 가능한 완성품.
> 

> **비용**: \$0 (개발자 계정비 외)
> 

> **언어**: 영어 + 한국어
> 

> **출시 국가**: 전 세계
> 

## 메뉴 구성

기존 Home → 스코어 화면 단순 구조에서 **3-탭 구조**로 개편:

- **요약** — 오늘/이번 주 활동, 통계 카드, 최근 경기
- **경기** — 스코어 입력 진입점 (모드 선택 → 스코어 화면)
- **기록** — 저장된 경기 히스토리

## 🎯 경기 모드 메뉴 구조 (확정)

### Phase 1 (싱글만 노출)

경기 탭 진입 시 **모드 선택 화면**:

```jsx
[새 경기 시작]
├── 🎾 One Set (한 세트)
│   - 빠른 연습용, 한 세트만 기록
└── 🏆 Best of 3 (3세트 매치)
    - 정식 경기, 2세트 선취 시 종료
```

→ Phase 1에서는 1단계 메뉴(Solo/Multi) 생략. 멀티가 없는 시점에 한 단계 더 들어가는 건 UX 비용만 증가.

→ Phase 2 시 멀티 추가하며 1단계 메뉴 부활 (자연스럽게 디자인 개편 시점).

### Phase 2 (전체 구조)

```jsx
[새 경기 시작]
│
├── 🏃 Solo (솔로)
│   ├── 🎾 One Set (한 세트)
│   └── 🏆 Best of 3 (3세트 매치)
│
└── 👥 Multi (멀티) [PRO 🔒]
    ├── 🏠 Create Room (방 만들기)
    └── 🚪 Join Room (방 참가)
```

### 메뉴명 결정 이유

| 레벨 | 영어 | 한국어 | 선정 이유 |
| --- | --- | --- | --- |
| 1단계 | Solo / Multi | 솔로 / 멀티 | 짧고 명확, Ralli 캐주얼 톤과 매칭, 글로벌 통용 |
| 2단계 (솔로) | One Set / Best of 3 | 한 세트 / 3세트 매치 | 테니스 정식 용어, 의미 충돌 없음 ("Pro"는 구독과 헷갈림 ❌) |
| 2단계 (멀티) | Create Room / Join Room | 방 만들기 / 방 참가 | 모든 게임/회의 앱 표준 패턴, 6자리 코드 시스템과 자연스럽게 연결 |

### 데이터 모델 변경

```swift
@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var mode: String = "solo" // "solo" | "multi"
    var matchFormat: String = "one_set" // "one_set" | "best_of_3"
    var sets: [SetRecord]? = []
    var opponentName: String?
    var caloriesBurned: Double?
    var durationSeconds: Int?
}
```

- `matchFormat` 필드 추가 → 한 세트/3세트 매치 구분
- 통계 집계 시 모드별 분리 가능 ("한 세트 평균 점수", "3세트 매치 승률" 등)

### Localization

```jsx
// Localizable.strings (en)
"match_mode_solo" = "Solo";
"match_mode_multi" = "Multi";
"solo_one_set" = "One Set";
"solo_best_of_3" = "Best of 3";
"multi_create" = "Create Room";
"multi_join" = "Join Room";

// Localizable.strings (ko)
"match_mode_solo" = "솔로";
"match_mode_multi" = "멀티";
"solo_one_set" = "한 세트";
"solo_best_of_3" = "3세트 매치";
"multi_create" = "방 만들기";
"multi_join" = "방 참가";
```

### UI 분기 (스코어 화면)

- **One Set 모드**: 단일 세트 점수만 크게 표시, [경기 종료] 버튼
- **Best of 3 모드**: 세트 인디케이터 (Set 1/2/3) + 이전 세트 결과 + [세트 종료] / [매치 종료] 버튼

## Phase 1-A: 기본 기능 (코트에서 사용 가능 시점)

| 단계 | 작업 | 비고 |
| --- | --- | --- |
| 1 | 데이터 모델 + SwiftData/CloudKit 셋업 | 모든 후속 작업 기반 |
| 2 | 기록 탭 구현 | 저장/조회 검증 |
| 3 | 요약 탭 구현 | 통계 집계 로직 |
| 4 | WatchConnectivity 점수 동기화 | 기존 워치 UI 재사용 |

→ **이 시점에 경기 중 사용 가능**

## Phase 1-B: 차별화 기능

| 단계 | 작업 | 비고 |
| --- | --- | --- |
| 5 | HealthKit 워크아웃 세션 + 좌우 스와이프 페이지 | 화면 유지 문제도 함께 해결 |
| 6 | 앱 아이콘 리뉴얼 + iOS 26 디자인 | 윤재 직접 제작 |
| 7 | Live Activity 도입 | 잠금화면 점수 표시 |

→ **App Store 대외 출시 (무료 앱)**

## Phase 1 핵심 결정사항

### ⚙️ HealthKit: 모든 모드에서 각자 측정 (공유 X)

- HealthKit 데이터는 **개인 건강 데이터** → Firebase로 공유 안 함
- 각자 자기 iPhone HealthKit / Apple 헬스앱에 저장
- 공유되는 건 점수뿐
- 결과적으로 싱글/멀티 모드 분리 불필요 → 코드 단순

### 워치 페이지 구조: 좌우 스와이프 (Apple 워크아웃 앱 스타일)

- **페이지 1 (메인)**: 스코어 입력 (기존 UI)
- **페이지 2**: 운동 데이터 (현재 BPM, 누적 칼로리, 경과 시간)
- **페이지 3**: 세트 히스토리 (현재 경기의 세트별 점수)

### "운동 시작" 버튼 별도 X — 경기 시작 = 운동 시작

```
[새 경기 시작] 버튼 누름
    ↓
1. HKWorkoutSession 시작 (백그라운드)
2. 스코어 페이지로 진입
    ↓
경기 진행 중 (좌우 스와이프로 데이터 확인)
    ↓
[경기 종료] 버튼
    ↓
1. HKWorkoutSession 종료
2. 칼로리/시간/평균 BPM이 SwiftData에 저장
3. Apple 헬스앱에도 운동 기록 추가
```

### HealthKit 권한 요청 시점

앱 첫 실행이 아닌 **"새 경기 시작" 첫 클릭 시점**에 요청 (동의율 ↑)

### 워치 미착용 케이스

- 폰만 사용 시: BPM 측정 불가, 칼로리 부정확
- 운동 데이터 페이지에 "워치 연결 시 측정 가능" 안내 또는 페이지 숨김

### 화면 꺼짐 / 백그라운드 유지 해결

이전 앱에서 화면이 꺼지던 문제 → `HKWorkoutSession` 도입으로 자연스럽게 해결됨

- iOS: `UIApplication.shared.isIdleTimerDisabled = true`
- watchOS: 워크아웃 세션 active 시 자동으로 화면 유지 + Always On Display 지원
- 백그라운드 데이터 측정도 워크아웃 세션이 background runtime 권한 부여

### 요약 페이지 디폴트

- **이번 주 디폴트** + 기간 토글 (오늘 / 이번 주 / 이번 달 / 전체)
- 헬스앱 패턴 참고

### 요약 페이지 보강 아이디어

- **연속 기록 (streak)** — 며칠 연속 플레이
- **최근 경기 카드 1\~2개** — 탭 시 기록 탭으로 이동
- **상대별 전적** — 멀티 도입 시 의미 커짐

### 기록 페이지

- **로컬 무제한 보관** (CloudKit은 본인 iCloud 저장 → 비용 부담 X)
- 무료 사용자도 무제한 보관
- **달력 뷰 + 리스트 뷰 토글** 추천

### 앱 아이콘: iOS 26 Layered Icon (직접 제작)

- iOS 26 Icon Composer (Xcode 포함) 활용
- 레이어 구조: background / middle / foreground
- Liquid Glass 효과 + 다크/틴트 모드 자동 대응
- Figma 작업 → 레이어별 PNG/SVG export → Icon Composer에서 .icon 파일로 합치기
- **주의**: 각 레이어 투명 배경 필수, 전경 요소 너무 디테일하지 않게 (블러 시 뭉개짐)

### Live Activity (5단계 직후 도입 확정)

**Live Activity란**: iOS 16+에서 앱이 백그라운드여도 **잠금화면 + Dynamic Island**에 실시간 정보 표시 (우버 도착 시간, 배달 상태 등)

**활용 시나리오**

- 폰을 가방에 넣고 워치로 점수 입력 → 잠금화면에 현재 점수 표시
- 동행자가 폰 잠금화면만 봐도 점수 확인 가능
- (Phase 2 후) 관전자가 자기 폰 잠금화면으로 친구 경기 모니터링

도입 시점이 5단계 직후인 이유: 싱글 사용자도 즉각 혜택, SwiftData 점수만 있으면 구현 가능 → 의존성 단순. Phase 2 멀티 도입 시 Firebase 데이터 소스만 추가 연결.

---

# 🔍 Phase 1.5: 검증 단계 (출시 후 3\~6개월)

- 사용자 피드백 수집
- "친구랑 점수 공유 기능 원하나?" 검증
- 멀티 모드 진입 의사결정
- 한국 시장 안정화 후 → 영어권 마케팅 시작

## 마케팅 채널 (단계별)

| 시점 | 채널 |
| --- | --- |
| Phase 1 출시 직후 | 국내 테니스 커뮤니티 (네이버 카페, 디씨 테니스 갤러리), 친구/동호회 바이럴 |
| Phase 1.5+ 영어권 확장 | Reddit r/tennis, Twitter/X 영어권 테니스 계정, Product Hunt 등록, TestFlight 베타, ASO 영어 키워드 최적화 |
| Phase 2+ 일본 시장 | 일본 테니스 커뮤니티, 일본어 메타데이터 추가 |

---

# 🌐 Phase 2: 멀티 모드 + Pro 도입

> **목표**: 실시간 스코어 공유 + 소셜 + 수익화 시작
> 

> **비용**: 초반 \$0, 성장 후 월 \$20\~50 (Firebase)
> 

> **변환점**: 서버리스 → Firebase 도입
> 

## 핵심 컨셉

실시간 스코어 공유 + 소셜 커뮤니케이션. 경기 중 최대 4-6명(플레이어 + 관전자)이 방에 입장해 스코어를 공유하고 이모티콘/프리셋 문구를 주고받는다.

## 작업 단계

| 단계 | 작업 | 비고 |
| --- | --- | --- |
| 8 | Firebase 프로젝트 셋업 + 인증 | Anonymous Auth or Apple 로그인 |
| 9 | 방 생성/입장 플로우 (Create Room / Join Room) | 6자리 코드, 1단계 메뉴(Solo/Multi) 구조 도입 |
| 10 | Realtime DB 실시간 점수 동기화 | last-write-wins |
| 11 | 이모티콘/프리셋 문구 | 5\~8개 제한 |
| 12 | FCM 초대/결과 알림 | 푸시 설정 |
| 13 | Live Activity 멀티 대응 확장 | 관전자용 |
| 14 | StoreKit 2 구독 구현 | 호스트 전용 Pro 권한 |

## 방 구조

- 6자리 코드로 방 생성/참여
- 플레이어(스코어 입력 권한) + 관전자(이모티콘만) 역할 분리
- 최대 4\~6명 동시 입장

## 실시간 스코어 공유

- Firebase Realtime Database 기반 실시간 동기화
- 테니스 스코어 자동 계산 (0-15-30-40-Deuce-Ad, 세트, 타이브레이크)
- 스코어 입력은 "우리편 득점 / 상대편 득점" 버튼 2개로 단순화
- Optimistic UI 적용 (탭 즉시 반영)
- **모든 플레이어 입력 가능** (last-write-wins로 충돌 처리, 동시 입력 가능성 낮음)

## 이모티콘 / 프리셋 문구

- 5\~8개로 제한 (집중 방해 최소화)
- 예시: 👍 나이스샷, 😅 아쉽, 🔥 에이스, ⏸️ 물 한잔
- 실제 문구는 클라이언트 하드코딩, Firebase엔 emoji_id만 전송

## Firebase 데이터 구조

```jsx
Realtime Database (실시간):
/rooms/{roomId}
  /score: { p1: 30, p2: 15, game_p1: 2, game_p2: 1 }
  /participants: { uid1: {role: "player"}, uid2: {role: "spectator"} }
  /last_emoji: { from: uid1, emoji_id: "nice_shot", ts: 123456 }

Firestore (영구 저장):
/matches/{matchId} — 경기 종료 후 요약만 저장
/users/{uid} — 프로필, 통계
```

## Firebase 비용 가이드

| 규모 | 예상 비용 |
| --- | --- |
| \~1,000 MAU | \$0 (무료 티어) |
| \~1만 MAU | \$0\~5/월 |
| \~10만 MAU | \$20\~50/월 |
- 테니스 앱은 경기 중에만 연결 → 24시간 상시 연결 아님
- 스코어 데이터는 바이트 단위 → 대역폭 거의 소모 안 함
- RTDB 무료 동시 접속 10만 명, 다운로드 10GB/월

**주의**: 클라이언트 버그로 무한루프 시 비용 폭탄 가능 → **Firebase Budget Alert 필수**

## 보안 규칙

방 참여자만 read, 플레이어만 스코어 write 가능하도록 RTDB Security Rules 설정 필수.

## 구현 팁

- **방 TTL**: 경기 종료 후 1시간 뒤 RTDB 방 데이터 자동 삭제 (쓰레기 데이터 방지)
- **Presence**: Firebase `onDisconnect()` 활용해 연결 끊긴 참여자 표시 (야외 코트 네트워크 불안정 대응)
- **iOS 백그라운드 소켓 유지**: Background Modes → Remote notifications + silent push 패턴

---

# 💎 Phase 3: 수익화 고도화

| 단계 | 작업 |
| --- | --- |
| 15 | 통계 대시보드 (월간/연간, 승률, 시간대별 등) |
| 16 | 경기 결과 카드 이미지 생성 (SwiftUI ImageRenderer, 인스타 공유용) |
| 17 | 커스텀 이모티콘/닉네임 |

---

# 💰 수익화 전략

**원칙**: 멀티 모드 자체를 Pro 핵심 가치로 (기존 "모든 멀티 기능 무료" 전략에서 변경).

## Free vs Pro

| 기능 | Free | Pro |
| --- | --- | --- |
| 싱글 점수 기록 | ✅ 무제한 | ✅ |
| 워치 연동 | ✅ | ✅ |
| HealthKit 운동 측정 | ✅ | ✅ |
| iCloud 기기 동기화 | ✅ | ✅ |
| Live Activity | ✅ | ✅ |
| 멀티 방 입장 (게스트) | ✅ 무제한 | ✅ |
| 멀티 방 생성 (호스트) | ❌ | ✅ |
| 통계 대시보드 | ❌ | ✅ |
| 경기 결과 카드 생성 | ❌ | ✅ |
| 커스텀 이모티콘 | ❌ | ✅ |
| 광고 제거 | ❌ | ✅ |

## "호스트만 Pro" 정책

- 호스트가 Pro면 게스트는 무료 입장 가능
- 이유:
    - 바이럴 효과: "친구가 만든 방이 너무 편해! 우리 동호회도 도입해야겠다"
    - Pro 전환 유도: "나도 호스트 해보고 싶다" → Pro 구독
    - Firebase 비용 통제: 무른 방 생성 방지
- B2C SaaS의 종단간 철학 (Slack, Notion 초창기 전략과 유사)

## 가격 정책

- **\$2.99\~3.99/월** 범위 검토 (멀티 포함 시 체감 가치 ↑)
- 연간: \$19.99\~29.99 (Apple 수수료 30% 제외 시 실수령 \$14\~21)
- 경쟁 앱 참고해 Phase 2 출시 직전 확정

## 수익 단계별 로드맵

| 시점 | 수익 모델 | 목표 |
| --- | --- | --- |
| Phase 1 출시 | 수익 없음 | 사용자 확보, 검증 |
| Phase 1.5 (3\~6개월) | 수익 없음 | 피드백 수집 |
| Phase 2 출시 | Pro 구독 시작 | BEP: 월 유료 유저 10\~30명 |
| Phase 3 | Pro 가치 증대 | 데이터 기반 가격/제한 튜닝 |

## 하면 안 되는 것

- 방 생성 횟수 제한 (X) → 사용 빈도 낮아져 앱이 죽음
- 참여자 수 제한 (X) → 소셜 앱의 본질 훼손

---

# 📡 통신 구조 (전체)

4가지 통신 방식 단계별 도입. 각자 다른 역할이라 충돌 없음.

| 통신 방식 | 용도 | 도입 단계 | 특징 |
| --- | --- | --- | --- |
| **CloudKit** | 폰↔워치, 폰↔폰(같은 iCloud) 기록 동기화 | Phase 1 (1단계) | 느림(수 초~수십 초), 영구 저장용 |
| **WatchConnectivity** | 폰↔워치 실시간 점수 동기화 | Phase 1 (4단계) | 즉각적, 오프라인 동작 |
| **Firebase Realtime DB** | 다른 사용자와 실시간 점수 공유 | Phase 2 (10단계) | 인터넷 필수, 멀티유저 |
| **FCM (Firebase Push)** | 경기 초대/결과 알림 | Phase 2 (12단계) | 앱 꺼져있을 때도 전달 |

## 왜 다 필요한가

- **CloudKit은 빠르지 않음** → 실시간 점수엔 부족
- **WatchConnectivity는 폰↔워치만 지원** → 다른 사용자와 공유 불가
- **Firebase는 인터넷 필수** → 오프라인일 때 워치↔폰 통신 불가
- **푸시는 throttle/drop 가능** → 실시간 점수 동기화 불가

각자 다른 문제 해결 → 단계별로 모두 도입.

---

# 🏆 차별화 포인트

📊 **영어권 시장 경쟁 앱 상세 분석은** [📊 영어권 테니스 앱 시장 분석](https://www.notion.so/350cd15e48f1810dbafdd8c31dd337ad?pvs=21) **자식 페이지 참고**

- **소셜 요소**: 기존 앱(SwingVision, MatchTrack 등)은 대부분 혼자 쓰는 스코어키퍼 → 실시간 공유가 진짜 차별점
- **게스트 관전 모드**: 코트 밖 부모님/친구가 링크로 실시간 스코어 보기
- **Live Activity**: 가방에 폰 넣어두고 워치로 입력해도 잠금화면에 점수 표시
- **HealthKit 통합**: 점수 + 운동 데이터를 한 앱에서
- **장기 확장**: 아카데미/동호회 B2B (코치가 학생 경기 데이터 수집 → 레슨 피드백)

---

# ✅ 작업 체크리스트

## Phase 0 (사전 준비)

- [ ]  Apple Developer Program 가입 (\$99/년)
- [ ]  데이터 모델 상세 설계 (`Match`, `Set`, `Game`)
- [ ]  Xcode 프로젝트 셋업 (CloudKit Capability 추가)
- [ ]  영어 마스터 문자열 정리 (`Localizable.strings`)
- [ ]  한국어 번역 추가 (`ko.lproj`)

## Phase 1-A

- [ ]  SwiftData + CloudKit 셋업 (`Match.matchFormat` 필드 포함)
- [ ]  경기 모드 선택 화면 (One Set / Best of 3)
- [ ]  스코어 화면 모드별 UI 분기
- [ ]  기록 탭 구현
- [ ]  요약 탭 구현
- [ ]  WatchConnectivity 점수 동기화
- [ ]  코트에서 실사용 검증

## Phase 1-B

- [ ]  HealthKit 워크아웃 세션
- [ ]  좌우 스와이프 페이지 (스코어/운동/세트)
- [ ]  앱 아이콘 직접 제작 (Icon Composer)
- [ ]  Live Activity
- [ ]  App Store 출시 준비 (메타데이터, 스크린샷, 영어+한국어)

## Phase 2

- [ ]  Firebase 프로젝트 셋업 + Budget Alert 설정
- [ ]  인증 플로우
- [ ]  1단계 메뉴 도입 (Solo / Multi)
- [ ]  방 생성/입장 (Create Room / Join Room, 6자리 코드)
- [ ]  Realtime DB 점수 동기화
- [ ]  이모티콘 시스템
- [ ]  FCM 푸시 설정
- [ ]  Live Activity 멀티 확장
- [ ]  StoreKit 2 구독 구현

## Phase 3

- [ ]  통계 대시보드
- [ ]  경기 결과 카드 생성
- [ ]  커스텀 이모티콘

[영어권 테니스 앱 시장 분석](https://www.notion.so/350cd15e48f1810dbafdd8c31dd337ad?pvs=21)