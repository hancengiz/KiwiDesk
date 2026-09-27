/// Display order for the Behaviour settings area (#678).
/// `BehaviorCensusRenderTests` holds these equal to the census —
/// a row moves by editing the census; these lists follow.
enum BehaviorRowOrder {
    /// The mouse card, top to bottom.
    static let mouse: [SettingKey] = [
        .behaviour(.mouseResize),
        .behaviour(.mouseFollowsFocus),
    ]

    /// The cues card (#1255).
    static let cues: [SettingKey] = [
        .behaviour(.refusalSound)
    ]

    /// The on-quit card.
    static let onQuit: [SettingKey] = [
        .behaviour(.quitGridTargetDepth)
    ]

    /// The menu bar Spaces card (fork-local, 2026-09-27).
    static let status: [SettingKey] = [
        .behaviour(.statusOccupiedSpaces)
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .mouse: mouse,
        .cues: cues,
        .onQuit: onQuit,
        .status: status,
    ]

    /// Containers rendered via bespoke views rather than static lists.
    static let bespokeContainers: Set<SettingsContainer> = [
        .mouse,
        .cues,
        .onQuit,
        .status,
    ]
}
