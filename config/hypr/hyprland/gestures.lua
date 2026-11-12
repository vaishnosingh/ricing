local vars = require("variables")

-- Gesture Sensitivity & Distance:
-- workspace_swipe_distance: 250px (increased 25% from 200px for natural travel)
-- workspace_swipe_cancel_ratio: 0.15 (effortless trigger threshold)
-- workspace_swipe_min_speed_to_force: 5 (low velocity threshold for instant commit)
-- workspace_swipe_direction_lock_threshold: 5
hl.config({
    gestures = {
        workspace_swipe_distance                 = 250,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 5,
        workspace_swipe_create_new               = true,
    },
})

-- 3-Finger Gestures
-- 3-finger horizontal: Fast, responsive 1:1 Workspace switching
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 3-finger swipe up: Application Launcher (shell:launcher)
hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = {
        finish = function()
            hl.dispatch(hl.dsp.global("shell:launcher"))
        end,
    },
})

-- 3-finger swipe down: Altar Dashboard / Control Center (shell:altar)
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = {
        finish = function()
            hl.dispatch(hl.dsp.global("shell:altar"))
        end,
    },
})

-- 3-finger pinch in: Terminal (Kitty)
hl.gesture({
    fingers   = 3,
    direction = "pinchin",
    action    = {
        finish = function()
            hl.exec_cmd(vars.terminal)
        end,
    },
})

-- 3-finger pinch out: Default browser (Brave)
hl.gesture({
    fingers   = 3,
    direction = "pinchout",
    action    = {
        finish = function()
            hl.exec_cmd(vars.browser)
        end,
    },
})

-- 4-Finger Gestures
-- 4-finger swipe up: Toggle Special Workspace (scratchpad)
hl.gesture({ fingers = 4, direction = "up", action = "special", workspace_name = "special" })

-- 4-finger swipe down: Dismiss Special Workspace or Close Active Window
hl.gesture({
    fingers   = 4,
    direction = "down",
    action    = {
        finish = function()
            local special = hl.get_active_special_workspace()
            if special then
                hl.dispatch(hl.dsp.workspace.toggle_special("special"))
            else
                hl.dispatch(hl.dsp.window.close())
            end
        end,
    },
})

-- 4-finger horizontal: Cycle window focus
hl.gesture({
    fingers   = 4,
    direction = "left",
    action    = {
        finish = function()
            hl.dispatch(hl.dsp.window.cycle_next(true))
        end,
    },
})
hl.gesture({
    fingers   = 4,
    direction = "right",
    action    = {
        finish = function()
            hl.dispatch(hl.dsp.window.cycle_next(false))
        end,
    },
})

-- 4-finger pinch in: Default file manager (Thunar)
hl.gesture({
    fingers   = 4,
    direction = "pinchin",
    action    = {
        finish = function()
            hl.exec_cmd(vars.fileManager)
        end,
    },
})

-- 4-finger pinch out: Super + I (Settings / Preferences)
hl.gesture({
    fingers   = 4,
    direction = "pinchout",
    action    = {
        finish = function()
            hl.dispatch(hl.dsp.global("shell:settings"))
        end,
    },
})

-- 5-Finger Gestures
-- 5-finger swipe down: Suspend / Sleep
hl.gesture({
    fingers   = 5,
    direction = "down",
    action    = {
        finish = function()
            hl.exec_cmd(vars.sleepGestureCmd)
        end,
    },
})
