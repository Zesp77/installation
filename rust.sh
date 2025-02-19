#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1" && exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
task() { echo -e "${MAGENTA}[TASK]${NC} $1"; }

RUSTUP_HOME="${HOME}/.rustup"
CARGO_HOME="${HOME}/.cargo"

# Immediately inject paths into current environment
inject_rust_paths() {
    export RUSTUP_HOME="${RUSTUP_HOME}"
    export CARGO_HOME="${CARGO_HOME}"
    export PATH="${CARGO_HOME}/bin:${PATH}"
    [ -f "${CARGO_HOME}/env" ] && source "${CARGO_HOME}/env"
}

atomic_install() {
    task "Nuclear Rust installation"
    rm -rf "${RUSTUP_HOME}" "${CARGO_HOME}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --no-modify-path || error "Install failed"
    inject_rust_paths
}

update_all_shells() {
    local shells=(
        "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"
        "$HOME/.bash_profile" "$HOME/.config/fish/config.fish"
    )
    
    local rust_config=(
        "export RUSTUP_HOME=\"${RUSTUP_HOME}\""
        "export CARGO_HOME=\"${CARGO_HOME}\""
        "export PATH=\"\$CARGO_HOME/bin:\$PATH\""
        "[ -f \"\$CARGO_HOME/env\" ] && source \"\$CARGO_HOME/env\""
    )

    for shell in "${shells[@]}"; do
        if [ -f "$shell" ]; then
            if ! grep -qF "CARGO_HOME" "$shell"; then
                {
                    echo ""
                    echo "# Atomic Rust Path Injection"
                    printf "%s\n" "${rust_config[@]}"
                } >> "$shell"
            fi
        fi
    done
}

force_current_shell() {
    inject_rust_paths
    hash -r 2>/dev/null || true
    if ! command -v cargo &>/dev/null; then
        warn "Current shell environment not updated - executing fallback"
        exec $SHELL
    fi
}

verify_installation() {
    [ -z "$(which cargo)" ] && error "Cargo not detected"
    [ -z "$(which rustc)" ] && error "Rustc not detected"
    success "Rust toolchain verified"
}

main() {
    info "Starting Atomic Rust Deployment"
    atomic_install
    update_all_shells
    force_current_shell
    verify_installation
    success "Environment ready - try 'cargo --version'"
}

inject_rust_paths
main
