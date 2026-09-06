import SwiftData
import SwiftUI

/// 저장이 실제로 되는지 눈으로 확인하기 위한 최소 화면. **제품 화면이 아니다** —
/// 홈·기록 탭은 별도 플랜에서 만든다.
struct ContentView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("기록 없음",
                                           systemImage: "figure.strengthtraining.traditional",
                                           description: Text("워치에서 운동을 마치면 여기에 나타난다."))
                } else {
                    List(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text(summary(of: record))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !record.orderedSegments.isEmpty {
                                Text(segmentLine(of: record))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("하루치 핏")
        }
    }

    private func summary(of record: WorkoutRecord) -> String {
        var parts = ["\(record.totalSeconds / 60)분"]
        if let calories = record.activeCalories { parts.append("\(Int(calories)) kcal") }
        if let heartRate = record.averageHeartRate, heartRate > 0 {
            parts.append("♥ \(Int(heartRate))")
        }
        return parts.joined(separator: " · ")
    }

    private func segmentLine(of record: WorkoutRecord) -> String {
        record.orderedSegments
            .map { "\($0.kind.title) \($0.durationSeconds / 60)분" }
            .joined(separator: " → ")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutRecord.self, Segment.self], inMemory: true)
}
