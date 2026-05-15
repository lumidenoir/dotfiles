from qtile_extras import widget
from core.widgets import *
from utils import color, config

extra_bar = config["two_monitors"]

widget_defaults = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=15,
    padding=2,
    background=color["bg"],
)
extension_defaults = widget_defaults.copy()


def create_bar(extra_bar=False):
    """Create top bar, defined as function to allow duplication in other monitors"""
    return bar.Bar(
        [
            w_hk,
            *gen_groupbox(),
            separator(),
            gen_spacer(),
            *music_name(),
            gen_spacer(),
            *((w_systray,) if not extra_bar else ()),
            separator(),
            w_box,
            *w_wlan,
            *gen_vol(),
            *w_battery,
            *gen_clock(),
            *gen_current_layout(),
            w_power,
        ],
        32,
        margin=[6, 16, 2, 16],
        border_width=[0, 0, 0, 0],
        border_color=color["fg"],
    )


main_screen_bar = create_bar()
secondary_screen_bar = bar.Gap(2)
if extra_bar:
    secondary_screen_bar = create_bar(extra_bar=True)
