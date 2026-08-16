import SwiftData
import SwiftUI

/// 라운드 상세. 시트가 아니라 push로 띄운다 — 스코어카드가 최대 18행이고
/// 그 위에 홀 편집 시트를 또 올려야 하기 때문이다 (spec §4).
struct RoundDetailView: View {
    @Bindable var round: GolfRound
    @Environment(\.modelContext) private var modelContext
    @State private var courseNameDraft = ""

    var body: some View {
        List {
            summarySection
            courseSection
            scorecardSection
            workoutSection
        }
        .navigationTitle("라운드 상세")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { courseNameDraft = round.courseName ?? "" }
        .onDisappear(perform: commitCourseName)
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 6) {
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                Text("\(round.totalStrokes)타 · \(round.totalPutts)퍼트")
                    .font(.headline)
                Text(round.startedAt.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    /// MapKit 자동 감지가 붙기 전(plan ⑧)까지 골프장명을 채우는 유일한 경로다 (spec §1).
    private var courseSection: some View {
        Section("골프장") {
            TextField("골프장명 입력", text: $courseNameDraft)
                .onSubmit(commitCourseName)
        }
    }

    private var scorecardSection: some View {
        Section("스코어카드") {
            ForEach(Array(round.holeScores.indices), id: \.self) { index in
                HoleRow(holeNumber: index + 1,
                        par: value(in: round.holePars, at: index),
                        score: value(in: round.holeScores, at: index),
                        putts: value(in: round.puttCounts, at: index))
            }

            HStack {
                Text("합계").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(round.totalStrokes)타 · \(round.totalPutts)퍼트")
                    .font(.subheadline)
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var workoutSection: some View {
        Section("워크아웃") {
            WorkoutMetricsGrid(round: round)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    /// 배열 세 개는 병렬이지만 길이가 어긋난 과거 데이터가 있을 수 있어 방어적으로 읽는다.
    private func value(in array: [Int], at index: Int) -> Int {
        index < array.count ? array[index] : 0
    }

    /// 공백만 남기면 nil로 되돌린다 — "미입력"과 "공백 한 칸"을 다르게 저장하지 않는다 (spec §4).
    private func commitCourseName() {
        let trimmed = courseNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        round.courseName = trimmed.isEmpty ? nil : trimmed
        courseNameDraft = trimmed
        try? modelContext.save()
    }
}
