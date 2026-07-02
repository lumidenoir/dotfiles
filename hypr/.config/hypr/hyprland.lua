-- 1. MONITORS
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "auto",
    scale = "1"
})

-- 2. AUTOSTART
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("awww-daemon & sleep 0.1 && awww restore")
    -- hl.exec_cmd("waybar -c ~/.config/waybar/hypr/config.json -s ~/.config/waybar/hypr/style.css")
    hl.exec_cmd("quickshell -p ~/dotfiles/quickshell")
    -- hl.exec_cmd("dunst")
    hl.exec_cmd("auto_network_switch.sh & mpd & mpDris2 &")
    hl.exec_cmd("~/dotfiles/scripts/Redshift.sh --auto &")
    hl.exec_cmd("pidof -q polkit-gnome-authentication-agent-1 || { /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & }")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("hypridle &")
-- hl.exec_cmd("kitty --class kitty-scratchpad", { workspace = "special:scratchpad silent" })
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'macOS'")
    hl.exec_cmd("hyprctl setcursor macOS 24")
end)

-- 3. ENVIRONMENT VARIABLES
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "macOS")
hl.env("GTK_THEME", "WhiteSur-Dark")

-- 4. CONFIGURATION
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.5,
        },
        sensitivity = 0 -- -1.0 - 1.0, 0 means no modification.
    },
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 1,
        col = {
            active_border = "0xccffffff",
            inactive_border = "0x33000000",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle"
    },
decoration = {
    rounding = 12,
    rounding_power = 2.0,

    shadow = {
        enabled = true,
        range = 20,           -- wider, softer spread vs tight 10
        render_power = 2,     -- lower = softer falloff (more macOS-like)
        color = "0x55000000", -- slightly more visible active shadow
        color_inactive = "0x18000000"
    },

    blur = {
        enabled = true,
        size = 6,
        passes = 3,
        new_optimizations = true,
        noise = 0.015,
        contrast = 1.12,
        brightness = 1.05,
        vibrancy = 0.25,
        vibrancy_darkness = 0.05
    },

    dim_inactive = true,
    dim_strength = 0.10,
    dim_special = 0.35
},
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false
    },
    master = {
        mfact = 0.6,
        new_status = "master",
    },
    scrolling = {
        fullscreen_on_one_column = true,
    },
    debug = {
        vfr = true
    }
})

-- 5. GESTURES
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Swipe down (3 fingers) to toggle Control Center
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("quickshell -p ~/dotfiles/quickshell ipc call qsIpc toggleGroundControl")
    end
})

hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd("quickshell -p ~/dotfiles/quickshell ipc call qsIpc toggleAirspace")
    end
})

-- Pinch to zoom (2 fingers)
-- hl.gesture({
--     fingers = 2,
--     direction = "pinch",
--     action = "cursorZoom",
--     zoom_level = 1,
--     mode = "live"
-- })

-- 6. WINDOW RULES
-- Clipse rules
hl.window_rule({
    match = { class = "clipse" },
    float = true, 
    size = { 622, 652 }
})

hl.window_rule({
    match = { class = "kitty-scratchpad" },
    float = true,
    size = { 1000, 800 },
    center = true,
})
-- Common dialog rules
hl.window_rule({
    match = { title = "^(Open File|Open Folder|Open|Save|Save As|Export|Import|Choose File|Rename|script-fu|kdenlive|brave)$" },
    float = true, 
    center = true
})

-- Rofi rule
hl.window_rule({
    match = { class = "Rofi" },
    stay_focused = true
})
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = "kitty -c ~/.config/kitty/mac-kitty.conf --class kitty-scratchpad" })
-- Quickshell layer rules (Frosted glass blur & macOS-style slide-down spawning)
hl.layer_rule({
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.2,
    animation = "false"
})

-- Rofi layer rules (macOS-style blur & premium pop-in zoom transition)
hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.2,
    animation = "popin 87%"
})

-- 7. KEYBINDINGS
local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty -c ~/.config/kitty/mac-kitty.conf"))
hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(0))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen(1))
hl.bind(mainMod .. " + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("powermenu.sh"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/dotfiles/scripts/screenlock.sh"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun -theme ~/.config/rofi/mac-hypr.rasi"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("quickshell -p ~/dotfiles/quickshell ipc call qsIpc toggleGroundControl"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("kitty -c ~/.config/kitty/mac-kitty.conf --class clipse -e 'clipse'"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("spotlight.sh"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("quickshell -p ~/dotfiles/quickshell ipc call qsIpc toggleAirspace"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("hyprctl getoption general:layout | grep -q dwindle && hyprctl eval \"hl.config({ general = { layout = 'master' } })\" || hyprctl eval \"hl.config({ general = { layout = 'dwindle' } })\""))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/dotfiles/scripts/keybindings.py"))
-- hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("waybar -c ~/.config/waybar/hypr/config.json -s ~/.config/waybar/hypr/style.css"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("pkill quickshell || quickshell -p ~/dotfiles/quickshell"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("(pkill -x hypridle || hypridle &) && pkill -USR1 -f quickshell_stats.sh"))
-- Toggle persistent Quake-style scratchpad
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("scratchpad"))

-- Focus movement
hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + DOWN", hl.dsp.focus({ direction = "d" }))

-- Workspace switching
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse:scroll_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse:scroll_up", hl.dsp.focus({ workspace = "e-1" }))

-- Media keys
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("settings_control.sh brightness_down"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("settings_control.sh brightness_up"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("settings_control.sh volume_up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("settings_control.sh volume_down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("settings_control.sh volume_mute"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("settings_control.sh play_pause"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("settings_control.sh play_prev"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("settings_control.sh play_next"))

-- Screenshot
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("screenshot.sh --sel"))
hl.bind("Print", hl.dsp.exec_cmd("screenshot.sh"))
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd("screenshot.sh --stop"))

-- Resize Submap
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 15, y = 0, relative = true }))
    hl.bind("left", hl.dsp.window.resize({ x = -15, y = 0, relative = true }))
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -15, relative = true }))
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 15, relative = true }))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

--hl.curve("easeOutQuint", { type = "bezier", points = { {0.83, 0}, {0.17, 1} } })
--hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
--hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
--hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
--hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
--hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
--hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

-- Curves
hl.curve("rotorEase",        { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })
hl.curve("rotorEaseOut",     { type = "bezier", points = { {0.16, 1.0}, {0.3,  1.0} } })
hl.curve("droneSpring",      { type = "spring", mass = 1, stiffness = 140, dampening = 22 })  -- softer open
hl.curve("droneFluidSpring", { type = "spring", mass = 1, stiffness = 110, dampening = 24 })  -- slower, zero bounce

-- Global / borders
hl.animation({ leaf = "global",        enabled = true, speed = 5.5,  bezier = "rotorEase" })
hl.animation({ leaf = "border",        enabled = true, speed = 4.0,  bezier = "rotorEase" })

-- Windows
hl.animation({ leaf = "windows",       enabled = true, speed = 4.8,  spring = "droneSpring" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.8,  spring = "droneSpring",      style = "popin 67%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3.2,  bezier = "rotorEase",        style = "popin 67%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 3.5,  spring = "droneFluidSpring" })

-- Fades
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3.2,  bezier = "rotorEase" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3.8,  bezier = "rotorEase" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.8,  bezier = "rotorEase" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3.8,  bezier = "rotorEase" })

-- Layers
hl.animation({ leaf = "layers",        enabled = true, speed = 5.5,  bezier = "rotorEaseOut" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 5.2,  bezier = "rotorEaseOut",     style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 5.5,  bezier = "rotorEase",        style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3.0,  bezier = "rotorEase" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3.2,  bezier = "rotorEase" })

-- Workspaces
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5.0, spring = "droneFluidSpring", style = "slide" })
hl.animation({ leaf = "workspacesIn",     enabled = true, speed = 5.5, spring = "droneFluidSpring", style = "slide" })
hl.animation({ leaf = "workspacesOut",    enabled = true, speed = 5.5, spring = "droneFluidSpring", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5.5, spring = "droneFluidSpring", style = "slidevert" })
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 5.5, spring = "droneFluidSpring" })

local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Native Lua Layer Rules for Quickshell Widgets & Overview blur
hl.layer_rule({
    name  = "quickshell-widgets-blur",
    match = { namespace = "quickshell_widgets" },
    blur  = true,
    ignore_alpha = 0.05
})

hl.layer_rule({
    name  = "quickshell-airspace-blur",
    match = { namespace = "quickshell_airspace" },
    blur  = true,
    ignore_alpha = 0.05
})

hl.layer_rule({
    name  = "flight-deck-blur",
    match = { namespace = "flight_deck" },
    blur  = true,
    ignore_alpha = 0.05
})

