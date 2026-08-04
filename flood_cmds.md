# Flood Load Generation

`floodsd` ("flood standalone") load-tests a remote firedancer validator from a
*separate* box, aimed at a target over the wire. Always sends 64B (min-sized)
UDP packets at dport 9000.

It's a single self-contained bash script: no zsh, nothing sourced into any
shell.

The flood engine is the in-kernel pktgen module (no DPDK/hugepages needed),
with a target-Mpps rate limit and a live Mpps monitor.

## Install

```sh
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (cd ~/dotfiles && git fetch && git reset --hard origin/main) && chmod +x ~/dotfiles/install-floodsd.sh && ~/dotfiles/install-floodsd.sh
```

## Commands

| Command | Action |
| :--- | :--- |
| `floodsd setup` | Pick the sending NIC, enter the destination IP; sends a UDP probe and resolves the MAC from the neighbor table (also a reachability check). Saved per-machine. |
| `floodsd kernel` | Configure in-kernel pktgen threads (top-down cores) at a target Mpps (or MAX), start the flood, and show a live Mpps counter. |
| `floodsd stop` | Stop the flood (`floodsd kernel`'s Ctrl-C only stops watching, not the traffic). |

`setup` and `kernel` also take `--multiport`, which rotates the src port
across a range so the target hashes the flood across all its RX queues / net
tiles (default: single src port, one queue).
