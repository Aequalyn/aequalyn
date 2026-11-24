------------------------------------------------------------------------- rules
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- A file chooser has no parent window to tile against; the title suffix is
-- how Aequalyn FM names its dialog windows (browsing windows never use it)
hl.window_rule({
    name = "float-aequalyn-fm-dialogs",
    match = { title = "^.+ — Aequalyn FM$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true,
              fullscreen = false, pin = false },
    no_focus = true,
})

hl.layer_rule({ name = "aequalyn-blur-shell",  match = { namespace = "quickshell-.*" }, blur = true })
hl.layer_rule({ name = "aequalyn-blur-aequalyn",   match = { namespace = "aequalyn-.*" },      blur = true })
hl.layer_rule({ name = "aequalyn-noanim-osd",  match = { namespace = "quickshell-osd" }, no_anim = true })
-- the full-screen panels (control center, pickers, clipboard, power menu, launcher, screens)
-- draw their own backdrop and transitions (style/backdrop in the shell): no fade of their own.
-- With "Instant" they are aequalyn-panel-*, blurred by the aequalyn-.* rule above.
hl.layer_rule({ name = "aequalyn-noanim-panels", match = { namespace = "aequalyn[-_]panel[-_].*" }, no_anim = true })
hl.layer_rule({ name = "aequalyn-ignorezero",  match = { namespace = "quickshell-.*" }, ignore_alpha = true })
hl.layer_rule({ name = "aequalyn-dock-noblur", match = { namespace = "aequalyn-dock-plain" }, blur = false, ignore_alpha = true })

