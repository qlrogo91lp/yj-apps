import SwiftData
import SwiftUI

/// 설정 탭. 한도 · 술 목록 · 알림. `AppSettings` 를 직접 알지 않는다 — T9 가 바인딩과 콜백을 잇는다.
/// `onKindsChanged` 는 술을 추가·편집·삭제할 때마다 불린다 (워치로 `ConfigMessage` 를 다시 보내는 자리).
struct SettingsView: View {
    @Binding var limit: Double
    @Binding var alertsEnabled: Bool
    let onKindsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()

    private var limitBinding: Binding<Double> {
        Binding(get: { limit }, set: { limit = SettingsViewModel.clampLimit($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: limitBinding, in: SettingsViewModel.limitRange, step: SettingsViewModel.limitStep) {
                        HStack {
                            Text("평소 주량")
                            Spacer()
                            Text("소주 \(SojuFormat.string(limit))잔")
                                .monospacedDigit()
                                .foregroundStyle(BrandColor.amber)
                        }
                    }
                    NavigationLink("술 목록 편집") {
                        KindListView(viewModel: viewModel, onKindsChanged: onKindsChanged)
                    }
                } header: {
                    Text("나의 기준")
                } footer: {
                    Text("한도의 80%와 100%에 이르면 알려 드려요. 넘어도 기록은 계속할 수 있어요.")
                }
                .listRowBackground(BrandColor.surface)

                Section {
                    Toggle("알림", isOn: $alertsEnabled)
                        .tint(BrandColor.amber)
                } header: {
                    Text("알림")
                } footer: {
                    Text("한도 80% · 한도 도달 알림과 다음 날 회고 알림을 함께 켜고 끕니다.")
                }
                .listRowBackground(BrandColor.surface)

                Section {} footer: {
                    Text("3시간 동안 입력이 없으면 술자리가 자동으로 종료돼요.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.background)
            .navigationTitle("설정")
        }
        .tint(BrandColor.amber)
        .onAppear { viewModel.configure(context: modelContext) }
    }
}

#if DEBUG
    private struct SettingsPreview: View {
        @State private var limit = 8.0
        @State private var alertsEnabled = true

        var body: some View {
            SettingsView(limit: $limit, alertsEnabled: $alertsEnabled, onKindsChanged: {})
        }
    }

    #Preview {
        SettingsPreview()
            .modelContainer(SettingsPreviewData.container())
            .preferredColorScheme(.dark)
    }
#endif
