# ── Firedancer Development ───────────────────────────
# Build/run commands for the firedancer validator. Config management lives in
# firedancer-config.zsh; pktgen/loopback setup in firedancer-pktgen.zsh.
#
# Which firedancer binary the fd commands drive. Switch with `switchfd <name>`,
# stored per-device in an untracked file (defaults to firedancer-dev).
FD_BIN_FILE="$HOME/.config/dotfiles/fdbin"
_fdbin() { cat "$FD_BIN_FILE" 2>/dev/null || echo firedancer-dev; }
# _fdbinpath uses the selected Clang build link, then current and older Clang layouts.
# Return an absolute path so sudo does not need the binary on PATH.
_fdbinpath() {
    local name objdir bin clang_bin=""
    local -a candidates
    name=$(_fdbin) || return
    objdir=$(make -s --no-print-directory CC=clang objdir 2>/dev/null)
    if [[ -n "$objdir" ]]; then
        clang_bin="$objdir/bin/$name"
        clang_bin="${clang_bin:A}"
    fi
    bin="$PWD/build/$name"
    if [[ -n "$clang_bin" && -f "$bin" && -x "$bin" && "${bin:A}" == "$clang_bin" ]]; then
        print -r -- "$bin"
        return
    fi
    if [[ -n "$clang_bin" && -f "$clang_bin" && -x "$clang_bin" ]]; then
        print -r -- "$clang_bin"
        return
    fi
    candidates=(build/*/clang/bin/$name(N.Om))
    for bin in "${candidates[@]}"; do
        if [[ -f "$bin" && -x "$bin" ]]; then
            print -r -- "${bin:a}"
            return
        fi
    done
    print -u2 -- "fd: executable missing for $name. Run makefd from the Firedancer checkout."
    return 1
}
# Make target(s) for the current binary. fddev also needs the solana target.
_fdtarget() { case "$(_fdbin)" in fddev) echo "fddev solana";; *) echo "$(_fdbin)";; esac; }

# _fd_clip <text>: copy text to the *local* clipboard via OSC 52, which
# round-trips over SSH (iTerm2's AllowClipboardAccess is enabled in
# install.sh) — same mechanism nvim/init.lua uses for its own OSC 52
# clipboard. Terminal.app doesn't support OSC 52, so it gets pbcopy instead.
# Wrapped in tmux's passthrough sequence when inside tmux, or the escape
# never reaches the outer terminal.
function _fd_clip() {
    local text=$1
    if [ "$TERM_PROGRAM" = "Apple_Terminal" ] && command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$text" | pbcopy
        return
    fi
    local b64
    b64=$(printf '%s' "$text" | base64 | tr -d '\n')
    if [ -n "$TMUX" ]; then
        printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$b64"
    else
        printf '\033]52;c;%s\a' "$b64"
    fi
}

# _fd_show <cmd...>: print the command — quoted so it's safe to paste back
# verbatim (e.g. prefixed with `perf record --` or wrapped in `gdb --args`)
# — and copy it to the clipboard via _fd_clip. Does NOT execute it; you paste
# and run it yourself (optionally wrapped in another tool first).
function _fd_show() {
    local printed
    printed=$(printf '%q ' "$@")
    printed=${printed% }
    echo "$printed"
    _fd_clip "$printed"
}

# _fd_dispatch <mode> <cmd...>: shared body for every fd function's `cmd`
# subcommand (devfd cmd, pktfd cmd, ...) — <mode> is the caller's un-shifted
# $1. "cmd" shows+copies <cmd...> via _fd_show instead of running it;
# anything else (typically empty) just executes it.
function _fd_dispatch() {
    local mode=$1; shift
    if [ "$mode" = cmd ]; then _fd_show "$@"; else "$@"; fi
}

# switchfd <name>: pick the firedancer binary makefd/devfd/pktfd/... use.
function switchfd() {
    if [ -z "$1" ]; then
        echo "Current firedancer binary: $(_fdbin) (make target: $(_fdtarget))"
        echo "Usage: switchfd <firedancer-dev|fddev|firedancer|...>"
        return 0
    fi
    mkdir -p "$(dirname "$FD_BIN_FILE")"
    echo "$1" > "$FD_BIN_FILE"
    echo "Firedancer binary set to: $1 (make target: $(_fdtarget))"
}

# These were aliases historically; drop any stale alias so re-sourcing .zshrc
# (without a fresh shell) doesn't shadow the functions — an alias would make
# `pktfd setup` expand to `... pktgen ... setup` instead of running the setup.
unalias makefd updatefd pktfd benchfd devfd testnetfd flamefd monitorfd metricsfd memfd initfd finifd 2>/dev/null

# Every function below takes an optional `cmd` first argument (see
# _fd_dispatch): plain `devfd` runs the validator, `devfd cmd` just shows +
# copies the command it would have run.
function makefd()    { make -j CC=clang $(_fdtarget); }
function devfd() {
    local bin
    bin=$(_fdbinpath) || return
    if [ "$1" = gdb ]; then shift; sudo gdb -q --args "$bin" dev --config "$(_fdconfig)" "$@"; return; fi
    _fd_dispatch "$1" sudo "$bin" dev --config "$(_fdconfig)"
}
function benchfd() {
    local bin
    bin=$(_fdbinpath) || return
    if [ "$1" = gdb ]; then shift; sudo gdb -q --args "$bin" bench --config "$(_fdconfig)" "$@"; return; fi
    _fd_dispatch "$1" sudo "$bin" bench --config "$(_fdconfig)"
}
function testnetfd() {
    local bin
    bin=$(_fdbinpath) || return
    if [ "$1" = gdb ]; then shift; sudo gdb -q --args "$bin" --testnet --config "$(_fdconfig)" "$@"; return; fi
    _fd_dispatch "$1" sudo "$bin" --testnet --config "$(_fdconfig)"
}
function flamefd() {
    local bin
    bin=$(_fdbinpath) || return
    _fd_dispatch "$1" sudo "$bin" flame --config "$(_fdconfig)"
}
function monitorfd() {
    local bin mode=$1
    if [ "$mode" = cmd ]; then shift; fi
    bin=$(_fdbinpath) || return
    _fd_dispatch "$mode" sudo "$bin" monitor --config "$(_fdconfig)" "$@"
}
function metricsfd() {
    local bin
    bin=$(_fdbinpath) || return
    _fd_dispatch "$1" sudo "$bin" metrics --config "$(_fdconfig)"
}
function memfd() {
    local bin
    bin=$(_fdbinpath) || return
    if [ "$1" = cmd ]; then _fd_show sudo "$bin" mem --config "$(_fdconfig)"; return; fi
    sudo "$bin" mem --config "$(_fdconfig)" | less
}
function initfd() {
    local bin
    bin=$(_fdbinpath) || return
    _fd_dispatch "$1" sudo "$bin" configure init all --config "$(_fdconfig)"
}
function finifd() {
    local bin
    bin=$(_fdbinpath) || return
    _fd_dispatch "$1" sudo "$bin" configure fini all --config "$(_fdconfig)"
}

# timenet reports mean and one-second min/max CPU use over 10 seconds.
function timenet() {
    if [[ $# -ne 0 ]]; then
        print -u2 -- "Usage: timenet"
        return 1
    fi
    python3 - <<'PY'
import os
import re
import sys
import time


def fail(message):
    print(f"timenet: {message}", file=sys.stderr)
    sys.exit(1)


def tiles():
    found = {}
    for pid in os.listdir("/proc"):
        if not pid.isdecimal():
            continue
        try:
            with open(f"/proc/{pid}/comm") as file:
                name = file.read().strip()
        except FileNotFoundError:
            continue
        if not re.fullmatch(r"(?:mlx5|net):[0-9]+", name):
            continue
        try:
            with open(f"/proc/{pid}/stat") as file:
                stat = file.read().rsplit(") ", 1)[1].split()
            with open(f"/proc/{pid}/schedstat") as file:
                runtime = int(file.read().split()[0])
        except FileNotFoundError:
            continue
        except OSError as exc:
            fail(f"cannot read {name} (PID {pid}): {exc}")
        found[int(pid)] = (name, int(stat[1]), int(stat[19]), runtime)
    return found


start = tiles()
if not start:
    fail("no mlx5 or net tile is running")
if len({tile[0].split(":")[0] for tile in start.values()}) != 1:
    fail("both mlx5 and net tiles are running")
if len({tile[1] for tile in start.values()}) != 1:
    fail("tiles from multiple validators are running")
if len({tile[0] for tile in start.values()}) != len(start):
    fail("duplicate tile names are running")

previous = start
begin_ns = previous_ns = time.monotonic_ns()
samples = {pid: [] for pid in start}
total_samples = []
for _ in range(10):
    time.sleep(1)
    current = tiles()
    current_ns = time.monotonic_ns()
    if start.keys() != current.keys() or any(start[pid][:3] != current[pid][:3] for pid in start):
        fail("a tile started, stopped, or restarted during the sample")
    elapsed_ns = current_ns - previous_ns
    total_runtime_ns = 0
    for pid in start:
        runtime_ns = current[pid][3] - previous[pid][3]
        if runtime_ns < 0:
            fail(f"CPU counter decreased for {start[pid][0]}, retry")
        samples[pid].append(100.0 * runtime_ns / elapsed_ns)
        total_runtime_ns += runtime_ns
    total_samples.append(100.0 * total_runtime_ns / elapsed_ns)
    previous, previous_ns = current, current_ns

elapsed_ns = previous_ns - begin_ns
mode = next(iter(start.values()))[0].split(":")[0]
print(f"{mode} CPU over {elapsed_ns / 1e9:.1f}s, percent of one core")
print("  tile       mean     min     max")
total_mean = 0.0
for pid in sorted(start, key=lambda pid: int(start[pid][0].split(":")[1])):
    name = start[pid][0]
    mean = 100.0 * (previous[pid][3] - start[pid][3]) / elapsed_ns
    total_mean += mean
    print(f"  {name:<8} {mean:6.2f}% {min(samples[pid]):6.2f}% {max(samples[pid]):6.2f}%  (PID {pid})")
print(f"  {'total':<8} {total_mean:6.2f}% {min(total_samples):6.2f}% {max(total_samples):6.2f}%")
PY
}

# ── Firedancer Fork Sync ──────────────────────────────
# updatefd: sync local + origin main to upstream's main. Only ever touches
# main — refuses to run with any uncommitted/staged changes (regardless of
# which branch they're on), and switches back to your original branch after,
# so whatever you were working on is left untouched.
function updatefd() {
    if [ -n "$(git status --porcelain)" ]; then
        echo "updatefd: working tree has uncommitted changes — commit or stash first."
        return 1
    fi
    local ans
    read "ans?Force-sync main to upstream? [Y/n] "
    case "$ans" in n|N|no|No) echo "Aborted."; return 1;; esac

    local cur
    cur=$(git branch --show-current)

    # Safety: never force-push to the real upstream. If origin points at
    # firedancer-io (the canonical repo), refuse - a force-push there is
    # outward-facing and forbidden.
    local originurl
    originurl=$(git remote get-url origin 2>/dev/null)
    if printf '%s' "$originurl" | grep -qi 'firedancer-io'; then
        echo "updatefd: origin is the upstream firedancer-io repo ($originurl)."
        echo "  Refusing to force-push to upstream. Point origin at your fork first."
        return 1
    fi

    git fetch upstream || return 1
    git checkout main || return 1
    git reset --hard upstream/main || return 1
    git push --force origin main
    local status=$?
    if [ -n "$cur" ] && [ "$cur" != main ]; then
        git checkout "$cur"
    fi
    return $status
}
