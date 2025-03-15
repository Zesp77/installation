#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Output functions
error() { printf "%b\n" "${RED}[ERROR]${NC} $1" >&2; exit 1; }
warn() { printf "%b\n" "${YELLOW}[WARN]${NC} $1"; }
info() { printf "%b\n" "${BLUE}[INFO]${NC} $1"; }
success() { printf "%b\n" "${GREEN}[SUCCESS]${NC} $1"; }
task() { printf "%b\n" "${MAGENTA}[TASK]${NC} $1"; }

run_with_spinner() {
    local msg="$1" cmd=("${@:2}") pid
    local spin_chars='🕘🕛🕒🕡' delay=0.1 i=0

    printf "%b" "${MAGENTA}[TASK]${NC} ${msg}...  "
    "${cmd[@]} &" pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%b" "${MAGENTA}[TASK]${NC} ${msg}... ${CYAN}${spin_chars:$((i%4)):1}${NC}"
        sleep "$delay" && ((i++))
    done

    if wait "$pid"; then
        printf "\r%b\n" "${MAGENTA}[TASK]${NC} ${msg}... ${GREEN}Done${NC}"
        return 0
    else
        printf "\r\033[K"
        error "Command failed: ${cmd[*]}"
    fi
}

check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        task "Installing curl"
        if command -v apt >/dev/null 2>&1; then
            run_with_spinner "Updating packages" sudo apt update -y
            run_with_spinner "Installing curl" sudo apt install -y curl
        elif command -v dnf >/dev/null 2>&1; then
            run_with_spinner "Installing curl" sudo dnf install -y curl
        elif command -v yum >/dev/null 2>&1; then
            run_with_spinner "Installing curl" sudo yum install -y curl
        elif command -v pacman >/dev/null 2>&1; then
            run_with_spinner "Installing curl" sudo pacman -S --noconfirm curl
        elif command -v zypper >/dev/null 2>&1; then
            run_with_spinner "Installing curl" sudo zypper install -y curl
        else
            error "Could not install curl - unsupported package manager"
        fi
    fi
}

install_nvm() {
    export NVM_DIR="${HOME}/.nvm"
    local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"

    mkdir -p "${NVM_DIR}" || error "Failed to create NVM directory: ${NVM_DIR}"

    if [ -d "${NVM_DIR}/.git" ]; then
        warn "Found existing NVM installation - updating"
        run_with_spinner "Updating NVM" git -C "${NVM_DIR}" pull
    else
        if [ -d "${NVM_DIR}" ]; then
            warn "Found existing NVM directory - creating backup"
            run_with_spinner "Creating backup" mv "${NVM_DIR}" "${NVM_DIR}.bak-$(date +%s)"
        fi
        task "Installing NVM"
        run_with_spinner "Downloading and installing NVM" \
            bash -c "curl -o- ${install_url} | PROFILE=/dev/null bash"
    fi

    # Verify installation and load immediately
    if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
        error "NVM installation failed - nvm.sh not found"
    fi
    source "${NVM_DIR}/nvm.sh"
    [ -s "${NVM_DIR}/bash_completion" ] && source "${NVM_DIR}/bash_completion"
}

configure_shell() {
    local shell_rc
    case "$SHELL" in
        *zsh) shell_rc="${HOME}/.zshrc" ;;
        *) shell_rc="${HOME}/.bashrc" ;;
    esac

    touch "${shell_rc}" || error "Failed to create/access ${shell_rc}"

    task "Configuring shell environment"
    if ! grep -q "NVM_DIR" "${shell_rc}"; then
        cat << EOF >> "${shell_rc}"

export NVM_DIR="${HOME}/.nvm"
[ -s "\${NVM_DIR}/nvm.sh" ] && . "\${NVM_DIR}/nvm.sh"  # Load NVM
[ -s "\${NVM_DIR}/bash_completion" ] && . "\${NVM_DIR}/bash_completion"  # Load NVM bash_completion
EOF
        [ $? -eq 0 ] || error "Failed to update ${shell_rc}"
    fi

    # Apply to current session
    source "${shell_rc}"
}

get_latest_lts() {
    nvm ls-remote --lts | grep 'Latest LTS' | awk '{print $1}' | sed 's/^v//' | head -n1
}

install_node() {
    task "Managing Node.js"
    local latest_lts
    latest_lts=$(get_latest_lts)
    [ -z "${latest_lts}" ] && error "Failed to find latest LTS version"

    if ! command -v node >/dev/null 2>&1; then
        run_with_spinner "Installing Node.js LTS (v${latest_lts})" nvm install "${latest_lts}"
    else
        local current_version
        current_version=$(node --version | sed 's/v//')
        if [ "$(printf "%s\n%s" "${current_version}" "${latest_lts}" | sort -V | tail -n1)" != "${current_version}" ]; then
            warn "Current Node.js (v${current_version}) is outdated"
            run_with_spinner "Updating to v${latest_lts}" nvm install "${latest_lts}" --reinstall-packages-from=current
        else
            info "Already using latest LTS: v${current_version}"
        fi
    fi

    run_with_spinner "Setting default version" nvm alias default "${latest_lts}"
    run_with_spinner "Updating npm" npm install -g npm@latest
}

check_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        warn "Running as root - NVM should be user-level"
        read -rp "Continue anyway? (y/N) " choice < /dev/tty
        if [[ ! "${choice,,}" =~ ^(y|yes)$ ]]; then
            error "Aborted by user"
        fi
    fi
}

main() {
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH}"

    check_privileges
    check_dependencies
    install_nvm
    configure_shell
    install_node

    success "Environment setup complete!"
    printf "%b\n" "Node.js: ${GREEN}$(node --version)${NC}"
    printf "%b\n" "npm:     ${GREEN}$(npm --version)${NC}"
    info "Setup complete - no manual sourcing required"
    info "Start a new terminal session to ensure all changes are applied"
}

main "$@"
