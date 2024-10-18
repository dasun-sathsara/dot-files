#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------- Helper Functions --------------------------------

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_exit_status() {
    if [ $? -ne 0 ]; then
        error "$1"
        exit 1
    fi
}

# --------------------------- Pre-Execution Checks -----------------------------

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Please run with sudo or as root user."
    exit 1
else
    success "Running as root."
fi

# ---------------------------- Helper Functions -------------------------------

source_nix_profile() {
    if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        info "Sourcing user Nix profile."
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    elif [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        info "Sourcing system Nix profile."
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    else
        warning "Nix profile script not found."
    fi
}

# ------------------------ Step 1: Ensure Nix is Available ---------------------

info "Checking for Nix installation..."
source_nix_profile

if ! command -v nix &>/dev/null; then
    warning "Nix command is not detected. Checking common installation paths..."

    if [ -e "$HOME/.nix-profile/bin/nix" ]; then
        success "Nix found in user profile. Adding to PATH..."
        export PATH="$HOME/.nix-profile/bin:$PATH"
    elif [ -e "/nix/var/nix/profiles/default/bin/nix" ]; then
        success "Nix found in system profile. Adding to PATH..."
        export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    else
        warning "Nix is not installed. Installing Nix..."
        curl -L https://nixos.org/nix/install | sh -s -- --daemon
        check_exit_status "Failed to install Nix."

        info "Sourcing Nix profile after installation."
        source_nix_profile
    fi
fi

if ! command -v nix &>/dev/null; then
    error "Nix is still not available after attempted installation or PATH update. Please install Nix manually and run this script again."
    exit 1
else
    success "Nix is available and ready to use."
fi

# ------------------- Step 2: Configure Nix with Flakes -----------------------

info "Configuring Nix with experimental features."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >>~/.config/nix/nix.conf
success "Nix configured to use flakes."

# ---------------------- Step 3: Install Nix Packages -------------------------

info "Installing required Nix packages..."
PACKAGES=(
    "fastfetch"
    "zsh"
    "git"
    "htop"
    "ripgrep"
    "tmux"
    "luarocks"
    "zoxide"
    "yazi"
    "eza"
    "fzf"
    "neovim"
    "unzip"
    "libgccjit"
)

for package in "${PACKAGES[@]}"; do
    if nix-env -q | grep -w "$package" >/dev/null; then
        success "$package is already installed. Skipping installation."
    else
        info "Installing $package..."
        nix-env -iA "nixpkgs.$package"
        check_exit_status "Failed to install $package."
        success "$package installed successfully."
    fi
done

# --------------------- Step 5: Install Oh-My-Posh ----------------------------

info "Checking for Oh My Posh installation..."
if ! command -v oh-my-posh &>/dev/null; then
    warning "Oh My Posh is not installed. Installing..."
    curl -s https://ohmyposh.dev/install.sh | bash -s
    check_exit_status "Failed to install Oh My Posh."
    export PATH=$PATH:$HOME/.local/bin
    success "Oh My Posh installed successfully."
else
    success "Oh My Posh is already installed."
fi

# ----------- Step 6: Install NvChad (a Neovim configuration) -----------------

info "Installing NvChad..."
NVCHAD_DIR="$HOME/.config/nvim"
git clone https://github.com/NvChad/starter "$NVCHAD_DIR"
check_exit_status "Failed to install NvChad."
success "NvChad installed successfully."

# Customizing NvChad with additional Lua configuration
info "Applying custom configuration to NvChad's chadrc.lua..."
CHADRC_PATH="$NVCHAD_DIR/lua/custom/chadrc.lua"
mkdir -p "$(dirname "$CHADRC_PATH")"

cat <<EOL >"$CHADRC_PATH"
local opt = vim.opt
local map = vim.api.nvim_set_keymap

-- Map 'jj' to escape insert mode
map('i', 'jj', '<Esc>', { noremap = true, silent = true })

return M
EOL

check_exit_status "Failed to apply custom configuration to chadrc.lua."
success "Custom configuration applied to chadrc.lua successfully."

# --------- Step 7: Clone Dot Files Repository into the Home Folder -----------

info "Cloning dot-files repository into a temporary directory..."
TMP_DIR="$HOME/tmp-dot-files"
git clone https://github.com/dasun-sathsara/dot-files.git "$TMP_DIR"
check_exit_status "Failed to clone the dot-files repository."

info "Moving contents from temporary directory to home directory..."
mv "$TMP_DIR"/.zshrc "$HOME"
mv "$TMP_DIR"/.config/* "$HOME/.config"
rm -rf "$TMP_DIR"
check_exit_status "Failed to move dot-files to the home directory or clean up."

if [ -f "$HOME/.zshrc" ]; then
    success ".zshrc file is present in the home directory."

    info "Setting Zsh as the default shell for the current user."
    chsh -s "$(command -v zsh)" || {
        error "Failed to change the default shell. Ensure the current user has permission to change their own shell."
        exit 1
    }
    success "Zsh is set as the default shell."
else
    error ".zshrc file is missing in the home directory. Check the dot-files cloning process."
    exit 1
fi

success "dot-files repository processed successfully."
