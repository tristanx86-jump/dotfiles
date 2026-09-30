#!/usr/bin/env bash
# Minimal setup for a client / jump machine (corporate MacBook, restricted env).
# Symlinks dotfiles, offers a user-local terminal font, and configures tools
# that are already installed.
# Does NOT install Homebrew packages or run curl-pipe-sh installers.
#
# What this sets up:
#   - zsh config
#   - tmux config (if tmux is installed)
#   - nvim config (if nvim is installed)
#   - optional FiraCode Nerd Font in the current macOS user account
#   - iTerm2 TokyoNight profile + default profile + clipboard access
#   - The `s` / `sfd` functions for connecting to your dev servers
#
# Run on the server itself:  bash ~/dotfiles/install.sh

set -uo pipefail
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
create_symlink() {
    local src=$1 dest=$2
    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        return  # already correct
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        local backup="${dest}.backup.$(date +%s)"
        echo "[Backup] $dest -> $backup"
        mv "$dest" "$backup"
    fi
    ln -s "$src" "$dest"
    echo "[Link]   $dest -> $src"
}

install_macos_nerd_font() {
    local user_font_dir="$HOME/Library/Fonts"
    local regular_font="$user_font_dir/FiraCodeNerdFontMono-Regular.ttf"
    [ -f "$regular_font" ] && return 0

    echo "[Font] Optional FiraCode Nerd Font"
    echo "  Downloads and extracts a third-party Nerd Font ZIP from GitHub."
    echo "  No additional packages are needed on macOS."
    printf 'Install the font for this user? [y/N] '
    local font_answer
    IFS= read -r font_answer || font_answer=
    case "$font_answer" in
        y|Y|yes|Yes) ;;
        *) echo "[Font] Skipped."; return 0 ;;
    esac

    local temp_dir archive
    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-font.XXXXXX")" || {
        echo "[WARN] Could not create temporary directory for FiraCode Nerd Font."
        return 1
    }
    archive="$temp_dir/FiraCode.zip"
    echo "[Client] Installing FiraCode Nerd Font for the current user..."
    if ! curl -fL --retry 3 \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
        -o "$archive"; then
        echo "[WARN] FiraCode Nerd Font download failed."
        rm -rf "$temp_dir"
        return 1
    fi
    mkdir -p "$user_font_dir"
    if ! ditto -x -k "$archive" "$temp_dir/unpacked"; then
        echo "[WARN] FiraCode Nerd Font extraction failed."
        rm -rf "$temp_dir"
        return 1
    fi
    find "$temp_dir/unpacked" -type f -name '*.ttf' \
        -exec cp -f {} "$user_font_dir/" \;
    rm -rf "$temp_dir"
    if [ ! -f "$regular_font" ]; then
        echo "[WARN] FiraCode Nerd Font archive did not contain the expected font."
        return 1
    fi
    echo "[Client] FiraCode Nerd Font installed in $user_font_dir."
}

# -----------------------------------------------------------------------------
# Shell config
# -----------------------------------------------------------------------------
create_symlink "$DOTFILES_DIR/zsh/.zshrc"       "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/zsh/.bashrc"       "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/zsh/.bash_profile" "$HOME/.bash_profile"

# -----------------------------------------------------------------------------
# tmux (only if installed)
# -----------------------------------------------------------------------------
if command -v tmux &>/dev/null; then
    create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
else
    echo "[Skip]   tmux not found — skipping tmux config."
fi

# -----------------------------------------------------------------------------
# nvim (only if installed)
# -----------------------------------------------------------------------------
if command -v nvim &>/dev/null; then
    create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
else
    echo "[Skip]   nvim not found — skipping nvim config."
fi

# -----------------------------------------------------------------------------
# iTerm2
# -----------------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
    install_macos_nerd_font || true
fi

ITERM_DIR="$HOME/Library/Application Support/iTerm2"
if [ -d "$ITERM_DIR" ]; then
    mkdir -p "$ITERM_DIR/DynamicProfiles"
    cp "$DOTFILES_DIR/iterm2/TokyoNight.json" "$ITERM_DIR/DynamicProfiles/"
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" \
        -string "fd0c77e8-7bb3-4b8c-9d2f-1a2b3c4d5e6f"
    defaults write com.googlecode.iterm2 AllowClipboardAccess -bool true
    echo "[Client] iTerm2 configured (TokyoNight default, clipboard enabled). Restart iTerm2."
else
    echo "[Skip]   iTerm2 not found — skipping iTerm2 config."
fi

# -----------------------------------------------------------------------------
# Dev server shortcut
# -----------------------------------------------------------------------------
SERVER_FILE="$HOME/.config/dotfiles/server"
if [ ! -s "$SERVER_FILE" ]; then
    echo ""
    read -rp "Dev server address (user@host, or Enter to skip): " _server
    if [ -n "$_server" ]; then
        mkdir -p "$(dirname "$SERVER_FILE")"
        echo "$_server" > "$SERVER_FILE"
        echo "[Client] Server saved — use 's' to connect."
    fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "Client setup done. Run:  exec zsh"
