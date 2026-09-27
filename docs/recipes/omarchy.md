---
title: Omarchy-compatible Workflow
description: A GUI-managed keyboard workflow for KiwiDesk Spaces,
  screens, scratch, and native layouts on macOS.
---

# Omarchy-compatible workflow

:::unreleased

This opt-in recipe brings Omarchy's window/Space/screen workflow to
KiwiDesk without replacing its layouts or requiring a remapper. It uses
KiwiDesk BSP, Scrolling, Monocle and other native layouts, **not** Hyprland
Dwindle, pseudotiling or window groups. It does not port the Linux desktop
utility suite. Existing app launchers and modal utilities are retained
when migrating the known Macarchy configuration.

## Preview and install

Use a KiwiDesk build containing `focus_display`, `move_to_display` and
`move_to_display_and_follow`, with relative display targets and display
identities in `get_state`/`list_monitors`. Python 3 is required for the
installer; no Python process runs after installation.

From the matching KiwiDesk source checkout:

```sh
# Read-only: inspect the proposed changes first.
python3 scripts/omarchy-config --config-dir "$HOME/.config/KiwiDesk"

# Explicitly back up and apply to that directory.
python3 scripts/omarchy-config --config-dir "$HOME/.config/KiwiDesk" --apply
```

There is **no implicit configuration directory** and preview never writes.
An empty directory gets a portable base with Spaces 1–10 and a Terminal
launcher. An existing configuration keeps its Space list; scratch is
created on demand by the normal Space movement commands. The installer
neither launches/reloads KiwiDesk nor starts applications. Reload manually
when ready, using KiwiDesk's Reload Config action or `kiwidesk reload_config`.
The main layer is `default`: no activation chord is needed after reload.

### Exactly what changes

- `gui.json`: replaces the default window/Space/screen controls with the
  table below. Migrates launchers and non-group utilities from
  `macarchy-like`, removes that obsolete layer, and renames
  `macarchy-resize`, `macarchy-system`, `macarchy-passthrough` to
  `omarchy-*`. Their exit actions return to `default`.
- `init.lua`: installs the contents of the reusable
  `scripts/omarchy-helpers.lua` inside `BEGIN/END KiwiDesk Omarchy helpers`
  comments. Only the exact known Macarchy helper section or this owned
  bounded section is replaced. Other authored hooks remain intact.
- App rules, settings, layout tuning, monitor pins, Space assignments,
  profile bindings and nonlegacy layers are preserved. No saved profile
  files are rewritten, and installation does not rearrange any Space.

Helpers contain no GUI-managed declarations: shortcuts remain editable
in Settings. The installer refuses unknown helper variants, Lua-owned
settings, conflicting custom shortcuts, duplicate chords or ambiguous
layer/marker collisions rather than silently discarding custom content.
Resolve the reported conflict manually and preview again. Reapplying an
unchanged recipe is a no-op; edits *inside* its owned helper block are
replaced, so keep unrelated custom hooks outside the markers.

Saved profiles may carry their own shortcut snapshots. Update such a
profile explicitly after migration if you want applying it to retain
this recipe; the installer does not overwrite saved profiles or their
layout settings. Interactive sizing and Lua session history are not
made durable by this recipe.
Deliberately authored per-profile shortcut overrides retain priority.

### Backup and restore

Before writing, the installer creates `omarchy-backup-*` in the selected
configuration directory. It contains the original bytes of each changed
file that existed and a `manifest.json` listing touched and previously
absent files. Unchanged files are not backed up or rewritten. Keep the
printed backup path.

To undo, quit KiwiDesk first. For each file listed in the manifest's
`touched` list, copy its backup over the configuration file. If the file
is listed in `absent`, remove the newly created configuration file
instead. Do not replace unrelated files or copy the manifest into
KiwiDesk's active configuration. Then reopen KiwiDesk. Restore both
`gui.json` and `init.lua` from the same backup when both were changed.

## Keyboard map

Omarchy **Super → Option**, **Alt → Command**, **Ctrl → Control**,
**Shift → Shift**. Super and Alt are deliberately distinct on macOS.
In this table, **arrow** means Left, Right, Up or Down; **digit** means
1–9 or 0 (Space 10).

| Chord | Action |
| --- | --- |
| Control+Option+arrow | Focus neighboring window |
| Option+Shift+arrow | Swap neighboring window |
| Control+Command+arrow | Focus neighboring screen's shown Space |
| Control+Command+Tab / +Shift+Tab | Next / previous screen, wrapping |
| Control+Command+Shift+arrow | Move window to neighboring screen and follow |
| Control+Option+Command+arrow | Send window to neighboring screen; stay here |
| Option+Command+Shift+arrow | Move the **whole current Space** to neighboring screen |
| Option+digit | Focus that globally named Space on its assigned screen |
| Option+Shift+digit | Move window to that Space and follow |
| Option+Command+Shift+digit | Send window to that Space; stay here |
| Option+Tab / Option+Shift+Tab | Next / previous existing numbered Space |
| Control+Option+Tab | Former still-existing Space |
| Option+S / Option+grave | Summon scratch / return to explicit source Space |
| Option+Command+S / Option+Shift+grave | Send window to scratch without following |
| Option+F | Monocle / previous layout for the entire Space |
| Control+Option+F | Native macOS fullscreen for the focused window |
| Option+L | Toggle Scrolling / BSP |
| Option+T | Toggle floating |
| Option+P | **Reset layout sizing to profile**, not pseudotile |
| Option+minus / Option+equal | Shrink / grow width by 100 |
| Option+Shift+minus / Option+Shift+equal | Shrink / grow height by 100 |
| Control+Option+minus / Control+Option+equal | Shrink / grow width by 25 |
| Option+W / Option+Q | Close focused window through Accessibility |
| Option+Return | Existing new-terminal action; Terminal on fresh installs |
| Option+K / Option+Space | Shortcut reference |
| Control+Option+comma | Settings |

The known migrated modal utilities retain Option+R (resize),
Option+Shift+Escape (system), and Option+semicolon (passthrough). Their
existing exit keys are preserved and return to `default`. Existing app
launchers keep their working actions; the shortcut reference shows them.
Fresh installs do not invent app-specific launcher or utility layers.

Screen arrows refuse a missing spatial neighbor without moving anything;
Tab screen cycling wraps. Window-to-screen commands target the Space
currently shown there, not a hardcoded Space number. Normal Space
activation honors its global display assignment. Sticky and native
fullscreen restrictions still apply: these shortcuts do not bypass
KiwiDesk's safety gates.

Space cycling sorts existing digit-named Spaces numerically,
including 11 and higher, skips names such as `scratch`, and wraps.
Former-Space history filters deleted Spaces and duplicate entries.

## Scratch, monocle and fullscreen are different

**Scratch is an ordinary KiwiDesk Space, not an overlay.** Summoning it
moves it to the active screen using that screen's current fingerprint,
remembers the explicit source Space, then focuses scratch. Toggling again
returns to that source if it still exists. This does not rewrite the
scratch Space's persistent monitor pin. Sending a window to scratch does
not summon or follow it. Other screens and Spaces retain their usual
lifecycle; no transparent compositor layer is involved.

**Monocle changes the whole Space's layout.** Toggling back restores the
mode remembered in this Lua session. If no prior mode was remembered
(for example after reload), it falls back to Scrolling. Former-Space
history and scratch return state also reset on reload.

**Native fullscreen changes the focused macOS window.** The AppleScript
uses `AXFocusedWindow`, not the first application window. macOS can create
a native fullscreen Space and animate its transition. Application support
and Accessibility/Automation permission still determine whether the action
succeeds. This is not equivalent to monocle.

There is **no saved-width bookmark** or app-specific width restore here.
Option+P resets native layout sizing to profile defaults. Interactive
resize values may be session-only; this recipe does not promise they
survive reload or profile application.

## macOS and application conflicts

- Bare Option+arrows stay unbound so native word navigation works.
  Option+Shift+arrows are bound to window swaps by the owner's ruling
  (2026-09-27): selecting text word-by-word with those chords is given up
  for Omarchy muscle memory — ⌘+Shift+arrows line selection is unaffected.
- Control+Option is VoiceOver's usual modifier. Focus, swap, fullscreen
  and former-Space chords can conflict when VoiceOver is enabled. Choose
  an accessible alternative in Settings rather than disabling assistive
  technology you use.
- Input-source switching can claim Control+Space or other customized
  combinations. Mission Control, keyboard shortcuts and third-party
  launchers may already claim related screen/Space chords. Review
  **System Settings → Keyboard → Keyboard Shortcuts** and the shortcut
  reference's conflict indicators; this recipe does not change macOS
  preferences for you.
- Control+Command+F is commonly native fullscreen in applications; this
  recipe uses **Control+Option+F** instead. Control+Command+arrows may
  already be app navigation shortcuts. Option+Command+Shift+digits can
  overlap application actions; global window-manager shortcuts win while
  active. Use the migrated passthrough layer or customize the conflict.
- Option combinations can produce accented/special characters on some
  keyboard layouts, and Option+Space is sometimes a launcher shortcut.
  The grave key is called `backtick` in configuration. Test your actual
  layout, particularly shifted digits and punctuation.
- Close/fullscreen AppleScripts may prompt for Automation access to
  System Events as well as Accessibility permission. Refusal is not
  solved by using another application's first window.

This is an intentional macOS adaptation, not a claim that every Omarchy
chord or Hyprland behavior is portable.
:::
