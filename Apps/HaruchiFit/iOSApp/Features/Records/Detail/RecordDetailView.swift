import SwiftData
import SwiftUI

struct RecordDetailView: View {
    @StateObject private var viewModel: RecordDetailViewModel
    @FocusState private var memoFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsMemoSaved = false
    @State private var detent: PresentationDetent = .medium
    @State private var confirmingDelete = false
    @State private var failure: AppAlert?
    private let onDismissCommit: (String?) -> Void
    private let onDelete: () -> Void
    private let onEdit: () -> Void

    /// 시트가 닫힐 때 메모 저장이 실패하면 `onDismissCommit`으로 초안을 돌려준다.
    /// 표시하는 쪽은 초안을 보관했다가 같은 기록을 다시 열 때 `initialMemoDraft`로 넘겨준다.
    init(record: WorkoutRecord,
         context: ModelContext,
         initialMemoDraft: String?,
         onDismissCommit: @escaping (String?) -> Void,
         onDelete: @escaping () -> Void,
         onEdit: @escaping () -> Void)
    {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(record: record,
                                                                     context: context,
                                                                     initialMemoDraft: initialMemoDraft))
        self.onDismissCommit = onDismissCommit
        self.onDelete = onDelete
        self.onEdit = onEdit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(viewModel.summary.dateTitle).font(.title3.bold())
                        Text(viewModel.summary.timeRangeTitle).foregroundStyle(HaruchiPalette.dim)
                    }
                    Spacer()
                    RecordShareButton(content: viewModel.shareContent)
                }
                HStack { stat(viewModel.summary.durationText, Text("detail_total_time")); stat(
                    viewModel.summary.caloriesText,
                    Text(verbatim: "kcal")
                ); stat(
                    viewModel.summary.heartRateText,
                    Text("detail_avg_heart_rate")
                ) }
                if !viewModel.summary.spans
                    .isEmpty
                {
                    VStack(alignment: .leading) {
                        Text("detail_composition"); SegmentTimelineBar(spans: viewModel.summary.spans)
                        if !viewModel.summary.compositionChips.isEmpty { CompositionCaption(chips: viewModel.summary.compositionChips) }
                    }
                }
                Divider().overlay(HaruchiPalette.line)
                VStack(alignment: .leading) {
                    Text("detail_body_parts"); BodyPartChips(selected: viewModel.bodyParts) { if !viewModel.toggle($0) { failure = .editFailed } }
                }
                VStack(alignment: .leading) {
                    HStack { Text("detail_memo"); Spacer(); memoAccessory }; TextField(
                        "detail_memo_placeholder",
                        text: $viewModel.memoDraft,
                        axis: .vertical
                    ).lineLimit(3 ... 8).focused($memoFocused).padding(12).background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    Button("btn_delete", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity).buttonStyle(.bordered).tint(HaruchiPalette.hr)
                    if viewModel.isManual {
                        Button("btn_edit", action: onEdit)
                            .frame(maxWidth: .infinity).buttonStyle(.borderedProminent)
                    }
                }
            }.padding(20)
        }
        .presentationDetents([.medium, .large], selection: $detent).presentationDragIndicator(.visible).presentationBackground(HaruchiPalette.bg)
        .onChange(of: memoFocused) { _, focused in if focused { detent = .large } else { commitMemo() } }
        // 연달아 저장되면 앞의 타이머는 취소되고 1.5초를 새로 센다
        .task(id: viewModel.memoSaveCount) { await flashMemoSaved() }
        .onDisappear {
            onDismissCommit(viewModel.commitMemo() ? nil : viewModel.memoDraft)
        }
        .confirmationDialog("records_delete_confirm", isPresented: $confirmingDelete) {
            Button("btn_delete", role: .destructive) { onDelete() }; Button(
                "btn_cancel",
                role: .cancel
            ) {}
        } message: {
            Text(viewModel.isManual ? LocalizedStringKey("records_delete_note_manual") : LocalizedStringKey("records_delete_note_health"))
        }
        .alert(failure?.title ?? "", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure) { _ in
            Button(
                "btn_ok",
                role: .cancel
            ) {}
        } message: { Text($0.message) }
    }

    private func stat(_ value: String,
                      _ caption: Text)
        -> some View
    {
        VStack { Text(value).font(.title2.monospacedDigit()); caption.font(.caption).foregroundStyle(HaruchiPalette.dim) }
            .frame(maxWidth: .infinity).padding(
                .vertical,
                12
            ).background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 입력 중에는 `완료`, 저장 직후 잠깐은 `저장됨`.
    @ViewBuilder private var memoAccessory: some View {
        if memoFocused {
            Button("btn_done") { memoFocused = false }
        } else if showsMemoSaved {
            Label("detail_memo_saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(HaruchiPalette.accent)
                .transition(.opacity)
        }
    }

    private func flashMemoSaved() async {
        guard viewModel.memoSaveCount > 0 else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsMemoSaved = true }
        AccessibilityNotification.Announcement(String(localized: "detail_memo_saved")).post()
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { showsMemoSaved = false }
    }

    private func commitMemo() {
        if !viewModel.commitMemo() { failure = .editFailed }
    }
}
