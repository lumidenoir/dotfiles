#!/usr/bin/env sh

CONF="$HOME/.config" #use test folder for testing
INS="$PWD"

# Function for creating symlinks with confirmation
create_symlink() {
    local src="$1"
    local dest="$2"
    echo "$src --> $dest"
    ln -sf "$src" "$dest"
}

# Case options for different setups
case "$1" in
base)
    read -p "Proceed with the installation? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation script..."
    echo "Configuration directory: $CONF"
    echo "Installation source: $INS"
    echo "Creating symlinks for base configuration folders in $CONF"
    for folder in bspwm sxhkd eww i3 awesome qtile hypr river sway picom rofi kitty polybar mpd mpDris2 neofetch cava dunst ncmpcpp wezterm waybar zathura dwm st dmenu; do
        if [ -e "$CONF/$folder" ]; then
            echo "$folder exists at CONF, backing up..."
            mkdir -p "$CONF/old"
            mv "$CONF/$folder" "$CONF/old/$folder"
        fi
        create_symlink "$INS/$folder/" "$CONF"
    done
    echo "Creating $HOME/.xmonad folder"
    mkdir -p "$HOME/.xmonad"
    create_symlink "$INS/xmonad.hs" "$HOME/.xmonad/"
    echo "Ensuring /usr/local/bin exists"
    sudo mkdir -p "/usr/local/bin/"
    sudo ln -sf $INS/scripts/* "/usr/local/bin"
    echo "Linked scripts to /usr/local/bin"
    echo "Finished moving folders pls install dependencies. To use dwm as WM, build dwm, st, and dmenu."
    ;;
zsh)
    read -p "Proceed with the installation? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation script..."
    read -p "Install zsh, starship, autosuggestions and syntax-highlighting? (y/n) " install_deps
    if [ "$install_deps" = "y" ]; then
        sudo pacman -S zsh starship
        echo "Installing Oh My Zsh and plugins..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    fi
    echo "Backing up .zshrc to .zshrc-predot"
    mv "$HOME/.zshrc" "$HOME/.zshrc_predot"
    cp "$INS/.zshrc" "$HOME/.zshrc"
    echo "Zsh setup complete."
    ;;
mini)
    read -p "Proceed with the minimal install? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation script..."
    echo "Configuration directory: $CONF"
    echo "Installation source: $INS"
    echo "Creating symlinks for base configuration folders in $CONF"
    for folder in picom rofi mpd neofetch cava dunst ncmpcpp wezterm zathura dwm st dmenu; do
        if [ -e "$CONF/$folder" ]; then
            echo "$folder exists at CONF, backing up..."
            mv "$CONF/$folder" "$CONF/$folder"_old
        fi
        create_symlink "$INS/$folder/" "$CONF"
    done
    echo "Ensuring /usr/local/bin exists"
    sudo mkdir -p "/usr/local/bin/"
    sudo ln -sf $INS/scripts/* "/usr/local/bin"
    echo "Linked scripts to /usr/local/bin"
    echo "Finished moving folders pls install dependencies and build dwm, st, and dmenu using instructions from upstream (siduck's repos)"
    ;;
doom)
    read -p "Proceed with the doom installation? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation script..."
    read -p "Install emacs and clone doom? (y/n) " install_deps
    if [ "$install_deps" = "y" ]; then
        sudo pacman -S emacs-nativecomp
        echo "Installing Doom Emacs..."
        git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs"
        "$HOME/.config/emacs/bin/doom" install
    fi
    rm -rf "$CONF/doom"
    create_symlink "$INS/doom/" "$CONF"
    ;;
nvchad)
    read -p "Proceed with the nvchad installation? (y/n) " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation canceled."
        exit 1
    fi
    echo "Starting installation script..."
    read -p "Install nvim and clone nvchad? (y/n) " install_deps
    if [ "$install_deps" = "y" ]; then
        sudo pacman -S nvim
        echo "Installing NvChad..."
        git clone https://github.com/NvChad/starter "$HOME/.config/nvim" && nvim
    fi
    rm -rf "$CONF/nvim"
    create_symlink "$INS/nvim/" "$CONF"
    ;;
*)
    echo "Usage: install.sh {base|mini|zsh|doom|nvchad}"
    exit 1
    ;;
esac
