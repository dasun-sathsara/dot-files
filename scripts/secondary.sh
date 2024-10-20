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
