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
    private let watchConnectivity = WatchConnectivityService.shared
    @State private var isLaunching = true

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
            if isLaunching {
                LaunchScreenView(onFinished: { isLaunching = false })
            } else {
                MainTabView()
            }
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    @State private var isMatchActive = false
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SummaryView()
                    .tabItem {
                        Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                    }
                    .tag(0)

                HomeView(onMatchStart: { withAnimation { isMatchActive = true } })
                    .tabItem {
                        Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                    }
                    .tag(1)

                HistoryView()
                    .tabItem {
                        Label(String(localized: "tab_history"), systemImage: "clock.fill")
                    }
                    .tag(2)
            }

            if isMatchActive {
                NavigationStack {
                    WorkoutSessionView(onExit: {
                        selectedTab = 1
                        withAnimation { isMatchActive = false }
                    })
                }
                .transition(.opacity)
            }
        }
    }
}
