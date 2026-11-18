import AppIntents

struct RalliAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CopyLastWorkoutStickerIntent(), phrases: [
            "Copy last workout sticker in \(.applicationName)",
        ], shortTitle: "shortcut_copy_sticker_title", systemImageName: "doc.on.doc")
    }
}
