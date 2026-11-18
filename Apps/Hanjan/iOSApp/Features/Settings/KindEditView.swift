import SwiftUI

/// 술 추가·편집. 이름 · 도수 · 한 잔 용량과 "소주 약 N잔" 미리보기.
/// 저장은 호출부가 검사·반영하고 결과를 돌려준다 — 실패하면 그 안내를 이 화면에 보인다.
struct KindEditView: View {
    let kind: DrinkKind?
    let onCancel: () -> Void
    let onSave: (_ name: String, _ abv: Double, _ volumeML: Double) -> Result<Void, KindValidationError>

    @State private var name: String
    @State private var abv: Double?
    @State private var volumeML: Double?
    @State private var error: KindValidationError?

    init(
        kind: DrinkKind?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ name: String, _ abv: Double, _ volumeML: Double) -> Result<Void, KindValidationError>
    ) {
        self.kind = kind
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: kind?.name ?? "")
        _abv = State(initialValue: kind?.abv)
        _volumeML = State(initialValue: kind?.volumeML)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름", text: $name)
                    numberField("도수", value: $abv, unit: "%")
                    numberField("한 잔 용량", value: $volumeML, unit: "ml")
                } footer: {
                    if let error {
                        Text(error.message)
                            .foregroundStyle(BrandColor.danger)
                    }
                }
                .listRowBackground(BrandColor.surface)

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("소주 환산 미리보기")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("한 잔당 소주 약 \(SettingsViewModel.sojuPreview(abv: abv ?? 0, volumeML: volumeML ?? 0))잔")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(BrandColor.amber)
                        Text(
                            "소주 \(KindListView.number(DrinkPresets.soju.abv))% · \(KindListView.number(DrinkPresets.soju.volumeML))ml 기준"
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(BrandColor.surface)
            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.background)
            .navigationTitle(kind == nil ? "술 추가" : "술 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(BrandColor.amber)
    }

    private func numberField(_ title: String, value: Binding<Double?>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        if case let .failure(failure) = onSave(name, abv ?? 0, volumeML ?? 0) {
            error = failure
        }
    }
}

#Preview("추가") {
    KindEditView(kind: nil, onCancel: {}, onSave: { _, _, _ in .failure(.emptyName) })
        .preferredColorScheme(.dark)
}

#Preview("편집") {
    KindEditView(kind: DrinkPresets.soju, onCancel: {}, onSave: { _, _, _ in .success(()) })
        .preferredColorScheme(.dark)
}
