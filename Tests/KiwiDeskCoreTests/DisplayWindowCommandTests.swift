import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Window to display commands", .serialized)
@MainActor
struct DisplayWindowCommandTests {
    private let origin = DisplayID(10001)
    private let target = DisplayID(10002)
    private let moving = WindowID(2)
    private let staying = WindowID(1)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.state.apply(
            .displaysChanged([
                Display(
                    id: origin,
                    name: "Origin",
                    frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
                ),
                Display(
                    id: target,
                    name: "Target",
                    frame: CGRect(x: 1600, y: 100, width: 800, height: 600)
                ),
            ])
        )
        for (space, display) in [
            ("1", origin), ("2", target), ("3", target),
        ] {
            core.state.workspaces.assign(SpaceID(space), to: display)
        }
        core.state.workspaces.activate(SpaceID("1"))
        core.state.workspaces.show(SpaceID("3"), on: target)
        for id in [staying, moving] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "Display test")
                )
            )
        }
        return core
    }

    @Test("Send and follow use the target's shown Space, not its first")
    func shownDestination() {
        for follow in [false, true] {
            let core = makeCore()
            let command =
                follow
                ? "move_to_display_and_follow" : "move_to_display"
            let pins = core.spacePins
            #expect(
                core.execute(
                    command,
                    args: [.string("right")]
                ).isSuccess
            )
            #expect(core.state.workspaces.space(of: moving) == SpaceID("3"))
            #expect(core.state.workspaces[SpaceID("2")]?.windows == [])
            #expect(core.state.workspaces[SpaceID("1")]?.windows == [staying])
            #expect(core.state.workspaces[SpaceID("3")]?.focused == moving)
            #expect(
                core.state.workspaces.activeSpace(on: target)
                    == SpaceID("3")
            )
            #expect(
                core.state.workspaces.activeSpace(on: origin)
                    == SpaceID("1")
            )
            #expect(
                core.state.workspaces.activeSpace
                    == SpaceID(follow ? "3" : "1")
            )
            #expect(core.focusedWindowID == (follow ? moving : staying))
            #expect(core.spacePins == pins)
        }
    }

    @Test("Missing screen, fullscreen and unmanaged focus never refile")
    func refusedMoves() {
        for command in ["move_to_display", "move_to_display_and_follow"] {
            let core = makeCore()
            #expect(
                !core.execute(
                    command,
                    args: [.string("left")]
                ).isSuccess
            )
            #expect(core.state.workspaces.space(of: moving) == SpaceID("1"))
            #expect(core.focusedWindowID == moving)
            core.state.windows.setFullscreen(moving, true)
            #expect(!core.execute(command, args: [.number(2)]).isSuccess)
            #expect(core.state.workspaces.space(of: moving) == SpaceID("1"))
            core.state.windows.setFullscreen(moving, false)
            core.frontmostPIDProvider = { 999 }
            #expect(!core.execute(command, args: [.number(2)]).isSuccess)
            #expect(core.state.workspaces.space(of: moving) == SpaceID("1"))
            #expect(core.state.workspaces.activeSpace == SpaceID("1"))
            #expect(core.state.workspaces[SpaceID("3")]?.windows == [])
            #expect(
                core.state.workspaces.activeSpace(on: target)
                    == SpaceID("3")
            )
        }
    }

    @Test("Sticky restrictions remain on the shared Space move path")
    func stickyRefusal() {
        for command in ["move_to_display", "move_to_display_and_follow"] {
            let core = makeCore()
            #expect(core.execute("make_sticky").isSuccess)
            core.execute(command, args: [.number(2)])
            #expect(core.state.workspaces.space(of: moving) == SpaceID("1"))
            #expect(core.state.workspaces.activeSpace == SpaceID("1"))
            #expect(core.state.workspaces[SpaceID("3")]?.windows == [])
        }
    }

    @Test("Display moves pay pending monocle focus before selecting a window")
    func pendingFocus() {
        for command in ["move_to_display", "move_to_display_and_follow"] {
            let core = makeCore()
            core.pendingMonocleFocus = (from: moving, to: staying)
            #expect(core.execute(command, args: [.number(2)]).isSuccess)
            #expect(core.state.workspaces.space(of: staying) == SpaceID("3"))
            #expect(core.state.workspaces.space(of: moving) == SpaceID("1"))
            #expect(core.pendingMonocleFocus == nil)
        }
    }

    @Test("A display without a shown Space refuses without creating one")
    func emptyDisplay() {
        let core = makeTestCore()
        core.state.apply(
            .displaysChanged([
                Display(
                    id: target,
                    name: "Empty",
                    frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
                )
            ])
        )
        let spaces = core.state.workspaces.allSpaces.map(\.id)
        for command in [
            "focus_display", "move_to_display",
            "move_to_display_and_follow",
        ] {
            #expect(!core.execute(command, args: [.number(1)]).isSuccess)
            #expect(core.state.workspaces.allSpaces.map(\.id) == spaces)
            #expect(core.state.workspaces.activeSpace(on: target) == nil)
        }
    }
}
