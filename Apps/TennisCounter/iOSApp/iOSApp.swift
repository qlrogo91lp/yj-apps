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
    var body: some View {
        TabView {
            SummaryView()
                .tabItem {
                    Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                }

            HomeView()
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }

            HistoryView()
                .tabItem {
                    Label(String(localized: "tab_history"), systemImage: "clock.fill")
                }
        }
    }
}
