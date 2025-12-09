#!/bin/zsh
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/.local/bin:$PATH

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Android SDK and flutter
export PATH=$HOME/.config/emacs/bin:$PATH
export PATH=$HOME/flutter/bin:$HOME/flutter/cache/dart-sdk:$PATH
export CHROME_EXECUTABLE=/usr/bin/chromium
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH="$PATH:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"

alias strel="xrdb merge $HOME/dotfiles/st/xresources && kill -USR1 $(pidof st)"

# matlab java options
export JAVA_TOOL_OPTIONS='-Djogl.disable.openglarbcontext=1'

# wechall credentials
export WECHALLUSER="lumidenoir"
export WECHALLTOKEN="BAFBF-789F3-4BA93-46F0A-73F47-DE8F0"

# emacs vterm
vterm_printf() {
    if [ -n "$TMUX" ] && ([ "${TERM%%-*}" = "tmux" ] || [ "${TERM%%-*}" = "screen" ]); then
        # Tell tmux to pass the escape sequences through
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        # GNU screen (screen, screen-256color, screen-256color-bce)
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}

source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load


# eval "$(starship init zsh)"
# export STARSHIP_LOG=error
# eval $(thefuck --alias)

# source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
#
# setopt APPEND_HISTORY
# setopt SHARE_HISTORY
# HISTFILE=$HOME/.zsh_history
# SAVEHIST=1000
# HISTSIZE=999
# setopt HIST_EXPIRE_DUPS_FIRST
# setopt EXTENDED_HISTORY

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
