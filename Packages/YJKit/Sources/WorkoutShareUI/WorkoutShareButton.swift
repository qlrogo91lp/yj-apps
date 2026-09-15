#if os(iOS)
    import SwiftUI
    import UIKit
    import WorkoutCore

    /// 공유 버튼을 어디에 두느냐에 따른 배경 처리.
    public enum WorkoutShareButtonAppearance {
        /// 스스로 원형 배경을 그린다. 툴바가 아닌 자리(경기 결과 화면 등)에 둘 때.
        case standalone
        /// 아이콘만 그리고 배경은 **툴바에 맡긴다**. 직접 원을 그리면 iOS 26 유리 배경과 두 겹이 되고,
        /// 유리를 끄면 옆의 기본 버튼들과 질감이 달라진다.
        case toolbar
    }

    /// 워크아웃 결과 카드를 내보내는 버튼. 누르면 메뉴가 뜬다 — 공유 시트, 또는 스티커로 복사.
    ///
    /// 공유 시트로 넘긴 사진에는 인스타가 배경을 붙인다. 배경 없는 스티커는 클립보드에 넣고
    /// 스토리에서 붙여넣는 경로로만 된다 (딥링크는 Meta App ID 가 필요해 걷어냈다).
    public struct WorkoutShareButton: View {
        private let result: WorkoutResult
        private let header: WorkoutShareHeader
        private let style: WorkoutShareStyle
        private let appearance: WorkoutShareButtonAppearance

        @State private var shared: SharedFile?
        @State private var showCopied = false

        public init(result: WorkoutResult,
                    header: WorkoutShareHeader,
                    style: WorkoutShareStyle,
                    appearance: WorkoutShareButtonAppearance = .standalone)
        {
            self.result = result
            self.header = header
            self.style = style
            self.appearance = appearance
        }

        public var body: some View {
            Menu {
                Button {
                    share()
                } label: {
                    Label(String(localized: "share_menu_share", bundle: .module),
                          systemImage: "square.and.arrow.up")
                }
                Button {
                    copySticker()
                } label: {
                    Label(String(localized: "share_menu_copy_sticker", bundle: .module),
                          systemImage: "doc.on.doc")
                }
            } label: {
                // 피트니스 앱 우상단 공유 버튼과 같은 모양 — 아이콘만. 글자는 VoiceOver 로만 읽힌다.
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .offset(y: -1) // 화살표 획 때문에 아이콘이 아래로 쏠려 보인다
                    .accessibilityLabel(String(localized: "share_button", bundle: .module))
            }
            .modifier(ShareButtonBackground(appearance: appearance))
            .sheet(item: $shared) { ShareSheet(fileURL: $0.url) }
            .alert(String(localized: "share_copied_title", bundle: .module), isPresented: $showCopied) {
                Button(String(localized: "share_copied_ok", bundle: .module)) {}
            } message: {
                Text(String(localized: "share_copied_message", bundle: .module))
            }
        }

        @MainActor
        private func renderCard(corners: ShareCardCorners) -> UIImage? {
            WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: result, header: header),
                                       style: style,
                                       corners: corners)
        }

        /// 공유 시트로 받은 사진은 인스타가 투명을 검정으로 채운다 — 네모로 굽는다.
        @MainActor
        private func share() {
            guard let image = renderCard(corners: .square),
                  let url = WorkoutShareExport.pngFile(from: image) else { return }
            shared = SharedFile(url: url)
        }

        /// 스티커층은 투명을 그대로 붙인다 — 둥근 모서리로 굽는다.
        @MainActor
        private func copySticker() {
            guard let image = renderCard(corners: .rounded),
                  WorkoutShareExport.copySticker(image) else { return }
            showCopied = true
        }
    }

    /// 툴바에서는 배경을 시스템이 그리고, 그 밖에서는 버튼이 직접 원을 그린다.
    private struct ShareButtonBackground: ViewModifier {
        let appearance: WorkoutShareButtonAppearance

        func body(content: Content) -> some View {
            switch appearance {
            case .toolbar:
                content.foregroundStyle(.primary)
            case .standalone:
                if #available(iOS 26.0, *) {
                    content
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                } else {
                    content
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(white: 0.17)))
                        .contentShape(Circle())
                }
            }
        }
    }

    private struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    #Preview {
        WorkoutShareButton(
            result: WorkoutResult(durationSeconds: 9351, caloriesBurned: 1343,
                                  averageHeartRate: 136, totalCaloriesBurned: 1584),
            header: WorkoutShareHeader(title: "테니스", startedAt: Date().addingTimeInterval(-9351), endedAt: Date()),
            style: WorkoutShareStyle(badgeColor: .green, logo: Image(systemName: "tennisball"))
        )
    }
#endif
