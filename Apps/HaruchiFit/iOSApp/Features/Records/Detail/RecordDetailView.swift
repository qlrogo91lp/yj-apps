import SwiftData
import SwiftUI

struct RecordDetailView: View {
    @StateObject private var viewModel: RecordDetailViewModel
    @FocusState private var memoFocused: Bool
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
                VStack(alignment: .leading) {
                    Text(viewModel.summary.dateTitle).font(.title3.bold()); Text(viewModel.summary.timeRangeTitle)
                        .foregroundStyle(HaruchiPalette.dim)
                }
                HStack { stat(viewModel.summary.durationText, "총 시간"); stat(viewModel.summary.caloriesText, "kcal"); stat(
                    viewModel.summary.heartRateText,
                    "평균 심박"
                ) }
                if !viewModel.summary.spans
                    .isEmpty
                {
                    VStack(alignment: .leading) {
                        Text("운동 구성"); SegmentTimelineBar(spans: viewModel.summary.spans); if let text = viewModel.summary
                            .compositionText { Text(text).foregroundStyle(HaruchiPalette.dim) }
                    }
                }
                Divider().overlay(HaruchiPalette.line)
                VStack(alignment: .leading) {
                    Text("부위"); BodyPartChips(selected: viewModel.bodyParts) { if !viewModel.toggle($0) { failure = .editFailed } }
                }
                VStack(alignment: .leading) { HStack { Text("메모"); Spacer(); if memoFocused { Button("완료") { memoFocused = false } } }; TextField(
                    "메모 추가하기…",
                    text: $viewModel.memoDraft,
                    axis: .vertical
                ).lineLimit(3 ... 8).focused($memoFocused).padding(12).background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12)) }
                HStack {
                    Button("삭제", role: .destructive) { confirmingDelete = true }
                        .frame(maxWidth: .infinity).buttonStyle(.bordered).tint(HaruchiPalette.hr)
                    if viewModel.isManual {
                        Button("편집", action: onEdit)
                            .frame(maxWidth: .infinity).buttonStyle(.borderedProminent)
                    }
                }
            }.padding(20)
        }
        .presentationDetents([.medium, .large], selection: $detent).presentationDragIndicator(.visible).presentationBackground(HaruchiPalette.bg)
        .onChange(of: memoFocused) { _, focused in if focused { detent = .large } else { commitMemo() } }
        .onDisappear {
            onDismissCommit(viewModel.commitMemo() ? nil : viewModel.memoDraft)
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete) { Button("삭제", role: .destructive) { onDelete() }; Button(
            "취소",
            role: .cancel
        ) {} } message: {
            Text(viewModel.isManual ? "삭제한 수동 기록은 복구할 수 없어요." : "건강 앱의 운동 기록은 그대로 남아요.")
        }
        .alert(failure?.title ?? "", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure) { _ in
            Button(
                "확인",
                role: .cancel
            ) {}
        } message: { Text($0.message) }
    }

    private func stat(_ value: String,
                      _ caption: String)
        -> some View
    {
        VStack { Text(value).font(.title2.monospacedDigit()); Text(caption).font(.caption).foregroundStyle(HaruchiPalette.dim) }
            .frame(maxWidth: .infinity).padding(
                .vertical,
                12
            ).background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func commitMemo() {
        if !viewModel.commitMemo() { failure = .editFailed }
    }
}
