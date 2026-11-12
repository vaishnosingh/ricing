local vars = require("variables")

-- App preferences
vars.browser  = "brave-browser"
vars.terminal = "kitty"

-- Native 1:1 Display Scale (prevent applications from being zoomed in)
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1.0})
hl.config({ xwayland = { force_zero_scaling = true } })

