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

            NavigationStack {
                Text("Match")
            }
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
