#!/bin/bash

show() {
    case $2 in
        "error")
            echo -e "\033[1;31m❌ $1\033[0m"
            ;;
        "progress")
            echo -e "\033[1;33m⏳ $1\033[0m"
            ;;
        *)
            echo -e "\033[1;32m✅ $1\033[0m"
            ;;
    esac
}

if ! command -v curl &> /dev/null; then
    show "Installing Curl..." "progress"
    sudo apt update && sudo apt install -y curl
    show "Curl installed successfully!" "success"
else
    show "Curl is already installed. Skipping..." "success"
fi

show "Installing Solana..." "progress"
if ! sh -c "$(curl -sSfL https://release.solana.com/v1.14.20/install)"; then
    show "Failed to install Solana." "error"
    exit 1
fi

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

show "Making Solana available for future sessions..." "progress"
if ! grep -q "solana" ~/.bashrc; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    show "Solana path added to ~/.bashrc for future sessions." "success"
else
    show "Solana path already exists in ~/.bashrc." "success"
fi

# For zsh users
if [ -n "$ZSH_VERSION" ] && ! grep -q "solana" ~/.zshrc; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.zshrc
    show "Solana path added to ~/.zshrc for future sessions." "success"
elif [ -n "$ZSH_VERSION" ]; then
    show "Solana path already exists in ~/.zshrc." "success"
fi

# Step 6: Apply the changes immediately to the current shell session
if ! source ~/.bashrc; then
    show "Failed to source ~/.bashrc. Make sure it exists and is readable." "error"
    exit 1
fi

# Step 7: Verify Solana command works
if ! solana --version &> /dev/null; then
    show "Failed to verify Solana command. Please restart the terminal and try again." "error"
    exit 1
fi

show "Solana installation and configuration complete!" "success"
