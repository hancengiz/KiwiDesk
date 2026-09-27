import Testing

@testable import KiwiDeskCore

/// The Lua bridge's verdict contract: a dispatcher command with
/// no payload answers `true`/`false` in Lua (its success), while
/// a payload command returns only the payload. The unified
/// direction chords in the Omarchy recipe fall through a failed
/// window probe to the screen verb by testing this value.
@Suite("Lua command verdicts", .serialized)
@MainActor
struct LuaCommandVerdictTests {
    private func ran(
        _ result: Result<Void, LuaError>
    ) -> Bool {
        if case .success = result { return true }
        return false
    }

    @Test("data-less commands answer success; payloads do not")
    func verdicts() throws {
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "Alone")
            )
        )
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)

        // One window: swap has no neighbor, so the verdict is
        // false even though the call itself ran.
        #expect(
            ran(lua.run("ok = KiwiDesk.swap(\"left\")"))
        )
        #expect(lua.global("ok") == .bool(false))

        // A data-less success answers true.
        #expect(
            ran(lua.run("ok = KiwiDesk.create_space(\"smoke\")"))
        )
        #expect(lua.global("ok") == .bool(true))

        // A payload command still returns its payload alone.
        #expect(
            ran(
                lua.run(
                    "t = KiwiDesk.get_state(); "
                        + "isTable = (type(t) == \"table\")"
                )
            )
        )
        #expect(lua.global("isTable") == .bool(true))
    }
}
