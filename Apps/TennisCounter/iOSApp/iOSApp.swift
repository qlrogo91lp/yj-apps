//
//  iOSApp.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Match.self, SetRecord.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Summary")
                .tabItem {
                    Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                }

            ModeSelectionView()
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }

            Text("History")
                .tabItem {
                    Label(String(localized: "tab_history"), systemImage: "clock.fill")
                }
        }
    }
}

// MARK: - ModeSelection

struct ModeSelectionView: View {
    @StateObject private var viewModel = ModeSelectionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                        NavigationLink(value: format) {
                            ModeCardView(format: format)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationDestination(for: MatchFormat.self) { format in
                MatchView(format: format)
            }
            .navigationBarHidden(true)
        }
    }
}

@MainActor
final class ModeSelectionViewModel: ObservableObject {
    @Published var selectedFormat: MatchFormat?

    func selectFormat(_ format: MatchFormat) {
        selectedFormat = format
    }
}

private struct ModeCardView: View {
    let format: MatchFormat

    private var title: String {
        format == .oneSet ? String(localized: "match_format_one_set") : String(localized: "match_format_best_of_3")
    }

    private var description: String {
        format == .oneSet ? String(localized: "match_format_one_set_desc") : String(localized: "match_format_best_of_3_desc")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
