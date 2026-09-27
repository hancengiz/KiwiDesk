-- KiwiDesk configuration
-- Docs: https://github.com/KiwiCanopy/KiwiDesk
--
-- Everyday settings live in the Settings window;
-- this file is for optional custom Lua. Comments
-- only by default — the built-in defaults apply
-- until a line below is uncommented.

-- One value for all gaps (the built-in default):
-- KiwiDesk.set_gap_global(10)

-- Every Space has its own layout; the first
-- argument is the SPACE id (number or name),
-- never a monitor. All Spaces
-- default to "bsp". Modes: bsp | stack |
-- scrolling | monocle | grid | floating
-- KiwiDesk.set_mode(1, "stack")
-- KiwiDesk.set_mode("music", "floating")

-- Windows that should never be tiled:
-- float_rules = { "com.apple.calculator" }

-- Apps KiwiDesk should never manage at all:
-- ignore_rules = { "eu.exelban.Stats" }

-- Send apps to fixed Spaces:
-- app_rules = {
--   ["com.spotify.client"] = "music"
-- }

-- Load a saved profile per macOS Desktop
-- (the Mission Control number):
-- KiwiDesk.bind_profile_to_desktop(
--     2, "Creator Studio")

-- Keybindings:
-- KiwiDesk.bind("cmd+alt+left", function()
--     KiwiDesk.focus("left")
-- end)

-- BEGIN KiwiDesk Omarchy helpers
-- Session-only history; structured shortcuts remain GUI-managed.
OmarchyKeys = {
    currentSpace = KiwiDesk.get_state().active_space,
    history = {},
    returnSpace = nil,
    returnModes = {},
}

local function spacesByID(state)
    local result = {}
    for _, space in ipairs(state.spaces or {}) do
        result[space.id] = space
    end
    return result
end

KiwiDesk.on("space_change", function(id)
    if id == OmarchyKeys.currentSpace then return end
    local existing = spacesByID(KiwiDesk.get_state())
    local history, seen = {}, {}
    local previous = OmarchyKeys.currentSpace
    if previous and previous ~= id and existing[previous] then
        history[1], seen[previous] = previous, true
    end
    for _, old in ipairs(OmarchyKeys.history) do
        if old ~= id and existing[old] and not seen[old] then
            history[#history + 1], seen[old] = old, true
        end
    end
    OmarchyKeys.history = history
    OmarchyKeys.currentSpace = id
end)

function OmarchyKeys.cycle(delta)
    local state, ids = KiwiDesk.get_state(), {}
    for _, space in ipairs(state.spaces or {}) do
        if space.id:match("^%d+$") then
            ids[#ids + 1] = space.id
        end
    end
    table.sort(ids, function(a, b)
        if tonumber(a) == tonumber(b) then return a < b end
        return tonumber(a) < tonumber(b)
    end)
    if #ids == 0 then return end
    local index = delta > 0 and 0 or 1
    for i, id in ipairs(ids) do
        if id == state.active_space then index = i; break end
    end
    KiwiDesk.focus_space(ids[(index - 1 + delta) % #ids + 1])
end

function OmarchyKeys.back()
    local state = KiwiDesk.get_state()
    local existing = spacesByID(state)
    for _, id in ipairs(OmarchyKeys.history) do
        if id ~= state.active_space and existing[id] then
            KiwiDesk.focus_space(id)
            return
        end
    end
end

function OmarchyKeys.scratch()
    local state = KiwiDesk.get_state()
    if state.active_space == "scratch" then
        local target = OmarchyKeys.returnSpace
        if target and target ~= "scratch" and spacesByID(state)[target] then
            KiwiDesk.focus_space(target)
        end
        return
    end
    if not state.active_space or not state.active_display then return end
    for _, monitor in ipairs(KiwiDesk.list_monitors()) do
        if monitor.id == state.active_display then
            KiwiDesk.move_space_to_display("scratch", monitor.fingerprint)
            local moved = spacesByID(KiwiDesk.get_state()).scratch
            if moved and moved.display == monitor.id then
                OmarchyKeys.returnSpace = state.active_space
                KiwiDesk.focus_space("scratch")
            end
            return
        end
    end
end

function OmarchyKeys.sendScratch()
    KiwiDesk.move_to_space("scratch")
end

function OmarchyKeys.moveSpace(direction)
    local id = KiwiDesk.get_state().active_space
    if id then KiwiDesk.move_space_to_display(id, direction) end

-- Omarchy's direction verbs: act on the window neighbor in that
-- direction, else on the screen in that direction. The bridge
-- answers true/false for these data-less commands, so a failed
-- window probe falls through to the screen verb.
function OmarchyKeys.focusDirection(direction)
    if KiwiDesk.focus(direction) then return end
    KiwiDesk.focus_display(direction)
end

function OmarchyKeys.moveDirection(direction)
    if KiwiDesk.swap(direction) then return end
    KiwiDesk.move_to_display_and_follow(direction)
end
end

-- The mode-changing function is supplied by the structured shortcut.
-- Merely loading this file never declares a layout preference.
function OmarchyKeys.monocle(changeMode)
    local layout = KiwiDesk.get_layout_info()
    if not layout then return end
    if layout.mode == "monocle" then
        changeMode(layout.space_id,
            OmarchyKeys.returnModes[layout.space_id] or "scrolling")
    else
        OmarchyKeys.returnModes[layout.space_id] = layout.mode
        changeMode(layout.space_id, "monocle")
    end
end
-- END KiwiDesk Omarchy helpers
