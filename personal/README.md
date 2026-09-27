# Personal setup

This fork is a private KiwiDesk distribution: the code **and** the
owner's configuration. One command makes a machine match it.

```sh
scripts/install-personal
```

## What it does

1. Builds the app (`scripts/build-app.sh`), strips Sparkle's
   updater keys (a local build must never update itself over the
   release channel), re-signs, quits the running app, swaps
   `/Applications/KiwiDesk.app`, relaunches.
2. Syncs this directory — `gui.json`, `init.lua`, `profiles/` —
   into `~/.config/KiwiDesk`, backing up everything it replaces
   to `~/.config/KiwiDesk/personal-backup-<timestamp>/`.
3. Reloads the config and, when the active profile is not
   `My Setup - laptop` (a new machine's display fingerprint will
   not match its saved monitor set), loads it explicitly so its
   settings apply: every Space in Scrolling, borders off, the
   occupied-Spaces menu-bar readout (`1³ 2¹` style).

Options: `--config-only`, `--app-only`.

## New machine notes

- **Accessibility**: allow it once when macOS asks. With the
  Developer ID identity imported into that machine's keychain the
  grant survives rebuilds; the ad-hoc fallback re-asks per build.
- To make a machine's own display join the profile permanently,
  run `kiwidesk save_profile "My Setup - laptop"` there once, then
  commit the updated `profiles/` back.
- The keymap (Omarchy-style, Option as Super) is in
  `gui.json`'s `default` layer; the reference with every chord is
  [`docs/recipes/omarchy.md`](../docs/recipes/omarchy.md). Lua
  helpers (Space cycling, scratch, direction verbs) live in
  `init.lua` between the `BEGIN/END KiwiDesk Omarchy helpers`
  markers — regenerate with `scripts/omarchy-config --apply`,
  never edit inside the markers.

## Syncing changes back

After changing shortcuts, Spaces or settings on any machine:

```sh
cp ~/.config/KiwiDesk/gui.json personal/gui.json
cp ~/.config/KiwiDesk/init.lua personal/init.lua
cp ~/.config/KiwiDesk/profiles/*.json personal/profiles/
```

…then commit and push. The installer is the only writer in the
other direction.
