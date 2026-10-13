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
                    DatePicker("manual_when", selection: $viewModel.draft.startedAt,
                               in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Text("manual_how_long")
                        Spacer()
                        TextField("manual_minutes_unit", value: $viewModel.draft.durationMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                        Text("manual_minutes_unit")
                    }
                } footer: {
                    Text("manual_start_hint")
                }

                Section("manual_kind") {
                    Picker("manual_kind", selection: $viewModel.draft.kind) {
                        ForEach(SegmentKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("manual_body_parts_optional") {
                    BodyPartChips(selected: BodyPart.allCases.filter(viewModel.draft.bodyParts.contains),
                                  onToggle: viewModel.toggle)
                        .padding(.vertical, 4)
                }

                Section("manual_memo_optional") {
                    TextField("detail_memo_placeholder", text: $viewModel.draft.memo, axis: .vertical)
                        .lineLimit(3 ... 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HaruchiPalette.bg)
            .navigationTitle(viewModel.record == nil ? LocalizedStringKey("manual_title_add") : LocalizedStringKey("manual_title_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("btn_cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("btn_save", action: save) }
            }
            .alert("manual_error_title", isPresented: Binding(get: { errorMessage != nil },
                                                              set: { if !$0 { errorMessage = nil } }))
            {
                Button("btn_ok", role: .cancel) {}
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
            errorMessage = String(localized: "manual_error_duration")
        } catch ManualRecordDraft.ValidationError.endsInFuture {
            errorMessage = String(localized: "manual_error_future")
        } catch {
            errorMessage = String(localized: "manual_error_save")
        }
    }
}
