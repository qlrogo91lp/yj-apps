import SwiftUI

/// 스파이크 전용 임시 화면. **검증이 끝나면 이 파일을 삭제한다.**
/// 디자인은 신경 쓰지 않는다 — 누를 수 있고 로그가 보이면 된다.
struct SpikeView: View {
    @StateObject private var spike = SegmentSpike()

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // 각 단계를 1분 이상 유지해야 한다 — 짧은 구간은 HealthKit 이 버릴 수 있다.
                Text(spike.isRunning ? "\(spike.elapsed)초" : "대기")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(spike.isRunning ? Color.green : Color.secondary)

                Button("시작(근력)") { spike.start() }
                Button("유산소 구간") { spike.beginCardio() }
                Button("근력 구간") { spike.beginStrength() }
                Button("구간 종료") { spike.endCurrentActivity() }
                Button("세션 종료") { Task { await spike.end() } }
                    .tint(.red)

                Divider()

                ForEach(spike.log, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
