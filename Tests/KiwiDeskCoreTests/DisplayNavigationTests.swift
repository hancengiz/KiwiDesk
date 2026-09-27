import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("Display navigation", .serialized)
@MainActor
struct DisplayNavigationTests {
    private let origin = DisplayID(10001)
    private let right = DisplayID(10002)
    private let upper = DisplayID(10003)
    private let diagonal = DisplayID(10004)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        let displays = [
            Display(
                id: origin,
                name: "Origin",
                frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
            ),
            Display(
                id: right,
                name: "East",
                frame: CGRect(x: 1600, y: 100, width: 800, height: 600)
            ),
            Display(
                id: upper,
                name: "North",
                frame: CGRect(x: 100, y: 1400, width: 1400, height: 900)
            ),
            Display(
                id: diagonal,
                name: "Diagonal",
                frame: CGRect(x: -1600, y: -1200, width: 900, height: 700)
            ),
        ]
        core.state.apply(.displaysChanged(Array(displays.reversed())))
        for (id, display) in [
            ("1", origin), ("2", right), ("3", right),
            ("4", upper), ("5", diagonal),
        ] {
            core.state.workspaces.assign(SpaceID(id), to: display)
        }
        core.state.workspaces.activate(SpaceID("1"))
        core.state.workspaces.show(SpaceID("3"), on: right)
        return core
    }

    @Test("Uneven and diagonal displays resolve in AppKit coordinates")
    func spatialTargets() {
        let core = makeCore()
        for (selector, target) in [
            ("right", "3"), ("up", "4"),
            ("left", "5"), ("down", "5"),
        ] {
            core.state.workspaces.activate(SpaceID("1"))
            let response = core.execute(
                "focus_display",
                args: [.string(selector)]
            )
            #expect(response.isSuccess)
            #expect(core.state.workspaces.activeSpace == SpaceID(target))
            #expect(
                core.state.workspaces.activeSpace(on: right)
                    == SpaceID("3")
            )
            #expect(
                core.state.workspaces.display(of: SpaceID("1"))
                    == origin
            )
        }
    }

    @Test("Cycles wrap in the same order as explicit indices")
    func cyclicAndExplicitTargets() {
        let core = makeCore()
        // No injected display is the machine main: x order wins.
        let targets = ["5", "1", "4", "3"]
        for (index, target) in targets.enumerated() {
            #expect(
                core.execute(
                    "focus_display",
                    args: [.number(Double(index + 1))]
                ).isSuccess
            )
            #expect(core.state.workspaces.activeSpace == SpaceID(target))
        }
        #expect(
            core.execute(
                "focus_display",
                args: [.string("next")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("5"))
        #expect(
            core.execute(
                "focus_display",
                args: [.string("prev")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
        #expect(
            core.execute(
                "focus_display",
                args: [.string("Origin")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
    }

    @Test("Explicit identity wins over relative words; pins stay explicit")
    func namesAndPins() {
        let core = makeCore()
        let named = Display(
            id: upper,
            name: "next",
            frame: CGRect(x: 100, y: 1400, width: 1400, height: 900)
        )
        core.state.workspaces.upsertDisplay(named)
        core.state.workspaces.activate(SpaceID("3"))
        #expect(
            core.execute(
                "focus_display",
                args: [.string("next")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("4"))
        #expect(
            core.execute(
                "focus_display",
                args: [.string(named.fingerprint)]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("4"))
        let pins = core.spacePins
        #expect(
            !core.execute(
                "pin_space_to_display",
                args: [.string("new"), .string("prev")]
            ).isSuccess
        )
        #expect(core.state.workspaces[SpaceID("new")] == nil)
        #expect(core.spacePins == pins)
        #expect(
            core.resolveDisplayArg(.string("next"), relative: false)
                == upper
        )
    }

    @Test("Missing neighbor refuses without creating or relocating Spaces")
    func missingNeighbor() {
        let core = makeCore()
        core.state.workspaces.activate(SpaceID("4"))
        let spaces = core.state.workspaces.allSpaces.map(\.id)
        let pins = core.spacePins
        #expect(
            !core.execute(
                "focus_display",
                args: [.string("up")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "move_space_to_display",
                args: [.string("new"), .string("up")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("4"))
        #expect(core.state.workspaces.allSpaces.map(\.id) == spaces)
        #expect(core.state.workspaces.display(of: SpaceID("4")) == upper)
        #expect(core.state.workspaces.activeSpace(on: right) == SpaceID("3"))
        #expect(core.spacePins == pins)
    }

    @Test("Whole Space relative move leaves persistent placement alone")
    func wholeSpaceMove() {
        let core = makeCore()
        core.spacePins[SpaceID("1")] = "Origin:1200x800"
        let pins = core.spacePins
        #expect(
            core.execute(
                "move_space_to_display",
                args: [.string("1"), .string("right")]
            ).isSuccess
        )
        #expect(core.state.workspaces.display(of: SpaceID("1")) == right)
        #expect(core.state.workspaces.activeSpace(on: right) == SpaceID("1"))
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        for (space, pin) in pins {
            #expect(core.spacePins[space] == pin)
        }
    }

    @Test("Coincident display geometry has a stable spatial tie-break")
    func coincidentDisplays() {
        let core = makeCore()
        // Identical frames and fingerprints still have distinct raw ids.
        for id in [upper, right] {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: id,
                    name: "Twin",
                    frame: CGRect(x: 1600, y: 100, width: 800, height: 600)
                )
            )
        }
        #expect(
            core.execute(
                "focus_display",
                args: [.string("right")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
        #expect(core.resolveDisplayArg(.number(3)) == right)
        #expect(core.resolveDisplayArg(.number(4)) == upper)
    }

    @Test("Single display cycles stay put; spatial and invalid targets refuse")
    func singleDisplay() {
        let core = makeTestCore()
        core.state.apply(
            .displaysChanged([
                Display(
                    id: origin,
                    name: "Only",
                    frame: CGRect(x: -900, y: 500, width: 900, height: 700)
                )
            ])
        )
        core.state.workspaces.assign(SpaceID("1"), to: origin)
        core.state.workspaces.activate(SpaceID("1"))
        for selector in [
            JSONValue.string("next"), .string("prev"),
            .string("Only"), .number(1),
        ] {
            #expect(core.execute("focus_display", args: [selector]).isSuccess)
            #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        }
        for selector in [
            JSONValue.string("left"), .string("right"),
            .string("up"), .string("down"), .number(0), .number(2),
            .string("absent"), .null,
        ] {
            #expect(!core.execute("focus_display", args: [selector]).isSuccess)
            #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        }
    }
}
