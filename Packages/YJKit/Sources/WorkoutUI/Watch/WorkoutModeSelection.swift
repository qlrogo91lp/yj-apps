#if os(watchOS)
    import SwiftUI

    /// 컨트롤 화면 전환 행의 항목 하나.
    ///
    /// 패키지는 이 항목이 **무엇인지 모른다** — 근력·유산소든 다른 무엇이든 제목과 색을
    /// 앱이 정해서 넘긴다. 코어가 도메인을 모르게 하려는 것이다.
    public struct WorkoutModeOption: Identifiable, Sendable {
        public let id: Int
        public let title: String
        public let tint: Color

        public init(id: Int, title: String, tint: Color) {
            self.id = id
            self.title = title
            self.tint = tint
        }
    }

    /// `WorkoutControlsView` 에 전환 행을 붙이는 설정.
    ///
    /// 개별 인자를 흩뿌리지 않고 하나로 묶는다 — 항목을 늘릴 때 뷰 시그니처가 다시 바뀌지 않는다.
    public struct WorkoutModeSelection {
        public let options: [WorkoutModeOption]
        public let selectedID: Int
        public let onSelect: (Int) -> Void

        public init(options: [WorkoutModeOption], selectedID: Int, onSelect: @escaping (Int) -> Void) {
            self.options = options
            self.selectedID = selectedID
            self.onSelect = onSelect
        }
    }

    /// 전환 행. 활성 항목은 채운 배경, 비활성은 틴트만 남긴다.
    struct WorkoutModeRow: View {
        let selection: WorkoutModeSelection

        var body: some View {
            HStack(spacing: 6) {
                ForEach(selection.options) { option in
                    let isSelected = option.id == selection.selectedID
                    Button { selection.onSelect(option.id) } label: {
                        Text(option.title)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    // 비활성은 배경을 지우고 글자만 틴트로 남긴다 — 활성 하나만 채워져 보이게 한다.
                    .tint(isSelected ? option.tint : option.tint.opacity(0.2))
                    .foregroundStyle(isSelected ? Color.black : option.tint)
                }
            }
        }
    }
#endif
