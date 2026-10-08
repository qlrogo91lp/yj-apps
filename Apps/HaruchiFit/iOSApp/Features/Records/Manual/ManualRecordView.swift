import SwiftData
import SwiftUI

/// 생성과 수동 기록 편집이 공유하는 입력 폼.
struct ManualRecordView: View {
    @StateObject private var viewModel: ManualRecordViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    let onSaved: () -> Void

    init(record: WorkoutRecord? = nil,
         initialMemoDraft: String? = nil,
         onSaved: @escaping () -> Void)
    {
        _viewModel = StateObject(wrappedValue: ManualRecordViewModel(record: record, initialMemoDraft: initialMemoDraft))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("언제", selection: $viewModel.draft.startedAt,
                               in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Text("얼마나")
                        Spacer()
                        TextField("분", value: $viewModel.draft.durationMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                        Text("분")
                    }
                } footer: {
                    Text("운동을 시작한 날짜와 시각을 입력해 주세요.")
                }

                Section("유형") {
                    Picker("유형", selection: $viewModel.draft.kind) {
                        ForEach(SegmentKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("부위 · 선택") {
                    BodyPartChips(selected: BodyPart.allCases.filter(viewModel.draft.bodyParts.contains),
                                  onToggle: viewModel.toggle)
                        .padding(.vertical, 4)
                }

                Section("메모 · 선택") {
                    TextField("메모 추가하기…", text: $viewModel.draft.memo, axis: .vertical)
                        .lineLimit(3 ... 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HaruchiPalette.bg)
            .navigationTitle(viewModel.record == nil ? "수동 기록 추가" : "기록 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
            .alert("저장할 수 없어요", isPresented: Binding(get: { errorMessage != nil },
                                                     set: { if !$0 { errorMessage = nil } }))
            {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        do {
            try viewModel.save(using: ManualRecordStore(context: modelContext))
            onSaved()
            dismiss()
        } catch ManualRecordDraft.ValidationError.durationOutOfRange {
            errorMessage = "운동 시간은 1분부터 24시간까지 입력해 주세요."
        } catch ManualRecordDraft.ValidationError.endsInFuture {
            errorMessage = "운동이 끝난 시각이 현재보다 늦어요."
        } catch {
            errorMessage = "변경 내용을 저장하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}
