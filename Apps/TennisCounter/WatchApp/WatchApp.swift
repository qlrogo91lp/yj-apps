//
//  WatchApp.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

@main
struct TennisCounter_Watch_AppApp: App {
    private let watchConnectivity = MatchConnectivity.shared

    init() {
        AppCrashReporter.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
