import Foundation

enum SyncPreferences {
    // Explicit allowlist: newly introduced keys stay local until reviewed.
    static let types: [String: String] = [
        "Clockin.AutoCheckUpdates": "bool",
        "Clockin.ChimeEnabled": "bool",
        "Clockin.ChimeIntervalMinutes": "integer",
        "Clockin.ChimeSound": "string",
        "Clockin.ChimeVolume": "double",
        "Clockin.CompanionAccessory": "string",
        "Clockin.Dashboard.Pin.chime": "bool",
        "Clockin.Dashboard.Pin.radio": "bool",
        "Clockin.Dashboard.Pin.reminder": "bool",
        "Clockin.DeskModeEnabled": "bool",
        "Clockin.GoalDailyHours": "double",
        "Clockin.GoalMonthlyHours": "double",
        "Clockin.HapticsEnabled": "bool",
        "Clockin.HeatmapRange": "string",
        "Clockin.HistoryGroupByDay": "bool",
        "Clockin.HistoryRange": "string",
        "Clockin.HistoryShowsTRY": "bool",
        "Clockin.InsightsHeatmapDayRange": "integer",
        "Clockin.InsightsHeatmapGrouping": "string",
        "Clockin.Language": "string",
        "Clockin.LevelUpSoundEnabled": "bool",
        "Clockin.LongSessionReminderHours": "integer",
        "Clockin.MascotDefault": "string",
        "Clockin.MascotEnabled": "bool",
        "Clockin.MinimalMode": "bool",
        "Clockin.MinimalShowEarnings": "bool",
        "Clockin.MinimalShowGoal": "bool",
        "Clockin.MinimalShowHours": "bool",
        "Clockin.MinimalShowSeconds": "bool",
        "Clockin.MinimalShowTRY": "bool",
        "Clockin.NudgeTone": "string",
        "Clockin.NudgesEnabled": "bool",
        "Clockin.PinnedMode": "string",
        "Clockin.RadioStation": "string",
        "Clockin.SeenAccessoryIDs": "strings",
        "Clockin.Theme": "string",
        "Clockin.Today.Link.goals": "bool",
        "Clockin.Today.Link.history": "bool",
        "Clockin.Today.Link.liveUpdates": "bool",
        "Clockin.Today.Link.newEntry": "bool",
        "Clockin.Today.Show.companion": "bool",
        "Clockin.Today.Show.exchange": "bool",
        "Clockin.Today.Show.goals": "bool",
        "Clockin.Today.Show.momentum": "bool",
        "Clockin.Today.Show.recent": "bool",
        "Clockin.Today.Show.summary": "bool",
        "Clockin.WardrobeShowHomeInDeskMode": "bool",
        "Clockin.WorkdaysPerWeek": "integer",
        "SUEnableAutomaticChecks": "bool",
    ]
    static let deviceKeys: [String] = [
        "AppleLanguages",
        "Clockin.GoalPromptDismissedAt",
        "Clockin.HasConfiguredGoal",
        "Clockin.LastCelebratedLevel",
        "Clockin.LiveActivitySetupSeen.v1",
        "Clockin.LongSessionReminderState",
        "Clockin.MoveToApplicationsSuppressed",
        "Clockin.NudgeState",
        "Clockin.PinVisibleBeforeMinimal",
        "Clockin.PinnedHeight.All",
        "Clockin.PinnedHeight.Compact",
        "Clockin.PinnedHeight.Goal",
        "Clockin.PinnedHeight.Money",
        "Clockin.PinnedHeight.Total",
        "Clockin.PinnedWidth.All",
        "Clockin.PinnedWidth.Compact",
        "Clockin.PinnedWidth.Goal",
        "Clockin.PinnedWidth.Money",
        "Clockin.PinnedWidth.Total",
        "Clockin.RemoteActivityConsent.v2",
        "Clockin.RemoteActivityPendingDeletions.v2",
        "Clockin.RemoteActivityRegisteredTokens.v1",
        "Clockin.SeenBadgeIDs",
        "Clockin.UIScale",
        "Clockin.UIScalePercent",
        "Clockin.USDTRYRates.v1",
        "Clockin.USDTRYRatesUpdated.v1",
        "NSWindow Frame ClockinMainWindow",
        "NSWindow Frame ClockinPinnedTimer",
        "pinVisible",
    ]

    static func accepts(_ key: String, _ value: SyncPreference) -> Bool {
        guard types[key] == value.type else { return false }
        if case .double(let number) = value { return number.isFinite }
        return true
    }

    static func filtered(_ values: [String: SyncPreference]) -> [String: SyncPreference] {
        values.filter { accepts($0.key, $0.value) }
    }
}
