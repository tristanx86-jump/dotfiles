#!/usr/bin/env bash
# We removed the '-e' flag so the script will NOT crash on errors.
# It will attempt to power through and do as much as it can.
set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration & Variables
# -----------------------------------------------------------------------------
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OS="$(uname -s)"
[ "$OS" = Linux ] || {
    echo "[ERROR] The full installer supports Linux. Use install-client.sh on macOS." >&2
    exit 1
}
FONT_DIR="$HOME/.local/share/fonts"

# Where we cache cheap "did this already happen recently" markers so re-runs
# (updatedot) don't redo expensive network-bound work every single time.
STATE_DIR="$HOME/.cache/dotfiles"
mkdir -p "$STATE_DIR"

_old_tools_path="$HOME/.local/share/dotfiles/tools/bin"
while [[ ":$PATH:" == *":$_old_tools_path:"* ]]; do
    PATH=":$PATH:"
    PATH="${PATH/:$_old_tools_path:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
done
unset _old_tools_path
# Keep user-local editor and plugin commands on PATH.
export PATH="$HOME/.local/bin:$PATH"

# -----------------------------------------------------------------------------
# Original-state snapshot (for `wipedot`)
# -----------------------------------------------------------------------------
# Written exactly once — the very first time install.sh runs on this machine,
# before anything below installs a single package — so wipedot can later tell
# apart "dotfiles installed this" (safe to remove) from "this was already
# here" (leave it alone). Re-running install.sh/updatedot never overwrites it.
# Machines that already had dotfiles installed before this existed have no
# snapshot to work from; wipedot handles that as a degraded, best-effort case.
ORIGINAL_STATE_FILE="$STATE_DIR/original-state"
if [ ! -f "$ORIGINAL_STATE_FILE" ]; then
    echo "[Wipedot] First run on this machine — recording original state for wipedot..."
    {
        echo "ORIGINAL_OS=$OS"
        echo "ORIGINAL_SHELL=$SHELL"
        echo "SNAPSHOT_VERSION=4"
        echo "MANAGED_SYSTEM_PACKAGES=0"
        echo "MANAGED_LOGIN_SHELL=0"
        echo "MANAGED_OHMYZSH=0"

        # Record user-local tools that may predate this install for wipedot.
        _p() { [ -e "$1" ] && echo 1 || echo 0; }
        echo "PREEXISTING_FONT=$(_p "$FONT_DIR/FiraCode")"
        echo "PREEXISTING_NVIM_DATA=$(_p "${XDG_DATA_HOME:-$HOME/.local/share}/nvim")"
    } > "$ORIGINAL_STATE_FILE"
fi

# _sha256 <file>: portable hash (Linux has sha256sum, macOS has shasum).
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        cksum "$1" | awk '{print $1}'
    fi
}

echo "==== Initializing Environment Setup ===="

# Confirm missing packages, existing-package updates, and the optional font.
if ! source "$DOTFILES_DIR/install-user-tools.sh"; then
    echo "[ERROR] System tool installation failed." >&2
    exit 1
fi

FD_LINK_STATE="$STATE_DIR/firedancer-bin-links"
link_firedancer_binary() {
    local dest=$1 name=$2 target
    target="$HOME/firedancer/build/$name"
    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$target" ]; then
            return 0
        fi
    elif [ -e "$dest" ]; then
        echo "[Skip] $dest is a real file."
        return 0
    fi
    sudo ln -sfnT -- "$target" "$dest" || return 1
    if ! grep -Fqx "$dest" "$FD_LINK_STATE" 2>/dev/null; then
        printf '%s\n' "$dest" >> "$FD_LINK_STATE" || return 1
    fi
    echo "[Link] $dest -> $target"
}

for fd_name in firedancer-dev fddev fdctl solana; do
    link_firedancer_binary "/usr/bin/$fd_name" "$fd_name" || exit 1
    local_link="/usr/local/bin/$fd_name"
    if [ -L "$local_link" ]; then
        case "$(readlink "$local_link")" in
            */firedancer/build/*)
                link_firedancer_binary "$local_link" "$fd_name" || exit 1
                ;;
        esac
    fi
done

# -----------------------------------------------------------------------------
# Shell Configuration & Symlinking
# -----------------------------------------------------------------------------


create_symlink() {
    local src=$1
    local dest=$2
    mkdir -p "$(dirname "$dest")"

    # Check if destination exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # If it is a symlink AND already points to our source, we are good to go
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            return
        fi

        # Otherwise, back it up
        local backup="${dest}.backup.$(date +%s)"
        echo "[Backup] Moving existing $dest to $backup"
        mv "$dest" "$backup"
    fi

    ln -sf "$src" "$dest"
    echo "[Link] $dest -> $src"
}

echo "==== Linking Configuration Files ===="
create_symlink "$DOTFILES_DIR/zsh/.zshrc"        "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/zsh/.bashrc"        "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/zsh/.bash_profile"  "$HOME/.bash_profile"
create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    echo "[Backup] Moving existing Neovim config..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$(date +%s)"
fi
create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

# Sync Neovim plugins to the lockfile when it changes.
if command -v nvim >/dev/null 2>&1; then
    NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

    # A new nvim build can break installed plugins, so resync after upgrades.
    NVIM_VER_STAMP="$STATE_DIR/nvim-version"
    CUR_NVIM_VER="$(nvim --version | head -1)"
    NVIM_VER_CHANGED=0
    [ "$CUR_NVIM_VER" != "$(cat "$NVIM_VER_STAMP" 2>/dev/null)" ] && NVIM_VER_CHANGED=1

    LOCK_FILE="$DOTFILES_DIR/nvim/lazy-lock.json"
    LOCK_STAMP="$STATE_DIR/lazy-lock.sha256"
    LOCK_HASH=""
    [ -f "$LOCK_FILE" ] && LOCK_HASH="$(_sha256 "$LOCK_FILE")"
    if [ "$NVIM_VER_CHANGED" = 1 ] || [ ! -d "$NVIM_DATA_DIR/lazy" ] || [ "$LOCK_HASH" != "$(cat "$LOCK_STAMP" 2>/dev/null)" ]; then
        echo "[Neovim] Syncing plugins to lockfile..."
        if nvim --headless "+Lazy! restore" +qa; then
            echo "$LOCK_HASH" > "$LOCK_STAMP"
        else
            echo "[WARNING] Lazy restore failed; plugins will re-sync next run."
        fi
    else
        echo "[Neovim] Plugins already match the lockfile — skipping Lazy restore."
    fi

    echo "$CUR_NVIM_VER" > "$NVIM_VER_STAMP"
fi

# -----------------------------------------------------------------------------
# htop / btop preconfiguration
# -----------------------------------------------------------------------------
# These tools rewrite their config on exit, so seed (copy) rather than symlink.
echo "==== Seeding htop / btop configs ===="

seed_config() {
    local src="$1" dest="$2"
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
        mv "$dest" "${dest}.backup.$(date +%s)"
        echo "[Backup] Saved existing $dest"
    fi
    cp "$src" "$dest"
    echo "[Config] Seeded $dest"
}

if command -v btop &>/dev/null; then
    seed_config "$DOTFILES_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
fi

# htop >= 3.2 uses named fields; older htop needs the legacy numeric format.
if command -v htop &>/dev/null; then
    HTOP_RC="$HOME/.config/htop/htoprc"
    htver="$(htop --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    if [ -n "$htver" ] && [ "$(printf '%s\n3.2.0\n' "$htver" | sort -V | head -1)" != "3.2.0" ]; then
        echo "[htop] Detected htop $htver (< 3.2); writing legacy numeric-field config..."
        mkdir -p "$(dirname "$HTOP_RC")"
        [ -f "$HTOP_RC" ] && mv "$HTOP_RC" "${HTOP_RC}.backup.$(date +%s)"
        cat > "$HTOP_RC" <<'HTOPRC'
htop_version=3.0.5
config_reader_min_version=2
fields=0 48 17 18 38 39 2 46 47 37 50 1
sort_key=46
sort_direction=-1
hide_kernel_threads=0
hide_userland_threads=0
shadow_other_users=0
show_thread_names=1
show_program_path=0
highlight_base_name=1
highlight_megabytes=1
highlight_threads=1
find_comm_in_cmdline=1
strip_exe_from_cmdline=1
show_merged_command=0
tree_view=0
header_margin=1
detailed_cpu_time=0
cpu_count_from_one=0
show_cpu_usage=1
show_cpu_frequency=1
show_cpu_temperature=1
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
enable_mouse=1
delay=15
hide_function_bar=0
header_layout=two_50_50
column_meters_0=LeftCPUs2 Memory Swap
column_meter_modes_0=1 1 1
column_meters_1=RightCPUs2 Tasks LoadAverage Uptime
column_meter_modes_1=1 2 2 2
HTOPRC
        echo "[Config] Seeded $HTOP_RC (legacy format)"
    else
        seed_config "$DOTFILES_DIR/htop/htoprc" "$HTOP_RC"
    fi
fi

# -----------------------------------------------------------------------------
# Finalization
# -----------------------------------------------------------------------------

echo "==== Setup Complete ===="
