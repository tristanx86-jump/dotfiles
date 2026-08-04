# Flood Load Generation

`floodsd` ("flood standalone") load-tests a remote firedancer validator from a
*separate* box, aimed at a target over the wire. Always sends 64B (min-sized)
UDP packets at dport 9000.

It's a single self-contained bash script: no zsh, nothing sourced into any
shell.

Two flood engines, chosen explicitly per run:

- `dpdk` — DPDK pktgen (userspace, needs a NIC bound to vfio-pci or Mellanox/mlx5).
- `kernel` — the in-kernel pktgen module (no DPDK/hugepages needed), with a
  target-Mpps rate limit and a live Mpps monitor.

## Install

From a clone of the repo on the sending box:

```sh
bash install-floodsd.sh
```

Copies `bin/floodsd` to `~/.local/bin` (never system-wide) and installs
`updateflood` alongside it. Installs nothing else and makes no shell rc
changes. If `~/.local/bin` isn't on your PATH it offers (opt-in) to add it.
DPDK/Pktgen-DPDK is only installed lazily on first `floodsd dpdk` run, with
its own prompt.

Refresh later with `updateflood` — re-fetches the repo and re-runs the
installer; updates `floodsd` only, installs nothing new, makes no rc changes.

## Commands

| Command | Action |
| :--- | :--- |
| `floodsd setup [--multiport]` | Pick the sending NIC, enter the destination IP; sends a UDP probe and resolves the MAC from the neighbor table (also a reachability check). Saved per-machine. `--multiport` rotates the src port across a range so the target hashes the flood across all its RX queues / net tiles (default: single src port → one queue). |
| `floodsd setup-srcport` | Change just the saved source port(s) without redoing the full setup. |
| `floodsd diagnose [--multiport]` | Check the saved target / NIC / MAC resolution and firewall egress without starting a flood. |
| `floodsd dpdk` | Installs DPDK + builds Pktgen-DPDK from source if missing (asks first), binds the NIC (vfio-pci, skipped for Mellanox) + reserves hugepages, then launches DPDK pktgen at the saved target. Drops you at pktgen's prompt — run `start 0` and `set 0 rate <pct>` yourself. |
| `floodsd kernel [--multiport]` | Configure in-kernel pktgen threads (top-down cores) at a target Mpps (or MAX), start the flood, and show a live Mpps counter. |
| `floodsd stop` | Stop the in-kernel pktgen flood (`floodsd kernel`'s Ctrl-C only stops watching, not the traffic). |
| `floodsd restore` | Undo `floodsd dpdk`'s vfio-pci bind — return the NIC to its kernel driver (and reattach a detached bond slave). |

**Bonded NICs:** `setup` accepts a bond master or a slave. A slave alone
can't resolve the target's MAC (bonding reassigns inbound replies to the
master), so `setup` probes via the master while recording the slave to flood
from. Neither engine can drive a bond master directly, so if the saved
target is a bond master both engines prompt for a slave; `floodsd dpdk`
offers to pull it out of the bond first and `floodsd restore` puts it back.
