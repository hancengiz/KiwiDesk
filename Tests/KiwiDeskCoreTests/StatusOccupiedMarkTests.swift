import Testing

@testable import KiwiDeskCore

/// The menu bar mark's occupied-Spaces list (fork-local,
/// 2026-09-27): the setting gates it, the Space Bar disables
/// it, occupancy decides membership, the active Space stays
/// listed while empty, and the counts follow the windows.
@Suite("Status mark occupied list", .serialized)
@MainActor
struct StatusOccupiedMarkTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.ensureSpace(SpaceID("empty"))
        core.state.workspaces.ensureSpace(SpaceID("scratch"))
        core.state.workspaces.activate(SpaceID("1"))
        for id in [WindowID(1), WindowID(2), WindowID(3)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(4), pid: 1, appName: "App")
            )
        )
        core.state.workspaces.add(WindowID(4), to: SpaceID("2"))
        // The list is a bar-off surface; the starter default
        // would leave the bar on and own it.
        core.tiler.settings.spaceBarStyle.enabled = false
        return core
    }

    @Test("off by default; the setting turns the list on")
    func settingGates() {
        let core = makeCore()
        #expect(core.statusSpaceMark().occupied.isEmpty)
        core.tiler.settings.statusOccupiedSpaces = true
        #expect(!core.statusSpaceMark().occupied.isEmpty)
    }

    @Test("occupied Spaces list counts; active stays while empty")
    func membershipAndCounts() {
        let core = makeCore()
        core.tiler.settings.statusOccupiedSpaces = true
        // Spaces 1 (3 windows) and 2 (1 window) are listed; the
        // non-active empties drop; the active Space stays listed
        // even while it holds nothing.
        core.state.workspaces.activate(SpaceID("scratch"))
        let occupied = core.statusSpaceMark().occupied
        #expect(
            occupied == [
                StatusSpaceMark.Occupied(
                    space: SpaceID("1"),
                    windows: 3,
                    active: false
                ),
                StatusSpaceMark.Occupied(
                    space: SpaceID("2"),
                    windows: 1,
                    active: false
                ),
                StatusSpaceMark.Occupied(
                    space: SpaceID("scratch"),
                    windows: 0,
                    active: true
                ),
            ]
        )
    }

    @Test("the Space Bar owns the surface while it is on")
    func barDisablesTheList() {
        let core = makeCore()
        core.tiler.settings.statusOccupiedSpaces = true
        core.tiler.settings.spaceBarStyle.enabled = true
        #expect(core.statusSpaceMark().occupied.isEmpty)
        #expect(core.statusSpaceMark().screens.isEmpty)
    }

    @Test("the command flips the setting and republishes")
    func commandApplies() {
        let core = makeCore()
        var published: [StatusSpaceMark] = []
        core.onStatusSpaceMarkChange = { published.append($0) }
        #expect(
            core.execute(
                "set_status_occupied_spaces",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.statusOccupiedSpaces)
        core.updateBars()
        #expect(
            published.last?.occupied.map(\.space)
                == [SpaceID("1"), SpaceID("2")]
        )
    }
}
