#!/bin/bash

# =============================================================================
# Script Name: setup_dasun_environment.sh
# Description: Creates user 'dasun' with the password 'root' and runs the
#              secondary script as the 'dasun' user.
# Author: Your Name
# Date: YYYY-MM-DD
# =============================================================================

set -e

# ------------------------------ Color Codes -----------------------------------

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
fi

# ---------------------------- Step 1: Create User 'dasun' ---------------------

USER_NAME="dasun"
USER_PASSWORD="root"

if id "$USER_NAME" &>/dev/null; then
    warning "User '$USER_NAME' already exists. Skipping creation."
else
    info "Creating user '$USER_NAME'..."
    useradd -m -s /bin/bash "$USER_NAME"
    check_exit_status "Failed to create user '$USER_NAME'."
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd
    check_exit_status "Failed to set password for user '$USER_NAME'."
    usermod -aG sudo "$USER_NAME"
    success "User '$USER_NAME' created and added to sudo group with password '$USER_PASSWORD'."
fi
