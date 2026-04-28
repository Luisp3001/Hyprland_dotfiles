local wal = require("colors")

hl.config({
    general = {
        gaps_in = 10,
        gaps_out = 20,
        border_size = 3,

        col = {
            active_border = { colors = { wal.colors.color1, wal.colors.color2 }, angle = 90 },
            inactive_border = wal.colors.bg
        },

        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },

    decoration = {
        active_opacity = 1,
        inactive_opacity = 1,
        rounding = 5,
        rounding_power = 2,

        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            new_optimizations = true,
            ignore_opacity = false,
        },

        shadow = {
            enabled = true,
            range = 30,
            render_power = 2,
            offset = { 3, 3 },
            color = wal.bg,
        },

    },

    animations = {
        enabled = true
    },

    dwindle = {
        preserve_split = true
    }
})

hl.curve("iosEaseInOut",   { type = "bezier", points = { {0.25, 0.1},    {0.25, 1}    } })
hl.curve("iosSlide", { type = "bezier", points = { {0.33, 1}, {0.68, 1}    } })

hl.animation({ leaf = "windows", enabled = true,  speed = 6, bezier = "iosEaseInOut", style = "popin 50%" })
hl.animation({ leaf = "workspaces", enabled = true,  speed = 7, bezier = "iosSlide", style = "slide" })
hl.animation({ leaf = "fade", enabled = true,  speed = 8, bezier = "iosEaseInOut" })
hl.animation({ leaf = "border", enabled = true,  speed = 10, bezier = "iosEaseInOut" })
hl.animation({ leaf = "borderangle", enabled = true,  speed = 100, bezier = "iosEaseInOut", style = "loop" })
hl.animation({ leaf = "layersIn", enabled = true,  speed = 6, bezier = "default", style = "slide right" })
hl.animation({ leaf = "layersOut", enabled = true,  speed = 6, bezier = "default", style = "slide right" })


