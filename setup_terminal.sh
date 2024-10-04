#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Variables
WEZTERM_DEB="wezterm-20240203-110809-5046fc22.Debian12.deb"
WEZTERM_URL="https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/${WEZTERM_DEB}"
DOTFILES_REPO="https://github.com/lxflk/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
TPM_DIR="$HOME/.tmux/plugins/tpm"
FONT_DIR="$HOME/.local/share/fonts"
MESLO_ZIP="Meslo.zip"
MESLO_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Meslo.zip"

# Update package list
sudo apt update

# Install necessary packages
sudo apt install -y zsh tmux fzf stow wget git unzip fontconfig

# Install dependencies for WezTerm
sudo apt install -y libxcb-image0 libxcb-shape0 libxcb-render0 libxcb-xfixes0 libxcb-shm0 libxcb-keysyms1 libxcb-util1 libxkbcommon-x11-0

# Set Zsh as the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Changing default shell to Zsh..."
  chsh -s "$(which zsh)"
fi

# Install WezTerm
if ! command -v wezterm >/dev/null 2>&1; then
  echo "Installing WezTerm..."
  wget "$WEZTERM_URL" -O "/tmp/${WEZTERM_DEB}"
  sudo apt install -y "/tmp/${WEZTERM_DEB}"
  rm "/tmp/${WEZTERM_DEB}"
fi

# Install MesloLGS Nerd Font Mono
echo "Installing MesloLGS Nerd Font Mono..."
mkdir -p "$FONT_DIR"
wget -O "/tmp/${MESLO_ZIP}" "$MESLO_URL"
unzip -o "/tmp/${MESLO_ZIP}" -d "/tmp/MesloFonts"
cp -f /tmp/MesloFonts/*.ttf "$FONT_DIR"
fc-cache -fv
rm -rf "/tmp/${MESLO_ZIP}" "/tmp/MesloFonts"

# Install tpm (Tmux Plugin Manager)
if [ ! -d "$TPM_DIR" ]; then
  echo "Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Clone dotfiles repository
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Cloning dotfiles repository..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Backup existing dotfiles and apply new ones using stow
echo "Backing up existing dotfiles and applying new configurations..."
cd "$DOTFILES_DIR"

# List of files and directories to stow (include dotfiles and .config)
DOTFILES_TO_STOW=$(find . -maxdepth 1 -mindepth 1 -not -name '.git' -not -name 'README.md' -not -name '.gitignore')

# Backup existing dotfiles
for file in $DOTFILES_TO_STOW; do
  filename=$(basename "$file")
  target="$HOME/$filename"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.bak"
    echo "Backed up $target to $target.bak"
  fi
done

# Apply stow
stow --dotfiles .

# Reload shell configurations
echo "Reloading shell configurations..."
if [ -f "$HOME/.zshrc" ]; then
  source "$HOME/.zshrc"
fi

# Apply dircolors settings
if [ -f "$HOME/.dircolors" ]; then
  echo "Applying dircolors settings..."
  eval "$(dircolors -b "$HOME/.dircolors")"
fi

# Reload tmux configuration for all sessions
if command -v tmux >/dev/null 2>&1; then
  echo "Reloading tmux configuration..."
  tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
    tmux send-keys -t "$session" ":source-file ~/.config/tmux/tmux.conf" Enter
    echo "Reloaded tmux configuration for session: $session"
  done
fi

# Install Tmux plugins
if [ -d "$TPM_DIR" ]; then
  echo "Installing Tmux plugins..."
  "$TPM_DIR"/scripts/install_plugins.sh
fi

# Reload WezTerm configuration
if pgrep wezterm >/dev/null 2>&1; then
  echo "Reloading WezTerm configuration..."
  wezterm cli reload
fi

echo "Setup complete! Please restart your terminal session to ensure all changes take effect."
