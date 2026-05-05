import SwiftUI

struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var flowViewModel: WorkoutFlowViewModel
    @State private var saved = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Result header
                Text(resultTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(resultColor)
                    .multilineTextAlignment(.center)

                // Set score
                HStack(spacing: 8) {
                    Text("\(session.mySetScore)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.green)
                    Text("-")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(session.yourSetScore)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.orange)
                }

                // Completed sets detail
                if !session.completedSets.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(session.completedSets.enumerated()), id: \.offset) { _, set in
                            Text("\(set.my)-\(set.your)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // Save button
                Button(action: saveMatch) {
                    HStack(spacing: 6) {
                        Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        Text(saved ? String(localized: "result_saved") : String(localized: "result_save"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(saved ? .gray : .blue)
                .disabled(saved)

                // New Match button
                Button(action: { flowViewModel.startNewMatch() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(String(localized: "watch_new_match"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
    }

    private var resultTitle: String {
        switch session.result {
        case .win: return String(localized: "watch_victory")
        case .loss: return String(localized: "watch_defeat")
        case .draw: return String(localized: "result_draw")
        case nil: return ""
        }
    }

    private var resultColor: Color {
        switch session.result {
        case .win: return .green
        case .loss: return .orange
        case .draw: return .yellow
        case nil: return .white
        }
    }

    private func saveMatch() {
        do {
            try flowViewModel.saveCurrentMatch()
            withAnimation { saved = true }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
