import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Display topology queries", .serialized)
@MainActor
struct DisplayQueryTests {
    private func object(_ value: JSONValue?) -> [String: JSONValue]? {
        guard case .object(let fields)? = value else { return nil }
        return fields
    }

    @Test("Monitor selectors and query identities join to shown Spaces")
    func topology() throws {
        let core = makeTestCore()
        let west = Display(
            id: DisplayID(10001),
            name: "West",
            frame: CGRect(x: -1200, y: 700, width: 900, height: 600)
        )
        let east = Display(
            id: DisplayID(10002),
            name: "East",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )
        core.state.apply(.displaysChanged([east, west]))
        core.state.workspaces.assign(SpaceID("1"), to: west.id)
        core.state.workspaces.assign(SpaceID("2"), to: east.id)
        core.state.workspaces.assign(SpaceID("3"), to: east.id)
        core.state.workspaces.ensureSpace(SpaceID("unassigned"))
        core.state.workspaces.activate(SpaceID("3"))
        guard case .array(let monitors)? = core.execute("list_monitors").data
        else {
            Issue.record("expected monitor array")
            return
        }
        try #require(monitors.count == 2)
        for (offset, display) in [west, east].enumerated() {
            let monitor = try #require(object(monitors[offset]))
            #expect(monitor["id"] == .number(Double(display.id.raw)))
            #expect(monitor["index"] == .number(Double(offset + 1)))
            #expect(monitor["name"] == .string(display.name))
            #expect(monitor["fingerprint"] == .string(display.fingerprint))
            #expect(monitor["x"] == .number(Double(display.frame.minX)))
            #expect(monitor["y"] == .number(Double(display.frame.minY)))
            #expect(monitor["width"] == .number(Double(display.frame.width)))
            #expect(monitor["height"] == .number(Double(display.frame.height)))
            #expect(monitor["active"] == .bool(display.id == east.id))
            #expect(
                monitor["active_space"]
                    == .string(display.id == east.id ? "3" : "1")
            )
            #expect(core.resolveDisplayArg(monitor["index"]) == display.id)
        }
        let state = try #require(object(core.execute("get_state").data))
        #expect(state["active_display"] == .number(Double(east.id.raw)))
        guard case .array(let spaces)? = state["spaces"] else {
            Issue.record("expected Space array")
            return
        }
        for (name, display) in [
            ("1", west.id), ("2", east.id), ("3", east.id),
        ] {
            let space = try #require(
                spaces.compactMap { object($0) }.first {
                    $0["id"] == .string(name)
                }
            )
            #expect(space["display"] == .number(Double(display.raw)))
        }
        let unassigned = try #require(
            spaces.compactMap { object($0) }.first {
                $0["id"] == .string("unassigned")
            }
        )
        #expect(unassigned["display"] == .null)
        core.execute("focus_display", args: [.string("West")])
        let focused = try #require(object(core.execute("get_state").data))
        #expect(focused["active_display"] == .number(Double(west.id.raw)))
        #expect(focused["active_space"] == .string("1"))
    }

    @Test("Global sticky focus reports its rendering display, not its home")
    func stickyRenderingDisplay() throws {
        let core = makeTestCore()
        for (raw, x) in [(UInt32(10001), 0), (UInt32(10002), 1200)] {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(raw),
                    name: "Screen \(raw)",
                    frame: CGRect(
                        x: CGFloat(x),
                        y: 0,
                        width: 1200,
                        height: 800
                    )
                )
            )
        }
        core.state.workspaces.assign(SpaceID("1"), to: DisplayID(10001))
        core.state.workspaces.assign(SpaceID("2"), to: DisplayID(10002))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "Sticky")
            )
        )
        core.execute("make_sticky")
        core.execute("focus_space", args: [.string("2")])
        let state = try #require(object(core.execute("get_state").data))
        #expect(core.state.workspaces.space(of: WindowID(1)) == SpaceID("1"))
        #expect(state["active_display"] == .number(10002))
        #expect(core.resolveDisplayArg(.string("prev")) == DisplayID(10001))
    }

    @Test("Absent topology reports null identities")
    func noDisplays() throws {
        let core = makeTestCore()
        core.state.apply(.displaysChanged([]))
        let state = try #require(object(core.execute("get_state").data))
        #expect(state["active_display"] == .null)
        #expect(core.execute("list_monitors").data == .array([]))
        #expect(
            !core.execute(
                "focus_display",
                args: [.string("next")]
            ).isSuccess
        )
    }
}
