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
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
--beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
beautiful.init("~/.config/awesome/themes/theme.lua")

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

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()


---|_________ CUSTOM WIDGETS ________|---

local cornerRadius = 10

-- create custom shapes --
local roundedRectangle = function (cr, width, height)
    gears.shape.rounded_rect(cr, width, height, cornerRadius)
end

local leftRoundedRectangle = function (cr, width, height)
    gears.shape.partially_rounded_rect(cr, width, height, true, false, false, true, cornerRadius)

end

local rightRoundedRectangle = function (cr, width, height)
    gears.shape.partially_rounded_rect(cr, width, height, false, true, true, false, cornerRadius)
end

-- Clock widget
container_clock_widget = {
	{
	    {
		{
			{
				widget = mytextclock,
			},
			left = 6,
			right = 6,
			top = 0,
			bottom = 0,
			widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_surface2,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background
	    },
            left = 600,
	    top = 5,
	    bottom = 5,
	    halign = "center",
	    widget = wibox.container.margin,
	},
	spacing = 5,
	layout = wibox.layout.fixed.horizontal,
}

---| CREATE CUSTOM WIFI WIDGET |---

-- create empty textbox widget -- 
local text_wifi_name = wibox.widget{
    font = "Inconsolata Black 10",
    widget=wibox.widget.textbox
}

local update_wifi_name = function (wifi)
    text_wifi_name.text = " " .. wifi
end

-- fill the textbox widget with the output of the shell script --
gears.timer {
    timeout = 10,
    call_now = true,
    autostart = true,
    callback = function ()
        awful.spawn.easy_async("/home/krishna/.config/awesome/scripts/wifi.sh", function (stdout)
    local wifi = stdout
    update_wifi_name(wifi)

end)

    end
}

-- create a container for the widget -- 
container_wifi_widget = {
    {
        {
                {
                    widget=text_wifi_name,
                },
                left = 10,
		right = 10,
		top = 6,
		bottom = 6,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_green,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin,
}

---| CREATE CUSTOM BATTERY WIDGET |---

-- create empty textbox widget -- 
local text_batt_name = wibox.widget{
    font = "Inconsolata Black 12",
    widget=wibox.widget.textbox
}

local update_batt_name = function (batt)
    text_batt_name.text = "POW " .. batt
end

-- fill the textbox widget with the output of the shell script --
gears.timer {
    timeout = 5,
    call_now = true,
    autostart = true,
    callback = function ()
        awful.spawn.easy_async("/home/krishna/.config/awesome/scripts/battery.sh", function (stdout)
    local batt = stdout
    update_batt_name(batt)

end)

    end
}

-- create a container for the widget -- 
container_batt_widget = {
    {
        {
                {
                    widget=text_batt_name,
                },
                left = 10,
		right = 10,
		top = 0,
		bottom = 0,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_peach,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin,
}

---| CREATE CUSTOM VOLUME WIDGET |---
local text_volume= wibox.widget{
    font = "Inconsolata Black 10",
    widget=wibox.widget.textbox
}

local update_volume = function (vol)
    text_volume.text = " " .. vol
end

local container_volume_widget = {
    {
        {       text_volume,
                left = 10,
		right = 10,
		top = 6,
		bottom = 6,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_peach,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin,
}



-- check for volume every 1/2 seconds and update the value of the progressbar and the volume -- 

gears.timer {
    timeout = 0.5,
    call_now = true,
    autostart = true,
    callback = function ()
        awful.spawn.easy_async("/home/krishna/.config/awesome/scripts/volume.sh", function (stdout)
    local vol = stdout
    update_volume(vol)

end)

    end
}

volume_widget = {
    container_volume_widget,
    layout=wibox.layout.fixed.horizontal
}

--| CREATE A CUSTOM BRIGHTNESS WIDGET |--

-- create empty textbox widget -- 
local text_bt_name = wibox.widget{
    font = "Inconsolata Black 10",
    fg = beautiful.gruv_red,
    widget=wibox.widget.textbox
}

local update_bt_name = function (bt)
    text_bt_name.text = " " .. bt
end


-- create a container for the widget -- 
container_bt_widget = {
    {
        {
                {
                    widget=text_bt_name,
                },
                left = 10,
		right = 10,
		top = 4,
		bottom = 6,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_sky,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin,
}

-- fill the textbox widget with the output of the shell script --
gears.timer {
    timeout = 0.5,
    call_now = true,
    autostart = true,
    callback = function ()
        awful.spawn.easy_async("/home/krishna/.config/awesome/scripts/bright.sh", function (stdout)
	local bt = stdout
	update_bt_name(bt)
    end)
end
}

--| CREATE A CUSTOM RAM/CPU WIDGET |--

-- create empty textbox widget -- 
local text_ram_name = wibox.widget{
    font = "Inconsolata Black 12",
    fg = beautiful.gruv_red,
    widget=wibox.widget.textbox
}

local update_bt_name = function (ram)
    text_ram_name.text = "PAM " .. ram
end


-- create a container for the widget -- 
container_ram_widget = {
    {
        {
                {
                    widget=text_ram_name,
                },
                left = 10,
		right = 10,
		top = 6,
		bottom = 6,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_sky,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin,
}

-- fill the textbox widget with the output of the shell script --
gears.timer {
    timeout = 0.5,
    call_now = true,
    autostart = true,
    callback = function ()
        awful.spawn.easy_async("/home/krishna/.config/awesome/scripts/perfor.sh", function (stdout)
	local ram = stdout
	update_bt_name(ram)
    end)
end
}

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

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
    awful.tag({ " 一 ", " 二 ", " 三 ", " 四 ", " 五 ", " 六 ", " 七 ", " 八 "}, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    container_layout_widget = {
    {
        {
		s.mylayoutbox,
		left = 4,
		right = 4,
		top = 4,
		bottom = 4,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_mantle,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        right = 5,
        widget = wibox.container.margin,
    }

    container_systray_widget = {
    {
        {
		wibox.widget.systray(),
		left = 10,
		right = 10,
		top = 5,
		bottom = 5,
		widget = wibox.container.margin,
		},
		shape = roundedRectangle,
		fg = beautiful.gruv_mantle,
		bg = beautiful.gruv_mantle,
		widget = wibox.container.background,
	},
        top = 5,
        bottom = 5,
        widget = wibox.container.margin
    }


    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s, height=35, })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
        },
	{ -- Middle widget
	    layout = wibox.layout.fixed.horizontal,
	    container_clock_widget,
	},
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            container_systray_widget,
            volume_widget,
            container_bt_widget,
            container_wifi_widget,
            container_ram_widget,
            container_batt_widget,
            container_layout_widget,
	    spacing = 5
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
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
         awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")
      end,
      {description = "volume up", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioLowerVolume",
      function()
         awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")
      end,
      {description = "volume down", group = "hotkeys"}
   ),
   awful.key({}, "XF86AudioMute",
      function()
         awful.spawn("pamixer -t")
      end,
      {description = "toggle mute", group = "hotkeys"}
   ),
   awful.key({}, "XF86MonBrightnessUp",
      function()
         awful.spawn("brightnessctl s +5%")
      end,
      {description = "inc brightness", group = "hotkeys"}
   ),
   awful.key({}, "XF86MonBrightnessDown",
      function()
         awful.spawn("brightnessctl s 5%-")
      end,
      {description = "dec brightness", group = "hotkeys"}
   ),
   

-- SCREENSHOT SHORT CUT --
    awful.key({},"Print", function () awful.spawn("flameshot screen") end,
             {description = "flameshot", group = "hotkeys"}),
    awful.key({modkey,            },"Print", function () awful.spawn("flameshot") end,
             {description = "launch flameshot", group = "hotkeys"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn("kitty --config /home/krishna/.config/kitty/gruvbox.conf") end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "KP_Add",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "KP_Subtract",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(1)                end,
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


    -- Menubar
    awful.key({ modkey }, "space", function() awful.util.spawn("rofi -show drun -config ~/.config/rofi/gruvbox.rasi") end,
              {description = "show app launcher(rofi)", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ "Mod1",   }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ "Mod1",   }, "l",      function () awful.spawn("/home/krishna/.config/scripts/xlock.sh")                     end,
              {description = "lock-screen", group = "launcher"}),
    awful.key({ modkey,   }, "p",      function (c)  awful.util.spawn("profi -show powermenu -config ~/.config/rofi/gruvbox.rasi")                        end,
              {description = "powermenu", group = "launcher"}),

    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
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
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
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
                  {description = "move focused client to tag #"..i, group = "tag"}),
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
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
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
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = false }
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

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = true})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- start picom
awful.spawn.with_shell("picom &")
awful.spawn.with_shell("greenclip daemon")
-- }}}
