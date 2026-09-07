/// 워치 세션의 단계. `.idle → .active → .summary → .idle` 한 바퀴가 세션 하나다.
///
/// 요약(`.summary`)이 낄 자리를 만들려고 `isActive` 불리언을 대체했다 —
/// 종료가 곧 저장이던 것을 여기서 끊는다 (W2).
enum SessionPhase {
    case idle
    case active
    case summary
}
