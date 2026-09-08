import SwiftUI

/// 경기 한 줄 — 승/패 + 세트별 게임 스코어 ("6-4 4-6 6-3").
///
/// 세트 합계(`2-1`)는 넣지 않는다. 세트 스코어를 보면 나오는 값이다.
///
/// **탭·스와이프를 스스로 처리하지 않는다.** 조립하는 쪽이 `.onTapGesture` /
/// `.swipeActions` 를 붙인다.
struct MatchRow: View {
    let match: Match

    private var didWin: Bool {
        match.myTotalSets > match.yourTotalSets
    }

    private var sets: [SetRecord] {
        (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(didWin ? .green : .orange)

            HStack(spacing: 8) {
                ForEach(sets, id: \.setNumber) { set in
                    setScore(set)
                }
            }
            .font(.system(size: 15))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 내가 이긴 세트의 숫자만 굵게. 색을 더 쓰면 목록이 시끄러워진다.
    private func setScore(_ set: SetRecord) -> some View {
        let iTook = set.myGames > set.yourGames
        return Text(verbatim: "\(set.myGames)").fontWeight(iTook ? .bold : .regular)
            + Text(verbatim: "-")
            + Text(verbatim: "\(set.yourGames)").fontWeight(iTook ? .regular : .bold)
    }
}

#Preview {
    func match(_ scores: [(Int, Int)]?, mySets: Int, yourSets: Int) -> Match {
        let match = Match()
        match.myTotalSets = mySets
        match.yourTotalSets = yourSets
        match.sets = scores?.enumerated().map { index, score in
            SetRecord(myGames: score.0, yourGames: score.1, setNumber: index + 1)
        }
        return match
    }

    return VStack(alignment: .leading, spacing: 16) {
        MatchRow(match: match([(6, 4), (4, 6), (6, 3)], mySets: 2, yourSets: 1))
        MatchRow(match: match([(4, 6)], mySets: 0, yourSets: 1))
        MatchRow(match: match(nil, mySets: 1, yourSets: 0))
    }
    .padding()
    .background(.black)
}
