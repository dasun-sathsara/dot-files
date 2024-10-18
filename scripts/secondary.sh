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
)

for package in "${PACKAGES[@]}"; do
    info "Installing $package..."
    nix-env -iA "nixpkgs.$package"
    check_exit_status "Failed to install $package."
    success "$package installed successfully."
done

# --------------------- Step 4: Set Zsh as Default Shell ----------------------
# info "Setting Zsh as the default shell for the user."
# chsh -s $(which zsh)
# check_exit_status "Failed to set Zsh as the default shell."
# success "Zsh is now the default shell."

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
git clone https://github.com/NvChad/starter ~/.config/nvim
check_exit_status "Failed to install NvChad."
success "NvChad installed successfully."

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

success "dot-files repository processed successfully.
