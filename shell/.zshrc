# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# ... (rest of comments)

alias strel="xrdb merge $HOME/dotfiles/st/xresources && kill -USR1 $(pidof st)"
alias yay="paru"

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


eval "$(starship init zsh)"
export STARSHIP_LOG=error
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
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
