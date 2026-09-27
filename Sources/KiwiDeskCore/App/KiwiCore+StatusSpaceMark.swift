import AppKit

/// What the menu bar item draws for the active layer and, while
/// the Space Bar is off, for the Space each screen shows (#1413).
/// The layer's menu-bar glyph has this one derivation, over
/// `activeLayerGlyph`. Core hands structure; the GUI draws and
/// names it (#96).
public struct StatusSpaceMark: Equatable {
    /// The bar's own identifier ladder, carried across with its
    /// tint bit: an untinted text glyph is an emoji, which takes
    /// no template tint.
    public enum Glyph: Equatable {
        case symbol(String)
        case text(String, tinted: Bool)

        public var keepsColour: Bool {
            if case .text(_, tinted: false) = self { return true }
            return false
        }

        init(_ identifier: SpaceGlyph) {
            switch identifier {
            case .symbol(let name): self = .symbol(name)
            case .text(let text, let tinted):
                self = .text(text, tinted: tinted)
            }
        }
    }

    public struct Layer: Equatable {
        public let name: String
        /// The icon, or the monogram where there is none — which
        /// `hasIcon` tells apart, since the bar-on item keeps the
        /// brand glyph for an icon-less layer (owner ruling).
        public let glyph: Glyph
        public let hasIcon: Bool
    }

    public struct Screen: Equatable {
        public let display: Display
        public let space: SpaceID
        public let glyph: Glyph
    }

    /// One occupied Space for the menu bar's list readout:
    /// its id, how many windows it holds, and whether it is
    /// the active one (fork-local surface, 2026-09-27).
    public struct Occupied: Equatable {
        public let space: SpaceID
        public let windows: Int
        public let active: Bool
    }

    /// nil on `default`, which has no icon.
    public let layer: Layer?
    /// One per display showing a Space, unordered — the GUI
    /// ranks them (`DeskOrder`). Empty while the bar is on.
    public let screens: [Screen]
    /// Every Space holding windows (the active Space always
    /// included), in profile order — empty unless the setting
    /// is on and the Space Bar is off.
    public var occupied: [Occupied] = []
}

extension KiwiCore {
    func statusSpaceMark() -> StatusSpaceMark {
        let layer = activeLayerGlyph().map {
            StatusSpaceMark.Layer(
                name: $0.name,
                glyph: StatusSpaceMark.Glyph($0.glyph),
                hasIcon: $0.hasIcon
            )
        }
        guard !tiler.settings.spaceBarStyle.enabled else {
            return StatusSpaceMark(layer: layer, screens: [])
        }
        let screens = state.workspaces.allDisplays.compactMap {
            display -> StatusSpaceMark.Screen? in
            // SHOWN, not focused (#1214): the item names what
            // each screen is displaying.
            guard
                let space = state.workspaces.currentSpace(
                    on: display.id
                )
            else { return nil }
            return StatusSpaceMark.Screen(
                display: display,
                space: space,
                glyph: StatusSpaceMark.Glyph(spaceGlyph(for: space))
            )
        }
        // The occupied list readout (fork-local): the active
        // Space stays listed even while it holds nothing.
        let active = state.workspaces.activeSpace
        let occupied: [StatusSpaceMark.Occupied] =
            tiler.settings.statusOccupiedSpaces
            ? state.workspaces.allSpaces
                .filter {
                    !$0.windows.isEmpty || $0.id == active
                }
                .map {
                    StatusSpaceMark.Occupied(
                        space: $0.id,
                        windows: $0.windows.count,
                        active: $0.id == active
                    )
                }
            : []
        return StatusSpaceMark(
            layer: layer,
            screens: screens,
            occupied: occupied
        )
    }

    /// Publishes the mark off the bar's own refresh, so every
    /// trigger the bar has — retile, layer switch, Desktop
    /// settle — reaches the menu bar too.
    func publishStatusSpaceMark() {
        spaceBars.publishStatusMark(statusSpaceMark())
    }
}
