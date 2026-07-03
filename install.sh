#!/usr/bin/env sh

CONF="$HOME/.config"
INS="$PWD"

# Function to check and install dependencies (Arch only for now)
install_pkg() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Installing $1..."
        sudo pacman -S --noconfirm "$1"
    fi
}

# Ensure stow is installed
install_pkg stow

# Case options for different setups
case "$1" in
base)
    read -p "Proceed with the installation? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation with GNU Stow..."
    
    # List of packages to stow
    PACKAGES="hypr picom mpd mpDris2 ncmpcpp cava wezterm waybar x11 quickshell zathura"
    
    for pkg in $PACKAGES; do
        if [ -d "$pkg" ]; then
            echo "Stowing $pkg..."
            # Backup existing dir if not a symlink
            if [ -d "$CONF/$pkg" ] && [ ! -L "$CONF/$pkg" ]; then
                echo "Backing up existing $pkg config..."
                mv "$CONF/$pkg" "$CONF/${pkg}_backup"
            fi
            stow -R "$pkg"
        fi
    done
    
    echo "Finished stowing base configurations."
    ;;
zsh)
    echo "Setting up Zsh..."
    stow -R shell
    install_pkg antidote
    echo "Zsh setup complete. Restart your shell."
    ;;
doom)
    echo "Setting up Doom Emacs..."
    install_pkg emacs
    if [ ! -d "$HOME/.config/emacs" ]; then
        git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs"
        "$HOME/.config/emacs/bin/doom" install
    fi
    stow -R doom
    ;;
nvchad)
    echo "Setting up Neovim (NvChad)..."
    install_pkg nvim
    if [ ! -d "$HOME/.config/nvim" ]; then
        git clone https://github.com/NvChad/starter "$HOME/.config/nvim"
    fi
    stow -R nvim
    ;;
*)
    echo "Usage: install.sh {base|zsh|doom|nvchad}"
    exit 1
    ;;
esac
