import os

from libqtile import bar, lazy, qtile
from qtile_extras import widget
from qtile_extras.widget import decorations
from qtile_extras.widget.decorations import RectDecoration
from utils import color, config
from utils.settings import workspace_names

home = os.path.expanduser("~")

group_box_settings = {
    "active": color["fg"],
    "block_highlight_text_color": color["fg"],
    "this_current_screen_border": color["fg"],
    "this_screen_border": color["fg"],
    "urgent_border": color["red"],
    "background": color["bg"],  # background is [10-12]
    "other_current_screen_border": color["bg"],
    "other_screen_border": color["bg"],
    "highlight_color": color["darkgray"],
    "inactive": color["gray"],
    "foreground": color["white"],
    "borderwidth": 2,  # change to 2 to add bottom border to active group
    "disable_drag": True,
    "fontsize": 18,
    "highlight_method": "line",
    "padding_x": 10,
    "padding_y": 16,
    "rounded": False,
}

# functions for callbacks


def open_launcher():
    qtile.cmd_spawn("rofi -show drun -theme ~/.config/rofi/kanagawa.rasi")


def open_powermenu():
    qtile.cmd_spawn("powermenu.sh")


def play_next():
    qtile.cmd_spawn("playerctl next")


def play_prev():
    qtile.cmd_spawn("playerctl previous")


def parse_window_name(text):
    """Simplifies the names of a few windows, to be displayed in the bar"""
    target_names = [
        "Mozilla Firefox",
        "Visual Studio Code",
        "Discord",
        "Doom Emacs",
    ]
    try:
        return next(filter(lambda name: name in text, target_names), text)
    except TypeError:
        return text


# separator
def separator():
    return widget.Sep(
        # foreground=color['white'],
        foreground=color["bg"],
        padding=4,
        linewidth=3,
    )


def separator_sm():
    return widget.Sep(
        # foreground=color['white'],
        foreground=color["bg"],
        padding=1,
        linewidth=1,
        size_percent=55,
    )


# widget decorations
base_decor = {
    "colour": color["black"],
    "filled": True,
    "padding_y": 4,
    "line_width": 0,
}


def _left_decor(color: str, padding_x=None, padding_y=4, round=False):
    radius = 4 if round else [4, 0, 0, 4]
    return [
        RectDecoration(
            colour=color,
            radius=radius,
            filled=True,
            padding_x=padding_x,
            padding_y=padding_y,
        )
    ]


def _right_decor(round=False):
    radius = 4 if round else [0, 4, 4, 0]
    return [
        RectDecoration(
            colour=color["darkgray"],
            radius=radius,
            filled=True,
            padding_y=4,
            padding_x=0,
        )
    ]


# hollow knight icon
w_hk = widget.Image(
    background=color["fg"],
    margin_x=14,
    margin_y=3,
    mouse_callbacks={"Button1": open_launcher},
    filename="~/Pictures/wallpaper/hkskull.png",
)

# left icon
w_sys_icon = widget.TextBox(
    # text=' ',
    # text='',
    # text='ﮊ',
    # text='',
    # text='',
    # text='',
    text="",
    # text='',
    # text='',
    font="Font Awesome 6 Free Solid",
    fontsize=22,
    foreground="#000000",
    # foreground=color['maroon'],
    background=color["fg"],
    padding=16,
    mouse_callbacks={"Button1": open_launcher},
)


# workspace groups
def gen_groupbox():
    return (
        widget.GroupBox(
            # font='Font Awesome 6 Free Solid',
            font="Xiaolai SC",
            visible_groups=workspace_names,
            **group_box_settings,
        ),
    )


def chord():
    return widget.Chord(
        # name_transform=lambda name: f'"{name}"',
        foreground=color["bg"],
        decorations=_left_decor(color=color["fg"], round=True),
    )


# spacers
def gen_spacer():
    return widget.Spacer()


# window name
def window_name():
    return (
        widget.TextBox(
            text=" ",
            foreground="#ffffff",
            font="Font Awesome 6 Free Solid",
        ),
        widget.WindowName(
            foreground="#ffffff",
            width=bar.CALCULATED,
            empty_group_string="Desktop",
            max_chars=30,
            parse_text=parse_window_name,
        ),
    )


w_window_name_icon = widget.TextBox(
    text=" ",
    foreground=color["white"],
    font="Font Awesome 6 Free Solid",
)

w_window_name = widget.WindowName(
    foreground=color["white"],
    width=bar.CALCULATED,
    empty_group_string="Desktop",
    max_chars=30,
    parse_text=parse_window_name,
)

# systray
w_systray = widget.Systray(
    padding=5,
    icon_size=20,
)

# current layout


def gen_current_layout():
    w_color = color["pink"]

    return (
        widget.CurrentLayoutIcon(
            custom_icon_paths=[os.path.expanduser("~/.config/qtile/icons")],
            scale=0.65,
            use_mask=True,
            foreground=color["bg"],
            decorations=_left_decor(w_color, round=True),
        ),
        # separator_sm(),
        # widget.CurrentLayout(
        #     foreground=color["fg"],
        #     padding=8,
        #     decorations=_right_decor(),
        # ),
        separator(),
    )


# battery
w_battery = (
    (
        widget.Battery(
            format="{char}",
            charge_char="󰂄",
            discharge_char="󰁹",
            full_char="󰂃",
            unknown_char="󰂑",
            empty_char="󰁺",
            show_short_text=False,
            foreground=color["dark"],
            fontsize=18,
            padding=8,
            decorations=_left_decor(color["magenta"]),
        ),
        separator_sm(),
        widget.Battery(
            format="{percent:2.0%}",
            show_short_text=False,
            foreground=color["fg"],
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )
    if config["with_battery"]
    else ()
)


# volume
def gen_vol():
    return (
        widget.TextBox(
            text="󰕾",
            foreground=color["dark"],
            font="JetBrainsMono Nerd Font",
            fontsize=20,
            padding=10,
            decorations=_left_decor(color["green"]),
        ),
        separator_sm(),
        widget.Volume(
            foreground=color["fg"],
            limit_max_volume="True",
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )


# internet
w_wlan = (
    (
        widget.Wlan(
            format="󰖩",
            foreground=color["dark"],
            disconnected_message="󰖪",
            fontsize=16,
            interface="wlan0",
            update_interval=5,
            padding=12,
            decorations=_left_decor(color["maroon"]),
        ),
        separator_sm(),
        widget.Wlan(
            format="{percent:2.0%}",
            disconnected_message=" NC",
            foreground=color["fg"],
            interface="wlan0",
            update_interval=5,
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )
    if config["with_wlan"]
    else ()
)

# time, calendar


def gen_clock():
    w_color = color["yellow"]

    return (
        widget.TextBox(
            text="󰃰",
            font="JetBrainsMono Nerd Font",
            fontsize=18,
            foreground=color["dark"],  # blue
            padding=8,
            decorations=_left_decor(w_color),
        ),
        separator_sm(),
        widget.Clock(
            # format="%b %d, %H:%M",
            format="%H:%M",
            foreground=color["fg"],
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )


# power menu
w_power = widget.TextBox(
    text="⏻",
    background=color["fg"],
    foreground="#000000",
    font="Font Awesome 6 Free Solid",
    fontsize=18,
    padding=16,
    mouse_callbacks={"Button1": open_powermenu},
)


def w_updates():
    w_color = color["blue"]

    return (
        widget.CheckUpdates(
            display_format="󰊠",
            distro="Arch",
            initial_text="󰊠",
            no_update_string="󰧵",  # "󰧵",
            font="JetBrainsMono Nerd Font",
            fontsize=18,
            foreground=color["dark"],  # blue
            colour_have_updates=color["dark"],  # blue
            colour_no_updates=color["dark"],  # blue
            padding=10,
            decorations=_left_decor(w_color),
            update_interval=60,
        ),
        separator_sm(),
        widget.CheckUpdates(
            display_format="{updates}",
            distro="Arch",
            custom_command="checkupdates",
            initial_text="󰮯",
            no_update_string="0",
            foreground=color["fg"],
            colour_have_updates=color["fg"],  # fg
            colour_no_updates=color["fg"],  # fg
            padding=8,
            decorations=_right_decor(),
            update_interval=60,
        ),
        separator(),
    )


def gen_cpu():
    w_color = color["fg"]

    return (
        widget.TextBox(
            text="󰍛",
            font="JetBrainsMono Nerd Font",
            fontsize=20,
            foreground=color["dark"],  # blue
            padding=10,
            decorations=_left_decor(w_color),
        ),
        separator_sm(),
        widget.CPU(
            format="{load_percent:.0f}%",
            update_interval=2,
            font="JetBrainsMono Nerd Font",
            foreground=color["fg"],
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )


def gen_mem():
    w_color = color["red"]

    return (
        widget.TextBox(
            text=" ",
            font="JetBrainsMono Nerd Font",
            fontsize=15,
            foreground=color["dark"],  # blue
            padding=6,
            decorations=_left_decor(w_color),
        ),
        separator_sm(),
        widget.Memory(
            format="{MemUsed:.1f}{mm}",
            measure_mem="G",
            update_interval=2,
            font="JetBrainsMono Nerd Font",
            foreground=color["fg"],
            padding=8,
            decorations=_right_decor(),
        ),
        separator(),
    )


def music_name():
    return (
        widget.TextBox(
            text="⏮ ",
            font="JetBrainsMono Nerd Font",
            fontsize=24,
            foreground="#ffffff",
            padding=2,
            mouse_callbacks={"Button1": play_prev},
        ),
        widget.Mpris2(
            playing_text="󰐊 ",
            paused_text="󰏤 ",
            foreground="#ffffff",
            font="JetBrainsMono Nerd Font",
            fontsize=20,
        ),
        widget.Mpris2(
            foreground="#ffffff",
            max_chars=40,
            paused_text="{track}",
            format="{xesam:title}",
            stopped_text="~ sweet ~",
            font="JetBrainsMono Nerd Font",
            fontsize=18,
        ),
        widget.TextBox(
            text=" ⏭",
            font="JetBrainsMono Nerd Font",
            fontsize=24,
            foreground="#ffffff",
            padding=2,
            mouse_callbacks={"Button1": play_next},
        ),
    )


# widget box
w_box = widget.WidgetBox(
    close_button_location="left",
    fontsize=18,
    foreground=color["fg"],
    widgets=[
        *gen_cpu(),
        *gen_mem(),
        *w_updates(),
    ],
    text_closed="",
    text_open="",
    padding=4,
    name="widgetbox",
)
