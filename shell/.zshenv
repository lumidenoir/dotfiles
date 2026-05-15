#!/usr/bin/env zsh

# Path management
export PATH="$HOME/.local/bin:$HOME/dotfiles/scripts:$PATH"
export PATH="$HOME/.config/emacs/bin:$PATH"
export PATH="$HOME/flutter/bin:$HOME/flutter/cache/dart-sdk:$PATH"

# Android SDK
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"

# App Defaults
export EDITOR="emacsclient -c -a 'emacs'"
export TERMINAL="wezterm"
export BROWSER="brave"

# Misc
export CHROME_EXECUTABLE="/usr/bin/brave"
export JAVA_TOOL_OPTIONS='-Djogl.disable.openglarbcontext=1'

# Credentials (kept here for consistency)
export WECHALLUSER="lumidenoir"
export WECHALLTOKEN="BAFBF-789F3-4BA93-46F0A-73F47-DE8F0"
