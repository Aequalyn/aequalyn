------------------------------------------------------------------------ input
hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


-------------------------------------------------------------------------- misc
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    layers = {
        allow_new_top_layers_over_existing_fullscreen = true,
    },
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
})
