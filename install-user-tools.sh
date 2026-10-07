#!/usr/bin/env bash
# Install Linux development tools through the host package manager.

[ "$(uname -s)" = Linux ] || {
    echo "[ERROR] The full installer supports Linux. Use install-client.sh on macOS." >&2
    return 1
}
[ -r /etc/os-release ] || return 1
. /etc/os-release

case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*)
        package_family=debian
        package_manager=apt-get
        tool_packages=(zsh git curl tar ripgrep fd-find python3 cmake
                       clang clangd cppcheck pkg-config make tmux
                       htop btop gdb xclip numactl)
        _package_installed() {
            [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
        }
        ;;
    *" rhel "*|*" fedora "*|*" centos "*)
        package_family=rhel
        if command -v dnf >/dev/null 2>&1; then
            package_manager=dnf
        else
            package_manager=yum
        fi
        python_package=python3
        # RHEL 8 and 9 need a newer Python for Firedancer's code generators.
        case "${PLATFORM_ID:-}" in
            platform:el8|platform:el9) python_package=python3.11 ;;
        esac
        tool_packages=(zsh git curl tar ripgrep fd-find "$python_package" cmake
                       clang clang-tools-extra cppcheck pkgconf-pkg-config
                       make tmux htop btop gdb xclip numactl)
        _package_installed() { rpm -q "$1" >/dev/null 2>&1; }
        ;;
    *)
        echo "[ERROR] Unsupported Linux distribution: ${ID:-unknown}" >&2
        return 1
        ;;
esac

if [ "${DOTFILES_INSTALL_DEBUG_TOOLS:-0}" = 1 ]; then
    tool_packages+=(lldb lld)
fi
command -v "$package_manager" >/dev/null 2>&1 || {
    echo "[ERROR] $package_manager is unavailable." >&2
    return 1
}

apt_updated=0
install_selected_packages() {
    local install_rc=0 ledger package
    [ "$#" -gt 0 ] || return 0
    sudo -v || return 1
    if [ "$package_family" = debian ]; then
        if [ "$apt_updated" -eq 0 ]; then
            sudo apt-get update || return 1
            apt_updated=1
        fi
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" || install_rc=$?
    else
        sudo "$package_manager" install -y "$@" || install_rc=$?
    fi

    ledger="$STATE_DIR/system-packages-installed"
    for package in "$@"; do
        if _package_installed "$package" &&
           ! grep -Fqx "$package_family $package" "$ledger" 2>/dev/null; then
            printf '%s %s\n' "$package_family" "$package" >> "$ledger" || return 1
        fi
    done
    return "$install_rc"
}

update_selected_packages() {
    [ "$#" -gt 0 ] || return 0
    sudo -v || return 1
    if [ "$package_family" = debian ]; then
        if [ "$apt_updated" -eq 0 ]; then
            sudo apt-get update || return 1
            apt_updated=1
        fi
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade --no-install-recommends "$@"
    else
        sudo "$package_manager" upgrade -y "$@"
    fi
}

missing_packages=()
installed_packages=()
for package in "${tool_packages[@]}"; do
    if _package_installed "$package"; then
        installed_packages+=("$package")
    else
        missing_packages+=("$package")
    fi
done

core_declined=0
if [ "${#missing_packages[@]}" -gt 0 ]; then
    echo "[Tools] Core system packages"
    echo "  Install:"
    printf '    %s\n' "${missing_packages[@]}"
    printf 'Install these packages with sudo? [y/N] '
    IFS= read -r install_answer || install_answer=
    case "$install_answer" in
        y|Y|yes|Yes) install_selected_packages "${missing_packages[@]}" || return 1 ;;
        *) core_declined=1; echo "[Tools] Core packages declined." ;;
    esac
else
    echo "[Tools] No core packages to install."
fi

if [ "${#installed_packages[@]}" -gt 0 ]; then
    echo "[Tools] Existing core system packages"
    echo "  Update if newer versions are available:"
    printf '    %s\n' "${installed_packages[@]}"
    printf 'Check for updates and update these packages with sudo? [y/N] '
    IFS= read -r update_answer || update_answer=
    case "$update_answer" in
        y|Y|yes|Yes) update_selected_packages "${installed_packages[@]}" || return 1 ;;
        *) echo "[Tools] Existing packages left unchanged." ;;
    esac
fi

if ! compgen -G "$FONT_DIR/FiraCode/*.ttf" >/dev/null 2>&1; then
    font_missing_packages=()
    for package in unzip; do
        _package_installed "$package" || font_missing_packages+=("$package")
    done
    echo "[Font] Optional FiraCode Nerd Font"
    echo "  Downloads and extracts a third-party Nerd Font ZIP from GitHub."
    if [ "${#font_missing_packages[@]}" -gt 0 ]; then
        echo "  Additional system packages to install:"
        printf '    %s\n' "${font_missing_packages[@]}"
    else
        echo "  No additional system packages are needed."
    fi
    printf 'Install the font and any listed packages? [y/N] '
    IFS= read -r font_answer || font_answer=
    case "$font_answer" in
        y|Y|yes|Yes)
            install_selected_packages "${font_missing_packages[@]}" || return 1
            mkdir -p "$FONT_DIR/FiraCode"
            font_archive="$FONT_DIR/FiraCode/FiraCode.zip"
            if curl -fL --retry 3 \
                https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
                -o "$font_archive" &&
               unzip -q "$font_archive" -d "$FONT_DIR/FiraCode"; then
                rm -f "$font_archive"
                if command -v fc-cache >/dev/null 2>&1; then fc-cache -f; fi
                echo "[Font] FiraCode Nerd Font installed."
            else
                rm -f "$font_archive"
                echo "[WARNING] Nerd Font install failed. It will be offered again next run." >&2
            fi
            ;;
        *) echo "[Font] Skipped." ;;
    esac
fi

if [ "$core_declined" -eq 1 ]; then
    echo "[ERROR] Core packages were declined. Setup is incomplete." >&2
    return 1
fi

if [ "$package_family" = debian ] &&
   ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd" || return 1
fi
echo "[Tools] System development packages are present."

if [ ! -x "$HOME/.local/bin/nvim" ]; then
    case "$(uname -m)" in
        x86_64)  nvim_release=nvim-linux-x86_64 ;;
        aarch64) nvim_release=nvim-linux-arm64 ;;
        *) echo "[ERROR] Unsupported Neovim architecture" >&2; return 1 ;;
    esac
    nvim_dir="$HOME/.local/share/dotfiles/nvim"
    mkdir -p "$HOME/.local/bin" "$(dirname "$nvim_dir")" || return 1
    if [ ! -x "$nvim_dir/bin/nvim" ]; then
        if [ -e "$nvim_dir" ]; then
            echo "[ERROR] Incomplete Neovim directory at $nvim_dir" >&2
            return 1
        fi
        echo "[Neovim] Installing user-local release..."
        nvim_archive="$STATE_DIR/$nvim_release.tar.gz"
        nvim_stage="$STATE_DIR/nvim-extract"
        rm -rf "$nvim_stage"
        mkdir -p "$nvim_stage"
        curl -fL "https://github.com/neovim/neovim/releases/latest/download/$nvim_release.tar.gz" -o "$nvim_archive" || return 1
        tar -xzf "$nvim_archive" -C "$nvim_stage" --strip-components=1 || return 1
        [ -x "$nvim_stage/bin/nvim" ] || return 1
        mv "$nvim_stage" "$nvim_dir" || return 1
        rm -f "$nvim_archive"
    fi
    if [ ! -e "$HOME/.local/bin/nvim" ] && [ ! -L "$HOME/.local/bin/nvim" ]; then
        ln -s "$nvim_dir/bin/nvim" "$HOME/.local/bin/nvim" || return 1
    elif [ ! -x "$HOME/.local/bin/nvim" ]; then
        echo "[ERROR] Unusable Neovim path at ~/.local/bin/nvim" >&2
        return 1
    fi
fi
