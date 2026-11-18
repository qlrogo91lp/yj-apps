import SwiftData
import SwiftUI

/// 기록 목록. 달별로 묶고 최신부터. 줄을 누르면 상세로 간다 (`navigationDestination(for: UUID.self)` 는 `RecordsView` 가 건다).
struct RecordListView: View {
    let sections: [RecordsViewModel.MonthSection]

    var body: some View {
        if sections.isEmpty {
            VStack(spacing: 8) {
                Text("아직 기록이 없어요")
                    .font(.system(size: 17, weight: .semibold))
                Text("술자리를 끝내면 여기에 남아요.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(sections) { section in
                        Text(RecordFormat.month(section.month))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                            .padding(.leading, 4)
                        ForEach(section.sessions) { session in
                            NavigationLink(value: session.id) {
                                RecordRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    let container = RecordsPreviewData.container()
    let sessions = (try? container.mainContext.fetch(FetchDescriptor<SessionRecord>())) ?? []
    return NavigationStack {
        RecordListView(sections: RecordsViewModel().sections(sessions))
            .background(BrandColor.background)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}

#Preview("빈 목록") {
    RecordListView(sections: [])
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
