import AppIntents

struct RalliAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CopyLastWorkoutStickerIntent(), phrases: [
            "Copy last workout sticker in \(.applicationName)",
        ], shortTitle: "Copy Last Workout Sticker", systemImageName: "doc.on.doc")
    }
}
