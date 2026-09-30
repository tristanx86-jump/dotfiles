# Start zsh for interactive shells when the login shell is bash.
_old_tools_path="$HOME/.local/share/dotfiles/tools/bin"
while [[ ":$PATH:" == *":$_old_tools_path:"* ]]; do
    PATH=":$PATH:"
    PATH="${PATH/:$_old_tools_path:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
done
unset _old_tools_path
export PATH="$HOME/.local/bin:$PATH"
[[ $- == *i* ]] && command -v zsh >/dev/null 2>&1 && exec zsh -l

# ── Everything below only runs when zsh is genuinely unavailable ──────────────

export EDITOR="nvim"

# Aliases
alias ll='ls -la'
alias v='nvim'
alias vim='nvim'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias disable-ht="echo off | sudo tee /sys/devices/system/cpu/smt/control"
alias enable-ht="echo on | sudo tee /sys/devices/system/cpu/smt/control"
