# Tristan Carter's macOS/Linux Development Setup

Sets up my configured development environment with Neovim, tmux, and Zsh. The full installer targets Linux. macOS uses the reduced client installer.

## Prerequisites

`git` is needed to clone the repo. On Linux, the full installer checks the
selected packages using the system package database. It lists missing packages
and asks before installing them with `sudo apt-get`, `dnf`, or `yum`. A separate
prompt lists installed packages and offers to update them if newer versions are
available. Declining that prompt leaves existing packages unchanged.
It does not add package repositories or change the login shell. RHEL-family
systems may need EPEL enabled beforehand for tools such as btop and ripgrep.
It links `firedancer-dev`, `fddev`, `fdctl`, and `solana` into `/usr/bin`
so `sudo` can find the current build. This may require sudo even when no
packages are missing.
Neovim 0.11 or newer and editor plugins remain user-local. C/C++ diagnostics
use the system `clangd` (`clangd` on Debian, `clang-tools-extra` on RHEL).
The installer does not install Node.js, npm, Mason, or tree-sitter CLI/parsers.
The optional FiraCode Nerd Font is installed for the current user after a
separate prompt that identifies the third-party ZIP download. Only that font
step may install `unzip` if it is missing. Rocky 9's packaged Neovim 0.8 is
too old for this config.
Kernel tracing tools require separate host support. Zsh uses its built-in
prompt. Set `DOTFILES_INSTALL_DEBUG_TOOLS=1` to include LLDB and LLD in the
core package prompts.

## Installation

Copy and paste this one-liner into your terminal to clone (or update) the repository and run the setup script automatically:

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install.sh && ~/dotfiles/install.sh && exec zsh
```

## Reduced / client setup

For a restricted machine. `install-client.sh` never uses `sudo`. It offers
FiraCode Nerd Font for the current macOS user, then sets up the terminal and
host/SSH management (`s`/`sfd`, see `host_cmds.md` / `hostdot`).

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install-client.sh && ~/dotfiles/install-client.sh && exec zsh
```

Standalones: `floodsd`

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install-floodsd.sh && ~/dotfiles/install-floodsd.sh
```
