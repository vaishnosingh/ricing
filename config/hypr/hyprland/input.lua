local vars = require("variables")

hl.config({
    input = {
        kb_layout          = "us",
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        focus_on_close     = 1,
        sensitivity        = 0.0,
        accel_profile      = "adaptive",

        touchpad           = {
            natural_scroll       = true,
            tap_to_click         = true,
            tap_and_drag         = true,
            drag_lock            = false,
            clickfinger_behavior = true,
            disable_while_typing = false,
            scroll_factor        = 1.0,
        },
    },

    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },
})

hl.device({
    name                 = "ven_27c6:00-27c6:0d45-touchpad",
    sensitivity          = 0.0,
    tap_to_click         = true,
    tap_and_drag         = true,
    natural_scroll       = true,
    clickfinger_behavior = true,
    disable_while_typing = false,
})

hl.device({
    name        = "ven_27c6:00-27c6:0d45-mouse",
    sensitivity = 0.0,
})
