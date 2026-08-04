# Flood Load Generation

`floodsd` ("flood standalone") load-tests a remote firedancer validator from a
*separate* box, aimed at a target over the wire. Always sends 64B (min-sized)
UDP packets at dport 9000.

It's a single self-contained bash script: no zsh, nothing sourced into any
shell.

Two flood engines, chosen explicitly per run:

- `dpdk`: DPDK pktgen (userspace, needs a NIC bound to vfio-pci or Mellanox/mlx5).
- `kernel`: the in-kernel pktgen module (no DPDK/hugepages needed), with a
  target-Mpps rate limit and a live Mpps monitor.

## Install

```sh
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (cd ~/dotfiles && git fetch && git reset --hard origin/main) && chmod +x ~/dotfiles/install-floodsd.sh && ~/dotfiles/install-floodsd.sh
```

## Commands

| Command | Action |
| :--- | :--- |
| `floodsd setup [--multiport]` | Pick the sending NIC, enter the destination IP; sends a UDP probe and resolves the MAC from the neighbor table (also a reachability check). Saved per-machine. `--multiport` rotates the src port across a range so the target hashes the flood across all its RX queues / net tiles (default: single src port, one queue). |
| `floodsd setup-srcport` | Change just the saved source port(s) without redoing the full setup. |
| `floodsd diagnose [--multiport]` | Check the saved target / NIC / MAC resolution and firewall egress without starting a flood. |
| `floodsd dpdk` | Installs DPDK + builds Pktgen-DPDK from source if missing (asks first), binds the NIC (vfio-pci, skipped for Mellanox) + reserves hugepages, then launches DPDK pktgen at the saved target. Drops you at pktgen's prompt; run `start 0` and `set 0 rate <pct>` yourself. |
| `floodsd kernel [--multiport]` | Configure in-kernel pktgen threads (top-down cores) at a target Mpps (or MAX), start the flood, and show a live Mpps counter. |
| `floodsd stop` | Stop the in-kernel pktgen flood (`floodsd kernel`'s Ctrl-C only stops watching, not the traffic). |
| `floodsd restore` | Undo `floodsd dpdk`'s vfio-pci bind: return the NIC to its kernel driver (and reattach a detached bond slave). |
