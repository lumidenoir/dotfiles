-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
-- local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")
local dpi = beautiful.xresources.apply_dpi
-- Autostart applications
HOME = "/home/lumi/"
awful.spawn.with_shell(HOME .. ".config/awesome/autostart.sh")
-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    os.execute(string.format('notify-send -u critical "Oops, there were errors during startup!" "%s"', awesome.startup_errors:gsub('"', '\\"')))
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        os.execute(string.format('notify-send -u critical "Oops, an error happened!" "%s"', tostring(err):gsub('"', '\\"')))
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(HOME .. ".config/awesome/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "kitty"
editor = "nvim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.floating,
--    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
--    awful.layout.suit.fair.horizontal,
--    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
--    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
--    awful.layout.suit.corner.nw,
--    awful.layout.suit.corner.ne,
--    awful.layout.suit.corner.sw,
--    awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()
local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9"}, s, awful.layout.layouts[1])
end)
-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))

-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "a",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Up",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Down",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "Right",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "Left",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey,  "Shift"  }, "Right", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey,  "Shift"  }, "Left", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),


-- FUNCTION KEYS
   awful.key({}, "XF86AudioRaiseVolume",
      function()
         awful.spawn("settings_control.sh volup")
      end,
      {description = "volume up", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioLowerVolume",
      function()
         awful.spawn("settings_control.sh voldown")
      end,
      {description = "volume down", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioMute",
      function()
         awful.spawn("settings_control.sh volmute")
      end,
      {description = "toggle mute", group = "hotkeys"}
   ),
   awful.key({}, "XF86MonBrightnessUp",
      function()
         awful.spawn("settings_control.sh briup")
      end,
      {description = "inc brightness", group = "hotkeys"}
   ),
   awful.key({}, "XF86MonBrightnessDown",
      function()
         awful.spawn("settings_control.sh bridown")
      end,
      {description = "dec brightness", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioPrev",
      function()
         awful.spawn("playerctl previous")
      end,
      {description = "dec brightness", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioNext",
      function()
         awful.spawn("playerctl next")
      end,
      {description = "dec brightness", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioPlay",
      function()
         awful.spawn("playerctl play-pause")
      end,
      {description = "dec brightness", group = "hotkeys"}
   ),

-- SCREENSHOT SHORT CUT --
    awful.key({},"Print", function () awful.spawn("screenshot.sh") end,
             {description = "Screenshot", group = "hotkeys"}),
    awful.key({modkey,            },"Print", function () awful.spawn("screenshot.sh --sel") end,
             {description = "Screenshot region", group = "hotkeys"}),
    awful.key({modkey,  "Control" },"Print", function () awful.spawn("screenshot.sh --stop") end,
             {description = "Stop recording", group = "hotkeys"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "KP_Add",     function() awful.tag.incmwfact( 0.05) end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "KP_Subtract",     function() awful.tag.incmwfact(-0.05) end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function() awful.layout.inc(1) end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),


    awful.key({ modkey }, "space", function() awful.util.spawn("rofi -show drun") end,
              {description = "show app launcher(rofi)", group = "launcher"}),

    awful.key({ "Mod1",   }, "l",      function () awful.spawn("screenlock.sh") end,
              {description = "lock-screen", group = "launcher"}),
    awful.key({ "Mod1",   }, "p",      function ()  awful.util.spawn("powermenu.sh") end,
              {description = "powermenu", group = "launcher"}),
    awful.key({ modkey,   }, "s",      function ()  awful.spawn("spotlight.sh") end,
              {description = "smart-search", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ "Mod1",   }, "q",      function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #i", group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #i", group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #i", group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #i", group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end,
    {description = "focus selected client", group = "mouse"}),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end,
    {description = "Move selected client", group = "mouse"}),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end,
    {description = "Resize client", group = "mouse"})
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = {border_width = beautiful.border_width,
                    border_color = beautiful.border_normal,
                    focus = awful.client.focus.filter,
	                maximized_vertical = false,
		            maximized_horizontal = false,
                    raise = true,
                    keys = clientkeys,
		            titlebars_enabled = false,
                    buttons = clientbuttons,
                    screen = awful.screen.preferred,
                    opacity=1,
                    maximized=false,
                    --floating=false,
                    placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "dialog" }
      }, properties = { titlebars_enabled = true }
    },
    { rule_any = {
        class = { "Polybar" }, -- Replace "Polybar" with the actual WM_CLASS
        name  = { "polybar" }  -- Replace "polybar" with the actual _NET_WM_NAME if needed
        },
    properties = {
        border_width = 0,
        focusable = false,
        below = true
        }
    },

}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)



-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

	awful.titlebar(c, { position = "top", size = dpi(36), font = beautiful.font, bg = beautiful.gruv_base })
		:setup({
			{
				layout = wibox.layout.align.horizontal,
				{ --- Left
					{
						{
							awful.titlebar.widget.closebutton(c),
							margins = { top = dpi(7), bottom = dpi(7), left = dpi(3), right = dpi(3) },
							widget = wibox.container.margin,
						},
						{
							awful.titlebar.widget.minimizebutton(c),
							margins = { top = dpi(7), bottom = dpi(7), left = dpi(3), right = dpi(3) },
							widget = wibox.container.margin,
						},
						{
							awful.titlebar.widget.maximizedbutton(c),
							margins = { top = dpi(7), bottom = dpi(7), left = dpi(3), right = dpi(3) },
							widget = wibox.container.margin,
						},
						layout = wibox.layout.fixed.horizontal,
					},
					top = dpi(2),
					bottom = dpi(2),
					left = dpi(8),
					widget = wibox.container.margin,
				},
				{ --- Middle
					{ --- Title
						align = "center",
						font = beautiful.font,
						widget = awful.titlebar.widget.titlewidget(c),
						buttons = {
							--- Move client
							awful.button({
								modifiers = {},
								button = 1,
								on_press = function()
									c.maximized = false
									c:activate({ context = "mouse_click", action = "mouse_move" })
								end,
							}),

							--- Kill client
							awful.button({
								modifiers = {},
								button = 2,
								on_press = function()
									c:kill()
								end,
							}),

							--- Resize client
							awful.button({
								modifiers = {},
								button = 3,
								on_press = function()
									c.maximized = false
									c:activate({ context = "mouse_click", action = "mouse_resize" })
								end,
							}),

							--- Side button up
							awful.button({
								modifiers = {},
								button = 9,
								on_press = function()
									c.floating = not c.floating
								end,
							}),

							--- Side button down
							awful.button({
								modifiers = {},
								button = 8,
								on_press = function()
									c.ontop = not c.ontop
								end,
							}),
						},
					},
					layout = wibox.layout.flex.horizontal,
				},
				--- Right
				{
					{
            widget = awful.widget.clienticon(c)
					},
					top = dpi(6),
					bottom = dpi(6),
					right = dpi(12),
					widget = wibox.container.margin,
				},
			},
			bg = beautiful.gruv_base,
			shape = gears.shape.rounded_rect,
			widget = wibox.container.background,
		})
	awful
		.titlebar(c, {
			position = "bottom",
			size = dpi(18),
			bg = beautiful.gruv_base,
		})
		:setup({
			bg = beautiful.gruv_base,
			shape = gears.shape.rounded_rect,
			widget = wibox.container.background,
		})
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = true})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

screen.connect_signal("request::desktop_decoration", function(s)
	local layout_list = awful.widget.layoutlist({
		source = awful.widget.layoutlist.source.default_layouts, --- DOC_HIDE
		spacing = dpi(24),
		base_layout = wibox.widget({
			spacing = dpi(24),
			forced_num_cols = 4,
			layout = wibox.layout.grid.vertical,
		}),
		widget_template = {
			{
				{
					id = "icon_role",
					forced_height = dpi(68),
					forced_width = dpi(68),
					widget = wibox.widget.imagebox,
				},
				margins = dpi(24),
				widget = wibox.container.margin,
			},
			id = "background_role",
			forced_width = dpi(68),
			forced_height = dpi(68),
			widget = wibox.container.background,
		},
	})

	local layout_popup = awful.popup({
		widget = wibox.widget({
			{ layout_list, margins = dpi(24), widget = wibox.container.margin },
			bg = beautiful.black,
			shape = gears.shape.rounded_rect,
			widget = wibox.container.background,
		}),
		placement = awful.placement.centered,
		ontop = true,
		visible = false,
		bg = beautiful.gruv_base,
	})

	function gears.table.iterate_value(t, value, step_size, filter, start_at)
		local k = gears.table.hasitem(t, value, true, start_at)
		if not k then
			return
		end

		step_size = step_size or 1
		local new_key = gears.math.cycle(#t, k + step_size)

		if filter and not filter(t[new_key]) then
			for i = 1, #t do
				local k2 = gears.math.cycle(#t, new_key + i)
				if filter(t[k2]) then
					return t[k2], k2
				end
			end
			return
		end

		return t[new_key], new_key
	end
local function toggle_layout_popup()
        layout_popup.visible = not layout_popup.visible
    end

    -- Function to safely get the current layout and iterate
    local function cycle_layout(step)
        if layout_list.layouts and layout_list.current_layout then
            local new_layout = gears.table.iterate_value(
                layout_list.layouts,
                layout_list.current_layout,
                step
            )
            if new_layout then
                awful.layout.set(new_layout)
            end
        end
    end

    -- Add keybindings to toggle the popup and cycle layouts
 local function reset_modkey_state()
        root.keys(root.keys()) -- Reapply global keybindings
    end

    -- Add keybindings to toggle the popup and cycle layouts
globalkeys = gears.table.join(globalkeys,
    awful.key(
        { "Mod1" }, "space", -- Example: Alt + Space
        function()
            if not layout_popup.visible then
                toggle_layout_popup()
                cycle_layout(1)
            else
                cycle_layout(1)
            end
            reset_modkey_state()
        end,
        { description = "cycle layout forward", group = "layout" }
    ),
    awful.key(
        { "Mod1", "Shift" }, "space",
        function()
            if not layout_popup.visible then
                toggle_layout_popup()
                cycle_layout(-1)
            else
                -- If popup is visible, just cycle layout forward
                cycle_layout(1)
            end
            reset_modkey_state()  -- Reapply global keybindings after toggle
        end,
        { description = "cycle layout backward", group = "layout" }
    ),
    awful.key(
        { "Mod1" }, "Escape",
        function()
            if layout_popup.visible then
                toggle_layout_popup() -- Close popup
            end
        end,
        { description = "close layout popup", group = "layout" }
    )
)
    -- Update the keybindings
    root.keys(globalkeys)
end)
-- }}}
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
gears.timer({
	timeout = 5,
	autostart = true,
	call_now = true,
	callback = function()
		collectgarbage("collect")
	end,
})
