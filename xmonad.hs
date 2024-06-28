----------------------------------------------------------------------
-- Import modules
----------------------------------------------------------------------
import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Layout.NoBorders

-- Layouts
import XMonad.Layout.Gaps (gaps, Direction2D(D, L, R, U))
import XMonad.Layout.Spacing (spacingRaw, Border(Border))
import XMonad.Layout.Grid
import XMonad.Layout.ThreeColumns
import XMonad.Layout.Spiral

-- Launch programs
import XMonad.Util.SpawnOnce (spawnOnce)

-- Keybinds
import qualified XMonad.StackSet as W
import qualified Data.Map        as M
import Graphics.X11.ExtraTypes.XF86 (
                                        xF86XK_AudioLowerVolume,
                                        xF86XK_AudioRaiseVolume,
                                        xF86XK_AudioMute,
                                        xF86XK_MonBrightnessUp,
                                        xF86XK_MonBrightnessDown
                                    )
-- Function to get the current layout and send a notification
notifyCurrentLayout :: X ()
notifyCurrentLayout = do
    layout <- gets (description . W.layout . W.workspace . W.current . windowset)
    spawn $ "dunstify -t 2000 'Layout' '" ++ layout ++ "'"

----------------------------------------------------------------------
-- Variables
----------------------------------------------------------------------
myTerminal            = "kitty"    -- Default terminal
myModMask             = mod4Mask   -- mean super
myBorderWidth         = 2
myNormalBorderColor   = "#545454"
myFocusedBorderColor  = "#c6c8d1"
myWorkspaces          = ["1", "2", "3", "4", "5", "6", "7", "8"]
--myWorkspaces          = ["零", "壱", "弐", "参", "肆", "伍"]

----------------------------------------------------------------------
-- Auto start programs
----------------------------------------------------------------------
myStartupHook = do
    spawnOnce "feh --bg-fill ~/Pictures/wallpaper/wall-07.webp"

    -- Picom
    spawn "picom"

    spawnOnce "polybar -conf=~/.config/polybar/rosepine.ini candy"

    spawn "dunst"

    spawnOnce "battery_notifier.sh"
----------------------------------------------------------------------
-- Keybinds
----------------------------------------------------------------------
myKeys conf@(XConfig {XMonad.modMask = super}) = M.fromList $
    [
        -- Launch terminal
        ((super, xK_Return),    spawn "kitty --config ~/.config/kitty/rosepine.conf"),

        -- Launch app launcher
        ((super, xK_space),         spawn "rofi -show drun -theme ~/.config/rofi/rosepine.rasi"),

        -- Kill focused window
        ((mod1Mask , xK_q),         kill),

        ((super, xK_l), spawn "~/.config/scripts/xlock.sh"),
        -- Take screenshot
        ((super, xK_s),
            spawn "~/.config/rofi/scripts/book-search"),

        -- Take selected area
        ((super .|. shiftMask, xK_s),
            spawn "~/.config/rofi/scripts/college-search"),

        -- Compile XMonad
        ((super, xK_r),
            spawn "xmonad --recompile; xmonad --restart"),

        -- Change current wallpaper
        ((super, xK_p),
            spawn "rofi -show powermenu -theme ~/.config/rofi/rosepine.rasi"),

        -- launch filemanager
        ((super, xK_f),         spawn "thunar"),

        -- Control brightness
        ((0,    xF86XK_MonBrightnessUp),
                spawn "~/dotfiles/scripts/settings_control.sh brightness_up"),

        ((0,    xF86XK_MonBrightnessDown),
                spawn "~/dotfiles/scripts/settings_control.sh brightness_down"),

        -- Control volume
        ((0,    xF86XK_AudioRaiseVolume),
                spawn "~/dotfiles/scripts/settings_control.sh volume_up"),

        ((0,    xF86XK_AudioLowerVolume),
                spawn "~/dotfiles/scripts/settings_control.sh volume_down"),

        ((0,    xF86XK_AudioMute),
                spawn "~/dotfiles/scripts/settings_control.sh volume_mute"),

        ((super, xK_Tab),    sendMessage NextLayout >> notifyCurrentLayout),

        -- Move focus
        ((super, xK_j),        windows W.focusUp),

        ((super, xK_k),        windows W.focusDown),

        -- Expand the master window
        ((super, xK_l),        sendMessage Expand),

        -- Shrink the master window
        ((super, xK_h),        sendMessage Shrink),

        -- Swap the focused window and master window
        ((super, xK_c),        windows W.swapMaster),

        -- Back to tiling
        ((super, xK_t),        withFocused $ windows . W.sink),

        ((super, xK_e), spawn "emacsclient --eval '(emacs-everywhere)'"),

        ((super, xK_x), spawn "org-capture")
    ]

    ++

    [
        -- Move workspace or send window to any workspaces
        ((m .|. super, k), windows $ f i)
            | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
            , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
    ]

----------------------------------------------------------------------
-- Window rules
----------------------------------------------------------------------
myManageHook = composeAll
    [
        -- You can use xprop command to make sure the window class

        -- Ignore
        className =? "Polybar" --> doIgnore,

        -- Float
        className =? "Gimp-2.10"    --> doFloat,
        -- className =? "Thunar"       --> doFloat,
        -- className =? "feh"          --> doFloat,
        -- className =? "vlc"          --> doFloat,
        -- className =? "discord"      --> doFloat,
        -- className =? "Spotify"      --> doFloat,

        className =? "Sample"       --> doFloat
    ]

----------------------------------------------------------------------
-- Window layouts
----------------------------------------------------------------------
myLayoutHook =
    -- Gap size for the around the window
    gaps [(L, 6), (R, 6), (U, 40), (D, 6)]

    -- Gap size for the single window
    $ spacingRaw False (Border gap gap gap gap)
                 True (Border gap gap gap gap)
                 True

    -- My favorit layout
    $ Tall nmaster delta fraction
    ||| Mirror (Tall nmaster delta fraction)
    ||| ThreeColMid nmaster delta fraction
    ||| spiral (0.61803)
    ||| Grid
    ||| Full

    -- Local variables for the layouts
        where
            nmaster  = 1
            delta    = 3/100
            fraction = 1/2
            gap      = 4


----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------
main = xmonad $ ewmh defaults

defaults = def
    {
        -- Basic variables
        terminal            = myTerminal,
        modMask             = myModMask,
        borderWidth         = myBorderWidth,
        normalBorderColor   = myNormalBorderColor,
        focusedBorderColor  = myFocusedBorderColor,
        workspaces          = myWorkspaces,

        -- Extends variables
        keys          = myKeys,
        manageHook    = myManageHook,
        layoutHook    = myLayoutHook,
        startupHook   = myStartupHook
    }



