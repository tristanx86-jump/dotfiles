# Tristan Carter's macOS/Linux Development Setup

## Linux

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install.sh && ~/dotfiles/install.sh && exec zsh
```

## macOS client

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install-client.sh && ~/dotfiles/install-client.sh && exec zsh
```

## floodsd only

```bash
git clone https://github.com/tristanx86-jump/dotfiles.git ~/dotfiles 2>/dev/null || (git -C ~/dotfiles remote set-url origin https://github.com/tristanx86-jump/dotfiles.git && git -C ~/dotfiles fetch origin main && git -C ~/dotfiles reset --hard origin/main) && chmod +x ~/dotfiles/install-floodsd.sh && ~/dotfiles/install-floodsd.sh
```
