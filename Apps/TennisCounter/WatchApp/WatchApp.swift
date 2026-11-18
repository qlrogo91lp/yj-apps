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
        // 앱 수명 내내 살아 있어야 운동 화면이 없을 때도 보관된 경기를 다시 보낸다.
        MatchSaveOutbox.shared.bind(to: .shared)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
