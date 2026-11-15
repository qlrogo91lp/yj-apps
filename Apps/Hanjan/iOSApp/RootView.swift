import Combine
import SwiftUI

struct RootView: View {
    @ObservedObject var store: PhoneSessionStore
    @ObservedObject var settings: AppSettings
    var onActive: () -> Void = {}
    @ObservedObject private var review = ReviewRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if settings.hasOnboarded {
                TabView(selection: $selectedTab) {
                    HomeView(store: store, settings: settings, onRecords: { selectedTab = 1 }, onSettings: { selectedTab = 2 })
                        .tabItem { Label("홈", systemImage: "house") }.tag(0)
                    RecordsView().tabItem { Label("기록", systemImage: "calendar") }.tag(1)
                    SettingsView(limit: $settings.limit, alertsEnabled: $settings.alertsEnabled, onKindsChanged: store.pushConfig)
                        .tabItem { Label("설정", systemImage: "gearshape") }.tag(2)
                }.tint(BrandColor.amber)
            } else {
                OnboardingView { limit in
                    settings.limit = limit; settings.hasOnboarded = true; store.pushConfig()
                }
            }
        }
        .sheet(isPresented: Binding(get: { review.sessionId != nil }, set: { if !$0 { review.sessionId = nil } })) {
            if let id = review.sessionId { ReviewFormView(sessionId: id) { review.sessionId = nil } }
        }
        .onChange(of: settings.limit) { _, _ in store.pushConfig() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.tick(); onActive() } }
        .onReceive(timer) { _ in if scenePhase == .active { store.tick() } }
        .onAppear { store.tick() }
    }
}
