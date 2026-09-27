# Omarchy-compatible workflow on KiwiDesk

Branch: `feat/omarchy-compatibility`.
Reference: local Omarchy checkout at
`fd961e5300c317025e561329e6e6a622eb4ad0b4`.

## Goal

Keep the familiar Omarchy keyboard workflow, especially screens and Spaces,
while using KiwiDesk's existing layouts and macOS window mechanisms.
Do not reproduce Hyprland internals or develop window groups.

## What the user will experience

- Option remains the main window-management modifier, but focus arrows become
  Control+Option+arrows and swaps become Control+Option+Shift+arrows. Ordinary
  Option+arrows and Shift+Option+arrows return to native text editing.
- Space numbers are global. Activating Space 4 means its assigned screen,
  not Space 4 on whichever screen contains the pointer.
- Keep the saved distribution: main display has 1,2,3,8,9,10 and scratch;
  built-in has 4,5; MB169CK has 6,7. Do not rearrange existing workspaces at
  installation. A summon may move scratch at runtime, not rewrite those pins.
- Number shortcuts move windows to a named Space, with separate follow and
  stay-here actions. A target on another screen carries the window there.
- Add screen focus and direct window-to-screen actions. They use whichever
  Space the target screen currently shows, not a hardcoded Space number.
- Keep moving a whole Space to another screen distinct from moving one window.
- Next/previous Space walks existing numbered Spaces, not a fixed 1–10 loop.
  Keep a separate former-Space action.
- Scratch is an ordinary dedicated Space: summon it on the current screen,
  then return to the prior Space. It is not a transparent overlay over the
  normal Space. Keep a silent send-to-scratch action.
- Reuse native macOS fullscreen and the existing monocle/return-layout toggle.
  Label them honestly; native fullscreen can create a macOS fullscreen Space,
  and monocle applies to a whole KiwiDesk Space.
- Preserve existing configured layout sizes and reset-to-profile behavior.
  Interactive resize values can be session-only. Do not claim an app-specific
  save/restore-width command exists or silently replace it with profile save.
- Omarchy Super+P means pseudotile, not fit all windows. The current Option+P
  reset-sizing action remains explicitly labelled as a KiwiDesk adaptation.
- Use the normal/default keybinding layer for the permanent workflow so it
  survives reload/profile apply without a separate activation keystroke.

## Scope decisions

Accepted: KiwiDesk BSP/Scrolling/Monocle/Grid geometry, existing profile
placement and ordinary Space lifecycle, native macOS fullscreen, no groups.
No Dwindle rewrite, pseudotile implementation, shell/notification/clipboard
suite port, custom native fullscreen protocol or compositor scratch overlay.
Existing app launchers stay available; this work is the window/screen/Space
workflow, not a promise that every Linux desktop shortcut is portable.
A future exact width bookmark or overlay is a separately specified feature.

Control+Option is not globally conflict-free: VoiceOver and input-source
shortcuts need consideration. Preserve bare Command application shortcuts and
Option text-editing arrows. Screen chords can still conflict with applications;
keep Super and Alt distinct rather than collapsing them onto Option.
No remapper dependency.

## Implementation

### 1. Small command/API additions, no layout changes

Reuse the existing display and Space authorities and focus/raise gates.

- Expose monitor bounds/origins, ordered display indices and active-display
  identity, plus Space-to-display and per-display active-Space mapping.
- Add `focus_display(display)`.
- Add `move_to_display(display)` and
  `move_to_display_and_follow(display)` by routing to the target display's
  currently active Space and reusing the existing Space move command.
- Support `left`, `right`, `up`, `down`, `next`, `prev` display targets in
  addition to the existing numeric index/name/fingerprint selection.
- Reuse that targeting for `move_space_to_display`; keep persistent pinning
  separate from runtime movement.
- Cyclic targets wrap; spatial targets without a neighbor refuse without
  mutating state. Focus stays on the destination's existing Space.
- Preserve sticky-window restrictions and native-fullscreen safety gates.

Owning files: `Sources/KiwiDeskCore/Commands/` and `Commands/Reference/`,
`KiwiCore+Diagnostics.swift`, existing state/display helpers; focused behavior
regressions in `Tests/KiwiDeskCoreTests/`. Follow existing API census and
command documentation conventions. No new persisted schema is needed.

### 2. Portable compatibility configuration

Provide a reproducible configuration recipe using structured GUI bindings
and Lua helpers rather than changing KiwiDesk's default shortcuts for everyone.
Keep the active configuration backed up before changing it. Preserve app
rules, layout tuning, monitor assignments and unrelated profile content.

Helpers own existing-Space cycling, former-Space history, scratch return and
monocle return mode. Use live topology for scratch/screen operations; never
hardcode monitor names into portable helpers. Session history is not durable
profile state. Remove obsolete Macarchy helper/layer references at cutover.

The parent/integration owner controls all live configuration, app installation
and smoke verification. Parallel implementation must not mutate live files.

### 3. Documentation and deployment

Document the new command contracts in the existing Lua/CLI reference and the
compatibility setup in an integration recipe. Keep the saved branch plan with
the work. Build/install with the existing updater-disabled local packaging
policy; do not re-enable automatic network updates as a side effect.

## Acceptance and verification

- Command tests with deterministic injected monitors: left/right/up/down,
  cyclic next/prev, missing neighbor, explicit target, existing active Space,
  silent/follow moves, and refusal with no state mutation.
- Query tests cover useful identities/geometry rather than incidental ordering.
- Prove changed/new assertions with a targeted mutation, alone; then run the
  repository verify gate. No build/test/lint while implementation agents edit.
- Run a real smoke scenario using temporary windows and restore the original
  arrangement: text navigation remains native; focus/swap chords work;
  selecting a Space uses its display; window moves land in the destination's
  shown Space and honor follow/stay; whole-Space relocation is separate.
- Scratch summons on the current screen and returns without losing the prior
  ordinary Space; silent send does not follow. Verify native fullscreen and
  monocle return independently on a disposable window.
- Reload and profile apply keep the intended permanent keymap active.
- Run Swift build, tests and lint, conditional release/ratchet checks per
  verify-gate, plus the site build for documentation changes.
- Record only checks actually exercised. Do not equate source inspection with
  live macOS behavior or claim Linux compositor equivalence.

## Progress

- Branch created from clean local main.
- Source comparison and live read-only API discovery completed.
- Implemented shared screen selectors, three display commands, topology queries,
  the preview-first installer, Lua helpers, and the documentation recipe.
- 2026-09-27: committed as d348929c after lint PASS, focused suite PASS
  (70 tests / 11 suites) and 9 mutation batches proving the new guards red.
-  Full-suite run: 6,587 tests, 3 residual failures in host-geometry float
  suites. Attribution closed: those suites PASS on this host in isolation on
  BOTH clean main (with only the compile fix) and this branch, and still pass
  with all of this branch's new/edited suites in one process — the failures
  are cross-suite pollution from other suites under full-run ordering, a
  pre-existing condition this host could never observe before (clean main
  cannot compile its test target on this CLT; CI is green) and out of scope
  here. Clean main not compiling locally is also why the ItemPadding split
  below is what makes local testing possible at all.
- 2026-09-27: installed the Developer-ID build with Sparkle keys stripped
  (local updater-disabled policy; previous adhoc app kept at
  ~/code/kiwidesk-config-backup/KiwiDesk-2.0.0-adhoc.app) and applied the
  config migration for real (backup at
  ~/.config/KiwiDesk/omarchy-backup-7c1xphyu; layers now default +
  omarchy-resize/system/passthrough, 100 bindings, no MacarchyKeys).
- This Command Line Tools installation requires explicit Testing framework,
  macro-plugin and runtime search paths; XCTest is absent and the repository
  tests use Swift Testing.
- The full run executed 6,587 tests in 1,266 suites and reported 28 issues.
  It also opened visible GUI test panels on the user's working desktop.
  The user reported the disruption; that test process has exited.
- Corrected three overlong command summaries and the whole-Space test's
  assumption that automatic empty-display healing cannot add a new pin.
  Existing pins are the preservation contract. All tests compile after these
  changes; the full suite has not been rerun.
- A pre-existing nested Space Bar fixture exceeded this compiler's type-checking
  limit. Its construction is split into explicit statements without changing
  the asserted behavior.
- Desktop-safe smoke passed: actual installer preview/apply on a disposable
  copy, preservation of unrelated fields, exact backup bytes, byte-stable
  repeat application, and the compiled CLI's new command catalog.
- Headless execution of the production Lua helper passed numeric cycling
  through Space 11, wraparound, deleted-history filtering, current-screen
  scratch summon, explicit return, deleted-return refusal, and monocle restore.
  The host API was simulated; this is not proof of macOS focus or window moves.

### Pending

The new build's changed signing identity requires one Accessibility re-grant;
the app is showing its Setup window and IPC is not up until the user clicks
it. Remaining once granted: reload_config, live smoke of screen focus and
window send/follow, scratch summon, cycling and one synthetic-chord check,
Attribution recorded above.

### Owner correction (2026-09-27, evening)

Window swaps ride bare Option+Shift+arrows (Super+Shift in Omarchy terms);
Control+Option+Shift+arrows is retired. Focus stays Control+Option+arrows
(Super+Ctrl). Word-by-word text selection on Option+Shift+arrows is the
accepted trade; bare Option+arrows stay native. Installer, boundary test
(red-proofed by reverting the tier), recipe docs and the live config all
carry the correction; reload_config applied it to the running app.
Do not describe the workflow as verified until that smoke passes.

### Second owner correction (2026-09-27, night)

Omarchy's unified direction verbs now ride the bare Super chords:
Option+arrow focuses the window — or, at the edge, the screen — in that
direction; Option+Shift+arrow swaps with a neighbor or moves the window
to that screen and follows. Enabling this needed a Lua bridge contract:
data-less dispatcher commands answer true/false in Lua (payload commands
unchanged), covered by LuaCommandVerdictTests; both the bridge and the
chord map are mutation-proofed. Native word/paragraph movement and
selection on Option/Option+Shift arrows is the accepted trade. Applied
live via the installer and reload_config.

### Personal distribution (2026-09-27, late)

The fork carries the owner's configuration: `personal/` (gui.json,
init.lua, profiles) plus `scripts/install-personal`, which builds and
installs the app with the updater stripped and syncs the configs with a
backup. Privacy-audited before vendoring (no usernames, paths, keys;
monitor model names only). The separate kiwidesk-config-backup repo is
retired; the local copy remains as the rollback holder.
