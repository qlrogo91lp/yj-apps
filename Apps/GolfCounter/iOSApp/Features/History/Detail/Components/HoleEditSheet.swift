import SwiftUI

/// 홀 하나를 정정하는 시트. 워치 오입력의 최종 구제 지점이다 (spec §4).
/// 불변식은 전부 `RoundEditViewModel`이 강제하므로 이 뷰는 상태를 그리기만 한다 —
/// 위반 입력을 만들 수 있는 컨트롤 자체가 없다.
struct HoleEditSheet: View {
    let holeNumber: Int
    let onSave: (RoundEditViewModel) -> Void

    @State private var model: RoundEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(holeNumber: Int,
         par: Int,
         score: Int,
         putts: Int,
         onSave: @escaping (RoundEditViewModel) -> Void)
    {
        self.holeNumber = holeNumber
        self.onSave = onSave
        _model = State(initialValue: RoundEditViewModel(par: par, score: score, putts: putts))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Par") {
                    Picker("Par", selection: parBinding) {
                        ForEach(RoundEditViewModel.parOptions, id: \.self) { par in
                            Text("\(par)").tag(par)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("타수") {
                    Stepper("\(model.score)타",
                            onIncrement: { model.incrementScore() },
                            onDecrement: model.canDecrementScore ? { model.decrementScore() } : nil)
                }

                Section("퍼팅") {
                    Stepper("\(model.putts)퍼트",
                            onIncrement: { model.incrementPutts() },
                            onDecrement: model.canDecrementPutts ? { model.decrementPutts() } : nil)
                }
            }
            .navigationTitle("H\(holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(model)
                        dismiss()
                    }
                    .disabled(!model.isSaveable)
                }
            }
        }
    }

    private var parBinding: Binding<Int> {
        Binding(get: { model.par },
                set: { model.setPar($0) })
    }
}
