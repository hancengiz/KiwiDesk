import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Omarchy configuration installer")
struct OmarchyConfigTests {
    @Test("preview is read-only; apply preserves unrelated configuration")
    func preservationAndBackup() throws {
        let fixture = try OmarchyFixture()
        defer { fixture.cleanup() }
        let original = fixture.sampleConfig
        try fixture.writeConfig(original)
        let hook =
            "KiwiDesk.on(\"focus_change\", function(id) "
            + "lastFocused = id end)\n"
        try fixture.write("init.lua", hook)
        try fixture.write("profiles.json", "authored profile data\n")
        let before = try fixture.snapshot()

        #expect(try fixture.run().status == 0)
        #expect(try fixture.snapshot() == before)
        let applied = try fixture.run(apply: true)
        #expect(applied.status == 0, "\(applied.stderr)")
        let result = try fixture.config()
        for key in original.keys where key != "layers" {
            #expect(result[key] == original[key])
        }
        let layers = try #require(result["layers"]?.arrayValue)
        let untouched = try #require(original["layers"]?.arrayValue?.last)
        #expect(layers.contains(untouched))
        let main = try #require(layers.first?.objectValue)
        let actions = try #require(main["bindings"]?.arrayValue)
        #expect(actions.contains(fixture.launcher))
        #expect(try fixture.text("init.lua").hasPrefix(hook))
        #expect(try fixture.text("profiles.json") == "authored profile data\n")
        let backups = try fixture.backups()
        let backup = try #require(backups.first)
        #expect(backups.count == 1)
        for name in ["gui.json", "init.lua"] {
            #expect(
                try Data(contentsOf: backup.appendingPathComponent(name))
                    == before[name]
            )
        }
    }

    @Test("ambiguous authored helpers refuse without any writes")
    func ambiguousHelperRefused() throws {
        let fixture = try OmarchyFixture()
        defer { fixture.cleanup() }
        try fixture.writeConfig(fixture.sampleConfig)
        try fixture.write(
            "init.lua",
            "MacarchyKeys = { custom = true }\n"
                + "KiwiDesk.on(\"space_change\", function() end)\n"
        )
        let before = try fixture.snapshot()
        #expect(try fixture.run(apply: true).status != 0)
        #expect(try fixture.snapshot() == before)
        #expect(try fixture.backups().isEmpty)
    }

    @Test("modifier aliases cannot silently discard an authored shortcut")
    func duplicateAliasesRefused() throws {
        let fixture = try OmarchyFixture()
        defer { fixture.cleanup() }
        var config = fixture.sampleConfig
        let rows: [JSONValue] = ["alt+enter", "option+return"].map { combo in
            .object([
                "combo": .string(combo),
                "kind": .string("application"),
                "label": .string("Authored action"),
                "lua": .string("KiwiDesk.exec(\"open -a Terminal\")"),
            ])
        }
        config["layers"] = .array([
            .object([
                "name": .string("default"), "bindings": .array(rows),
            ])
        ])
        try fixture.writeConfig(config)
        let before = try fixture.snapshot()
        #expect(try fixture.run(apply: true).status != 0)
        #expect(try fixture.snapshot() == before)
        #expect(try fixture.backups().isEmpty)
    }

    @Test("reapplication is byte-stable and preserves hooks around helpers")
    func repeatedApplication() throws {
        let fixture = try OmarchyFixture()
        defer { fixture.cleanup() }
        #expect(try fixture.run(apply: true).status == 0)
        let hook =
            "\nKiwiDesk.on(\"focus_change\", function(id) "
            + "afterHelper = id end)\n"
        try fixture.write("init.lua", try fixture.text("init.lua") + hook)
        let before = try fixture.snapshot()
        #expect(try fixture.run(apply: true).status == 0)
        #expect(try fixture.snapshot() == before)
        #expect(try fixture.backups().count == 1)
    }

    @Test("fresh shortcuts do not collide or consume text-editing arrows")
    func freshKeymapBoundaries() throws {
        let fixture = try OmarchyFixture()
        defer { fixture.cleanup() }
        #expect(try fixture.run(apply: true).status == 0)
        let config = try fixture.config()
        let layers = try #require(config["layers"]?.arrayValue)
        for layer in layers {
            let rows = try #require(layer.objectValue?["bindings"]?.arrayValue)
            let combos = try rows.map { row in
                let raw = try #require(row.objectValue?["combo"]?.stringValue)
                return try #require(KeyCombo.parse(raw))
            }
            #expect(Set(combos).count == combos.count)
            for direction in ["left", "right", "up", "down"] {
                for modifiers in ["option", "option+shift"] {
                    let reserved = try #require(
                        KeyCombo.parse("\(modifiers)+\(direction)")
                    )
                    #expect(!combos.contains(reserved))
                }
            }
        }
        #expect(
            !ManagedConfig.declaresManagedSettings(
                try fixture.text("init.lua")
            )
        )
    }
}

private struct OmarchyFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("omarchy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
    }

    var launcher: JSONValue {
        .object([
            "combo": .string("option+enter"),
            "kind": .string("application"),
            "label": .string("My terminal"),
            "lua": .string("KiwiDesk.exec(\"open -a Terminal\")"),
        ])
    }

    var sampleConfig: [String: JSONValue] {
        [
            "format": .number(4),
            "spaces": .array([.string("2"), .string("11")]),
            "app_rules": .object(["app.example": .string("11")]),
            "profile_bindings": .object(["2": .string("Work")]),
            "monitor_spaces": .object(["fingerprint": .string("11")]),
            "gap": .number(17),
            "layers": .array([
                .object([
                    "name": .string("default"),
                    "bindings": .array([launcher]),
                ]),
                .object([
                    "name": .string("authored"),
                    "icon": .string("keyboard"),
                    "bindings": .array([
                        .object([
                            "combo": .string("escape"),
                            "kind": .string("custom"),
                            "label": .string("Leave"),
                            "lua": .string(
                                "KiwiDesk.switch_layer(\"default\")"
                            ),
                        ])
                    ]),
                ]),
            ]),
        ]
    }

    func run(apply: Bool = false) throws -> ScriptRun {
        try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/omarchy-config"),
            arguments: ["--config-dir", root.path]
                + (apply ? ["--apply"] : [])
        )
    }

    func writeConfig(_ config: [String: JSONValue]) throws {
        try JSONEncoder().encode(config).write(
            to: root.appendingPathComponent("gui.json")
        )
    }

    func config() throws -> [String: JSONValue] {
        try JSONDecoder().decode(
            [String: JSONValue].self,
            from: Data(contentsOf: root.appendingPathComponent("gui.json"))
        )
    }

    func write(_ name: String, _ text: String) throws {
        try text.write(
            to: root.appendingPathComponent(name),
            atomically: true,
            encoding: .utf8
        )
    }

    func text(_ name: String) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    func snapshot() throws -> [String: Data] {
        var result: [String: Data] = [:]
        for url in try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) where !url.lastPathComponent.hasPrefix("omarchy-backup-") {
            result[url.lastPathComponent] = try Data(contentsOf: url)
        }
        return result
    }

    func backups() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("omarchy-backup-") }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

extension JSONValue {
    fileprivate var arrayValue: [JSONValue]? {
        if case .array(let values) = self { return values }
        return nil
    }

    fileprivate var objectValue: [String: JSONValue]? {
        if case .object(let values) = self { return values }
        return nil
    }
}
