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
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Match.self, SetRecord.self])
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
