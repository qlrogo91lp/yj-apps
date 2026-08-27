# 피트니스 앱 목록의 "시간 vs kcal" 표시 — 조사 결과 (수정 불가 결론)

## 작업일: 2026-06-16

## 증상

Apple **피트니스 앱 → 세션(워크아웃) 목록**에서, 각 줄의 헤드라인 수치가:
- 우리 앱(Ralli)이 기록한 테니스 워크아웃 → **운동 시간**(예: `2:26`)
- Apple 자체 운동 앱이 기록한 테니스 → **활동 칼로리**(예: `326KCAL`)

로 다르게 떴다. 우리 것도 kcal로 띄우고 싶다는 요구.

> 참고: 워크아웃 **상세 화면**에는 우리 것도 활동 킬로칼로리(예: 1,179)가 정상 표시됨. 문제는 **목록 줄의 대표 수치**뿐.

## 조사 방법

워치 배포 터널이 불안정해서, **iOS 앱에서 HealthKit을 직접 조회**하는 일회성 진단을 사용 (아이폰 케이블 배포 = 안정). 이미 저장된 워크아웃들을 읽어 속성을 비교하고, `HKWorkoutBuilder`로 테스트 워크아웃을 만들어 A/B 검증.

진단 항목: `statistics(for: .activeEnergyBurned)`(연결된 활동 에너지), `totalEnergyBurned`, `metadata` 키 목록, `HKMetadataKeyIndoorWorkout`, `workoutActivities.count`, `sourceRevision.source.name`.

## 검증 단계와 결과 (가설 → 반증)

1. **"활동 에너지가 워크아웃에 연결 안 됨"** 가설
   → 반증. 우리 1,179kcal 워크아웃의 `active(연결)=1179.76`, `totalEnergyBurned=1179.76`. **에너지는 정상 연결돼 있음.**

2. **`HKAverageMETs` 메타데이터가 트리거** 가설 (Apple 워크아웃엔 있고 우리 건 없음)
   → 반증. METs만 넣은 테스트 워크아웃 생성 → 목록은 여전히 시간(`0:30`). 로그로 `meta=[HKAverageMETs,HKIndoorWorkout]` 부착 확인됨에도 불변.

3. **나머지 메타데이터(`HKTimeZone`, `HKWeatherHumidity`, `HKWeatherTemperature`)까지 전부 추가**
   → 반증. 테스트 워크아웃 메타데이터를 Apple과 **완전히 동일**하게 맞춤(5종 전부). 그래도 목록은 시간(`0:30`).

4. **`HKWorkoutActivity` 구조 차이(iOS 17+)** 가설
   → 반증. 우리 진짜 워치 워크아웃 `acts=1`, Apple 워크아웃 `acts=1`. **구조도 동일.**

## 최종 비교 (모든 제어 가능 속성 일치)

| 속성 | Ralli | Apple Watch | 일치 |
|--|--|--|--|
| active 에너지 연결 | ✅ | ✅ | 같음 |
| totalEnergyBurned | ✅ | ✅ | 같음 |
| activityType / indoor | tennis / false | tennis / false | 같음 |
| 메타데이터 5종 (테스트로 동일화) | ✅ | ✅ | 같음 |
| workoutActivities | 1 | 1 | 같음 |
| **sourceRevision (출처 앱)** | **Ralli** | **Apple Watch(시스템)** | **다름 — 유일** |

결정적 추가 근거: Apple의 **66초 / 3.6kcal** 테니스 워크아웃도 목록엔 **kcal로** 표시됨. 칼로리 양·시간과 무관하게 **출처로만** 갈림.

## 결론

**피트니스 목록의 헤드라인 수치(시간 vs kcal)는 워크아웃의 "출처"에 따라 Apple이 결정한다.** Apple 자체 운동 앱(시스템) 워크아웃은 kcal, third-party 앱 워크아웃은 시간. 데이터/메타데이터/구조를 Apple과 100% 동일하게 맞춰도 바뀌지 않으므로 **앱 코드로 수정 불가능한 Apple 측 동작**으로 확정.

- Apple 개발자 포럼(thread 679835)도 동일 증상에 "매칭되는 공식 API/메타데이터 키를 못 찾았다 = 비공개 동작"이라 결론. 본 조사로 **메타데이터·구조가 아님을 실증**하여 그 결론을 보강함.
- 포럼의 "kcal로 뜨는 third-party 앱도 있다"는 주장은, 사실이라면 구버전 iOS이거나 오인일 가능성. 현재 iOS에서 쿼리 가능한 모든 속성을 매칭했음에도 재현 불가.

## 영향 / 후속

- **기능 손실 없음**: 칼로리는 정상 기록되어 워크아웃 상세·무브링·활동 링에 모두 반영됨. 목록 헤드라인만 시간으로 표시되는 표시상의 차이.
- **조치**: 진단 코드는 전부 되돌림(커밋 없음). 향후 동일 시도 금지 — 본 문서가 근거.
- 원한다면 Apple Feedback Assistant로 enhancement 요청 가능.
- 테스트로 생성한 워크아웃 2개는 건강/피트니스 앱에서 수동 삭제.

## 참고

- [Apple Developer Forums — thread 679835 (Fitness 목록이 calories 대신 duration 표시)](https://developer.apple.com/forums/thread/679835)
