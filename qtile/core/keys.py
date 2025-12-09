import os

from libqtile import qtile
from libqtile.config import Key, KeyChord
from libqtile.lazy import lazy

mod = "mod4"
control = "control"
shift = "shift"
alt = "mod1"
home = os.path.expanduser("~")


# resize functions
def resize(qtile, direction):
    layout = qtile.current_layout
    child = layout.current
    parent = child.parent

    while parent:
        if child in parent.children:
            layout_all = False

            if (direction == "left" and parent.split_horizontal) or (
                direction == "up" and not parent.split_horizontal
            ):
                parent.split_ratio = max(5, parent.split_ratio - layout.grow_amount)
                layout_all = True
            elif (direction == "right" and parent.split_horizontal) or (
                direction == "down" and not parent.split_horizontal
            ):
                parent.split_ratio = min(95, parent.split_ratio + layout.grow_amount)
                layout_all = True

            if layout_all:
                layout.group.layout_all()
                break

        child = parent
        parent = child.parent


@lazy.function
def toggle_bar(qtile):
    qtile.cmd_hide_show_bar("top")


@lazy.function
def resize_left(qtile):
    current = qtile.current_layout.name
    layout = qtile.current_layout
    if current == "bsp":
        resize(qtile, "left")
    elif current == "columns":
        layout.cmd_grow_left()


@lazy.function
def resize_right(qtile):
    current = qtile.current_layout.name
    layout = qtile.current_layout
    if current == "bsp":
        resize(qtile, "right")
    elif current == "columns":
        layout.cmd_grow_right()


@lazy.function
def resize_up(qtile):
    current = qtile.current_layout.name
    layout = qtile.current_layout
    if current == "bsp":
        resize(qtile, "up")
    elif current == "columns":
        layout.cmd_grow_up()


@lazy.function
def resize_down(qtile):
    current = qtile.current_layout.name
    layout = qtile.current_layout
    if current == "bsp":
        resize(qtile, "down")
    elif current == "columns":
        layout.cmd_grow_down()


keys = [
    # essentials
    Key(
        [mod],
        "Return",
        lazy.spawn("kitty"),
        desc="Launch terminal",
    ),
    Key([alt], "q", lazy.window.kill(), desc="Kill active window"),
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle forward layout"),
    Key([mod, shift], "Tab", lazy.prev_layout(), desc="Toggle last layout"),
    # qtile
    Key([mod, shift], "r", lazy.restart(), desc="Restart Qtile"),
    # menus
    Key(
        [mod],
        "space",
        lazy.spawn("rofi -show drun -theme ~/.config/rofi/qtile.rasi"),
        desc="Launch Rofi (drun)",
    ),
    # Key([mod], "r", lazy.spawn("rofi -show run -theme ~/.config/rofi/launcher.rasi"), desc="Launch Rofi (run)"),
    # focus, move windows and screens
    Key(
        [mod], "Down", lazy.layout.down(), desc="Move focus down in current stack pane"
    ),
    Key([mod], "Up", lazy.layout.up(), desc="Move focus up in current stack pane"),
    Key(
        [mod], "Left", lazy.layout.left(), desc="Move focus left in current stack pane"
    ),
    Key(
        [mod],
        "Right",
        lazy.layout.right(),
        desc="Move focus right in current stack pane",
    ),
    Key(
        [mod, shift],
        "Down",
        lazy.layout.shuffle_down(),
        lazy.layout.move_down(),
        desc="Move windows down in current stack",
    ),
    Key(
        [mod, shift],
        "Up",
        lazy.layout.shuffle_up(),
        lazy.layout.move_up(),
        desc="Move windows up in current stack",
    ),
    Key(
        [mod, shift],
        "Left",
        lazy.layout.shuffle_left(),
        lazy.layout.move_left(),
        desc="Move windows left in current stack",
    ),
    Key(
        [mod, shift],
        "Right",
        lazy.layout.shuffle_right(),
        lazy.layout.move_right(),
        desc="Move windows right in the current stack",
    ),
    Key([mod, control], "Down", lazy.layout.flip_down(), desc="Flip layout down"),
    Key([mod, control], "Up", lazy.layout.flip_up(), desc="Flip layout up"),
    Key(
        [mod, control],
        "Left",
        lazy.layout.flip_left(),
        lazy.layout.swap_column_left(),
        desc="Flip layout left",
    ),
    Key(
        [mod, control],
        "Right",
        lazy.layout.flip_right(),
        lazy.layout.swap_column_left(),
        desc="Flip layout right",
    ),
    # window resizing
    Key([mod, alt], "Left", resize_left, desc="Resize window left"),
    Key([mod, alt], "Right", resize_right, desc="Resize window Right"),
    Key([mod, alt], "Up", resize_up, desc="Resize windows upward"),
    Key([mod, alt], "Down", resize_down, desc="Resize windows downward"),
    Key([mod, alt], "n", lazy.layout.normalize(), desc="Normalize window size ratios"),
    # window states
    Key(
        [mod],
        "m",
        lazy.window.toggle_maximize(),
        desc="Toggle window between minimum and maximum sizes",
    ),
    Key([mod, shift], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key(
        [mod],
        "i",
        lazy.window.toggle_floating(),
        desc="Toggle floating mode for a window",
    ),
    Key([alt], "l", lazy.spawn("screenlock.sh"), desc="lock screen"),
    # floating mode
    # Key([mod] , "i", lazy.layout.grow(), desc="Increase window size"),
    # Key([mod, shift] , "i", lazy.layout.shrink(), desc="Decrease window size"),
    # program launches
    Key([mod], "grave", lazy.group["scratchpad"].dropdown_toggle("term")),
    Key([mod, shift], "grave", lazy.group["scratchpad"].dropdown_toggle("btop-term")),
    # screenshots
    Key([], "Print", lazy.spawn("screenshot.sh"), desc="Screenshot screen"),
    Key([mod], "Print", lazy.spawn("screenshot.sh --sel"), desc="Screenshot region"),
    Key(
        [mod, control],
        "Print",
        lazy.spawn("screenshot.sh --stop"),
        desc="Stop recording",
    ),
    # audio stuff
    Key(
        [],
        "XF86AudioRaiseVolume",
        lazy.spawn("settings_control.sh volup"),
        desc="Increase volume",
    ),
    Key(
        [],
        "XF86AudioLowerVolume",
        lazy.spawn("settings_control.sh voldown"),
        desc="Decrease volume",
    ),
    Key(
        [],
        "XF86AudioMute",
        lazy.spawn("settings_control.sh volmute"),
        desc="Toggle volume mute",
    ),
    # brightness
    Key(
        [],
        "XF86MonBrightnessUp",
        lazy.spawn("settings_control.sh briup"),
        desc="Increase brightness",
    ),
    Key(
        [],
        "XF86MonBrightnessDown",
        lazy.spawn("settings_control.sh bridown"),
        desc="Decrease brightness",
    ),
    # misc
    # Key([mod], "w", lazy.spawn("" + home + "/.local/bin/wmname"), desc='Get wmname of a window',),
    # bar
    Key([mod, "control"], "0", toggle_bar(), desc="Toggle bar"),
    Key(
        [mod, "control"],
        "1",
        lazy.widget["widgetbox"].toggle(),
        desc="Toggle widgetbox",
    ),
    # keychords
    KeyChord(
        [mod],
        "l",
        [
            Key([], "d", lazy.spawn("discord"), desc="Launch Discord"),
            Key([], "f", lazy.spawn("thunar"), desc="Launch Thunar"),
            Key(
                [],
                "s",
                lazy.spawn("smart-search"),
                desc="Launch Book search",
            ),
            Key([], "m", lazy.spawn("spotify"), desc="Launch Spotify"),
        ],
        name="Launcher",
    ),
]


def show_keys():
    key_help = ""
    for i in range(0, len(keys)):
        k = keys[i]
        if not isinstance(k, Key):
            continue
        mods = ""

        for m in k.modifiers:
            if m == "mod4":
                mods += "Super + "
            else:
                mods += m.capitalize() + " + "

        if len(k.key) > 1:
            mods += k.key.capitalize()
        else:
            mods += k.key

        key_help += "{:<25} {}".format(
            mods, k.desc + ("\n" if i != len(keys) - 1 else "")
        )

    return key_help


keys.extend(
    [
        Key(
            [mod],
            "a",
            lazy.spawn(
                "sh -c 'echo \""
                + show_keys()
                + '" | rofi -dmenu -theme ~/.config/rofi/hotkeys.rasi -i -p ""\''
            ),
            desc="Print keyboard bindings",
        ),
    ]
)
