------------------
---- MONITORS ----
------------------

hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@100", position = "0x0",    scale = 1    })
hl.monitor({ output = "eDP-1",    mode = "2560x1600@120", position = "696x1440", scale = 1.25 })

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "wofi --show drun"
local browser     = "firefox"
local social      = "Telegram"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hyprpolkitagent")

    -- Put the panel on the refresh rate that matches the current power source.
    -- A udev rule handles every later charger change; this covers starting the
    -- session on battery, when no uevent is coming.
    hl.exec_cmd("display-power-mode")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 2,
        gaps_out    = 0,
        border_size = 2,

        col = {
            active_border   = "rgba(@base0D@80)",
            inactive_border = "rgba(00000000)",
        },

        resize_on_border = true,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 8,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Blur defaults to on and is the one decoration that costs GPU time on
        -- every frame that touches a translucent surface, idle or not.  Nothing
        -- here is translucent (both opacities are 1.0), so it was buying
        -- nothing.
        blur = {
            enabled = false,
        },

        shadow = {
            enabled      = false,
            range        = 2,
            render_power = 3,
            color        = "rgba(@base00@99)",
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0}  } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,

        -- 2 = adaptive sync for fullscreen windows only.  Kept as-is: this
        -- panel does not advertise adaptive sync at all (no `vrr_capable` on
        -- card1-eDP-1), so the setting is inert for the laptop display and only
        -- ever applies to an external monitor, which is on mains power anyway.
        vrr                     = 2,
    },

    -- VFR -- stop redrawing a screen whose contents have not changed -- is the
    -- single most valuable idle-power setting Hyprland has, and it is on by
    -- default.  It lives under `debug` since it was moved out of `misc`, whose
    -- `vfr` key no longer exists; stated here so a future config edit does not
    -- quietly resurrect the old key and assume it took effect.
    debug = {
        vfr = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ru",
        -- Caps Lock emits KEY_SCROLLLOCK: it is remapped at the hwdb level, not
        -- in xkb (see modules/hardware.nix), so grp:sclk_toggle is what puts the
        -- layout switch back onto that physical key. The option only rewrites
        -- the keysym of <SCLK>, never its keycode, so the raw 0x46 scancode the
        -- hwdb rule exists for still reaches a VM.
        kb_options = "grp:alt_shift_toggle,grp:sclk_toggle",

        follow_mouse = 1,

        sensitivity = 0.1,

        touchpad = {
            natural_scroll = true,
            scroll_factor  = 0.2,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(social))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + M",         hl.dsp.exit())
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("wlogout"))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot --clipboard-only -m region"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("hyprshot --raw -m region | satty --filename - --fullscreen current"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Hyprlang `fullscreen, 1` is the maximized/non-covering mode, `fullscreen, 0`
-- the real one. Keep that mapping rather than the more obvious key/name pairing.
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd([[cliphist list | wofi --dmenu --pre-display-cmd "echo '%s' | cut -f 2" | cliphist decode | wl-copy]]))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- SUPER + 1..9,0 -> workspaces 1..10, with SHIFT to move the active window there.
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0

    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + D",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s +10%"))

-- These were `bindl`: they keep working while the session is locked.
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({ match = { class = "^(pavucontrol)$" },           float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" },  float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" },       float = true })
hl.window_rule({ match = { class = "^(thunar)$", title = "^(File Operation Progress)$" },   float = true })
hl.window_rule({ match = { class = "^(thunar)$", title = "^(Confirm to replace files)$" },  float = true })
hl.window_rule({ match = { class = "^(thunar|org.xfce.thunar)$" }, float = true })
hl.window_rule({ match = { class = "^(firefox)$", title = "^(.*Opening.*)$" }, no_initial_focus = true })
