#!/bin/bash
# ClawBox Installer
# Usage: curl -sSL https://get.clawbox.sh | sh

set -e

VERSION="${CLAWBOX_VERSION:-latest}"
INSTALL_DIR="${CLAWBOX_INSTALL_DIR:-/usr/local/bin}"
REPO="HarrisHan/clawbox"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" && exit 1; }

# Detect OS and arch
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$OS" in
        darwin) OS="apple-darwin" ;;
        linux) OS="unknown-linux-gnu" ;;
        *) error "Unsupported OS: $OS" ;;
    esac
    
    case "$ARCH" in
        x86_64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac
    
    PLATFORM="${ARCH}-${OS}"
}

# Get latest version
get_version() {
    if [ "$VERSION" = "latest" ]; then
        VERSION=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
    fi
    [ -z "$VERSION" ] && error "Could not determine version"
    info "Version: $VERSION"
}

# Download and install
install() {
    TEMP_DIR=$(mktemp -d)
    FILENAME="clawbox-${VERSION}-${PLATFORM}.tar.gz"
    URL="https://github.com/$REPO/releases/download/${VERSION}/${FILENAME}"
    
    info "Downloading $URL..."
    curl -sL "$URL" -o "$TEMP_DIR/$FILENAME" || error "Download failed"
    
    info "Installing to $INSTALL_DIR..."
    tar -xzf "$TEMP_DIR/$FILENAME" -C "$TEMP_DIR"
    
    if [ -w "$INSTALL_DIR" ]; then
        mv "$TEMP_DIR/clawbox" "$INSTALL_DIR/"
    else
        sudo mv "$TEMP_DIR/clawbox" "$INSTALL_DIR/"
    fi
    
    chmod +x "$INSTALL_DIR/clawbox"
    rm -rf "$TEMP_DIR"
}

# Verify installation
verify() {
    if command -v clawbox &> /dev/null; then
        success "ClawBox installed successfully!"
        echo ""
        clawbox --version
        echo ""
        echo "Get started:"
        echo "  clawbox init          # Initialize vault"
        echo "  clawbox set key value # Store a secret"
        echo "  clawbox get key       # Retrieve a secret"
        echo ""
        echo "Documentation: https://github.com/$REPO"
    else
        error "Installation failed"
    fi
}

# Main
main() {
    echo ""
    echo "  🔐 ClawBox Installer"
    echo "  AI-Native Secret Manager"
    echo ""
    
    detect_platform
    info "Platform: $PLATFORM"
    
    get_version
    install
    verify
}

main
