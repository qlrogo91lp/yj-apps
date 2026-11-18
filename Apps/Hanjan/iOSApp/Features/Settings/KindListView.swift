import SwiftData
import SwiftUI

/// 술 목록 편집. 프리셋은 고치기만, 사용자가 추가한 술은 밀어서 지운다.
struct KindListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onKindsChanged: () -> Void

    /// 편집 시트 대상. 새 술이면 `kind == nil`.
    private struct EditTarget: Identifiable {
        let id = UUID()
        let kind: DrinkKind?
    }

    @State private var editing: EditTarget?

    var body: some View {
        List {
            Section {
                ForEach(viewModel.kinds) { kind in
                    Button {
                        editing = EditTarget(kind: kind)
                    } label: {
                        row(kind)
                    }
                    .deleteDisabled(kind.isPreset)
                }
                .onDelete(perform: delete)
            } footer: {
                Text("기본 술은 지울 수 없고 고치기만 할 수 있어요. 지난 기록의 잔 수는 바뀌지 않아요.")
            }
            .listRowBackground(BrandColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(BrandColor.background)
        .navigationTitle("술 목록")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("직접 추가") { editing = EditTarget(kind: nil) }
            }
        }
        .sheet(item: $editing) { target in
            KindEditView(kind: target.kind, onCancel: { editing = nil }, onSave: { name, abv, volumeML in
                let result = viewModel.save(id: target.kind?.id, name: name, abv: abv, volumeML: volumeML)
                if case .success = result {
                    editing = nil
                    onKindsChanged()
                }
                return result
            })
        }
        .onAppear { viewModel.reload() }
    }

    private func row(_ kind: DrinkKind) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.name)
                    .foregroundStyle(.primary)
                Text("\(Self.number(kind.abv))% · \(Self.number(kind.volumeML))ml")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("소주 약 \(SettingsViewModel.sojuPreview(abv: kind.abv, volumeML: kind.volumeML))잔")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { viewModel.kinds[$0].id }
        let deleted = ids.map { viewModel.delete(id: $0) }.contains(true)
        if deleted { onKindsChanged() }
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }
}

#if DEBUG
    private struct KindListPreview: View {
        @Environment(\.modelContext) private var modelContext
        @StateObject private var viewModel = SettingsViewModel()

        var body: some View {
            NavigationStack {
                KindListView(viewModel: viewModel, onKindsChanged: {})
            }
            .onAppear { viewModel.configure(context: modelContext) }
        }
    }

    #Preview {
        KindListPreview()
            .modelContainer(SettingsPreviewData.container())
            .preferredColorScheme(.dark)
    }
#endif
