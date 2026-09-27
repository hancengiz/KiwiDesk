import Foundation

/// Space↔display commands (multi-monitor): move a space to a
/// monitor at runtime, or pin it there persistently. Split from
/// `KiwiCore+SpaceCommands.swift` (which owns window-in-space
/// verbs) for the file ceiling.
extension KiwiCore {
    /// The focused rendering Space owns the active screen, not
    /// the menu-bar display or a sticky traveler's home.
    var activeDisplayID: DisplayID? {
        let rendered = focusedWindow.flatMap {
            state.stickyRenderSpace(of: $0)
        }
        return (rendered ?? state.workspaces.activeSpace)
            .flatMap { state.workspaces.display(of: $0) }
    }

    var orderedDisplays: [Display] {
        PositionalDisplays.ordered(
            state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
        )
    }

    /// Explicit identities win over relative selector words.
    /// Pins pass `relative: false`: a persistent target is explicit.
    func resolveDisplayArg(
        _ arg: JSONValue?,
        relative: Bool = true
    ) -> DisplayID? {
        let displays = orderedDisplays
        // Index first: a numeric arg is positional, never a name.
        if let index = arg?.intValue {
            guard index >= 1, index <= displays.count else {
                return nil
            }
            return displays[index - 1].id
        }
        guard let name = arg?.stringValue else { return nil }
        if let match = displays.first(where: {
            $0.fingerprint == name
        }) {
            return match.id
        }
        if let match = displays.first(where: { $0.name == name }) {
            return match.id
        }
        guard relative, let active = activeDisplayID,
            let index = displays.firstIndex(where: { $0.id == active })
        else { return nil }
        if name == "next" || name == "prev" {
            let step = name == "next" ? 1 : displays.count - 1
            return displays[(index + step) % displays.count].id
        }
        guard let direction = Direction(rawValue: name) else {
            return nil
        }
        return neighboringDisplay(
            from: displays[index],
            toward: direction,
            in: displays
        )
    }

    /// Display frames use AppKit coordinates: up is positive y.
    /// Unlike window navigation, diagonal screens remain reachable.
    /// Ordered input breaks equal-distance ties deterministically.
    private func neighboringDisplay(
        from origin: Display,
        toward direction: Direction,
        in displays: [Display]
    ) -> DisplayID? {
        var best: (id: DisplayID, score: CGFloat)?
        for display in displays where display.id != origin.id {
            let dx = display.frame.midX - origin.frame.midX
            let dy = display.frame.midY - origin.frame.midY
            let forward: CGFloat
            let lateral: CGFloat
            switch direction {
            case .left:
                forward = -dx
                lateral = abs(dy)
            case .right:
                forward = dx
                lateral = abs(dy)
            case .up:
                forward = dy
                lateral = abs(dx)
            case .down:
                forward = -dy
                lateral = abs(dx)
            }
            guard forward > 0 else { continue }
            let score = forward + lateral * 2
            if best == nil || score < best!.score {
                best = (display.id, score)
            }
        }
        return best?.id
    }

    func focusDisplay(_ args: [JSONValue]) -> CommandResponse {
        guard let display = resolveDisplayArg(args.first) else {
            return .fail("no matching display")
        }
        guard let space = state.workspaces.activeSpace(on: display) else {
            return .fail("display has no active Space")
        }
        return focusSpace([.string(space.raw)])
    }

    func moveToDisplay(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let display = resolveDisplayArg(args.first) else {
            return .fail("no matching display")
        }
        guard let space = state.workspaces.activeSpace(on: display) else {
            return .fail("display has no active Space")
        }
        guard focusedWindow?.isFullscreen != true else {
            return .fail("the focused window is fullscreen")
        }
        return moveToSpace([.string(space.raw)], follow: follow)
    }

    /// `move_space_to_display(space, display)` — moves a space to
    /// another monitor NOW and shows it there. Runtime only: a
    /// later monitor re-resolve (dock/undock) reverts to the
    /// space's pin or auto placement — use `pin_space_to_display`
    /// to make it stick. Auto-creates the space if new.
    func moveSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard
            let display = resolveDisplayArg(
                args.count > 1 ? args[1] : nil
            )
        else {
            return .fail("no matching display")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        state.workspaces.assign(space, to: display)
        // The one relocation that bypasses the resolve, so it
        // heals the screen it may have emptied itself (#1175).
        healEmptyDisplays(mainID: PositionalDisplays.liveMainID)
        // Show it on — and move focus to — the target display.
        state.workspaces.activate(space)
        // The layout carries the tiled members to the new
        // display; floats have no layout frame, so each one
        // re-anchors explicitly (#444).
        reanchorFloats(of: space)
        spaceSwitchRetile()
        emitSpaceChange()
        return .ok()
    }

    /// `pin_space_to_display(space, display)` — pins a space to a
    /// monitor by that monitor's fingerprint, so the assignment
    /// survives dock/undock (and, declared in `init.lua`, a
    /// relaunch). Overrides any Main-role assignment. Auto-creates
    /// the space if new.
    ///
    /// Sets the RUNTIME pin and re-resolves; it does not hand-write
    /// `gui.json` — under a GUI-managed config the Settings Canvas
    /// stays the persistent pin owner, so a pin set here is a
    /// session override there. Under a Lua-managed config the
    /// declarative `init.lua` re-exec is the persistence.
    func pinSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard
            let display = resolveDisplayArg(
                args.count > 1 ? args[1] : nil,
                relative: false
            ),
            let monitor = state.workspaces.allDisplays.first(where: {
                $0.id == display
            })
        else {
            return .fail("expected display index or name")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        spacePins[space] = monitor.fingerprint
        // A pin and the Main role are mutually exclusive
        // placements (`SpacePlacement` precedence); a fresh pin
        // wins, so drop any stale Main designation.
        mainSpaces.remove(space)
        // `resolveSpaceDisplays` re-anchors the floats of every
        // space it relocates (#444) — including another space
        // this pin displaces off the target display.
        resolveSpaceDisplays()
        retile(pass: .apply)
        emitSpaceChange()
        return .ok()
    }
}
