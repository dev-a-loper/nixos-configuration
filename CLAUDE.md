# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### System Rebuild (Primary)
```bash
sudo https_proxy=http://localhost:1080 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --flake path:./#nixos-new-laptop --impure
```

### Other Systems
```bash
sudo nixos-rebuild switch --flake .#nixos-home-desktop --impure  # Desktop (NVIDIA)
sudo nixos-rebuild switch --flake .#nixos-laptop --impure          # Older laptop
sudo nixos-rebuild switch --flake .#tablet --impure                # Tablet (KDE Plasma6)
```

### Build Images
```bash
# ISO image
sudo nixos-rebuild switch --flake .#iso --impure

# USB installation
sudo nix run github:nix-community/disko -- --mode disko hosts/usb-disko.nix
echo -n "password" > /tmp/secret.key
sudo nixos-install --flake path:./#usb --impure --root /mnt
```

**Important:** All builds use `--impure` flag because secrets are sourced from gitignored files outside the nix store.

## Repository Architecture

### Module Organization

```
flake.nix                      # Central orchestrator, defines all systems
├── hosts/                     # Per-host configurations
│   ├── base.nix              # Base template (imports default.nix + hardware)
│   ├── new-laptop.nix        # Main laptop (TLP, keyboard remap)
│   ├── laptop.nix            # Older laptop (TLP)
│   ├── home-pc.nix           # Desktop (NVIDIA drivers, taskchampion)
│   ├── tablet.nix            # KDE Plasma6 + disko partitions
│   ├── usb.nix               # Full USB install + LUKS + disko
│   └── iso.nix               # Live ISO image
│
├── default.nix               # Top-level module aggregator
│
├── system/                   # Core system configuration
│   ├── boot.nix              # GRUB bootloader
│   ├── users.nix             # User "ehsan" definition
│   ├── nix.nix               # Flakes, GC settings
│   ├── network.nix           # VPNs, proxies, ExpressVPN
│   ├── slipstream.nix        # Custom DNS channel package
│   └── printing.nix          # Printing service
│
├── gui/                      # Hyprland/Wayland desktop
│   ├── default.nix           # GUI aggregator (Hyprland, SDDM, fonts, packages, home-manager)
│   ├── hyprland-config.nix   # Hyprland WM config, keybindings, window rules
│   ├── waybar.nix            # Status bar
│   ├── firefox.nix           # Firefox settings
│   ├── media.nix             # Media applications
│   └── Custom shell apps: notitrans-{fa,en,dict}, search-select, ensure-class-hyprland
│
├── cli/                      # Command-line tools
│   └── zsh, shells, utilities
│
├── programming/              # Development environment
│   ├── editors.nix           # Neovim via nixvim
│   ├── claude-code.nix       # Claude Code config (AI assistant)
│   ├── virtualisation.nix    # Docker, libvirt, virt-manager
│   └── nixvim/               # Modular Neovim config
│       ├── lsp.nix           # LSP, completion, keybinds
│       ├── telescope.nix     # Fuzzy finder
│       ├── agentic.nix       # Agentic AI assistant
│       └── ...               # navigation, ui, terminal, treesitter, comment, gitsigns, options
│
└── praytimes/                # Islamic prayer times service
```

### Flake Special Arguments

The flake passes these to all modules via `specialArgs`:
- `unstable` - Unstable nixpkgs import with unfree enabled
- `hardware-configuration` - From `./vars/hardware-configuration.nix`

Secrets are injected via `config.userConfiguration.secrets` (defined in `system/userInfo.nix`).

### Import Hierarchy

```
flake.nix → nixosConfigurations
    └── hosts/<host>.nix
        └── hosts/base.nix
            └── default.nix
                ├── system/default.nix
                ├── gui/default.nix
                ├── cli/default.nix
                ├── programming/default.nix
                └── praytimes/default.nix
```

## Secrets Management

Secrets live in `vars/secrets.*.nix` (gitignored, matched by `vars/*.nix` in `.gitignore`):

- `vars/secrets.default.nix` — **boot parent**: shared infrastructure (proxy
  generation via `utils/sing-box.nix`, OpenVPN configs, shared API keys) plus
  Ehsan's full profile (location, keys, password, filtered proxy set). Also
  exposes `allProxies` (the full, unfiltered proxy set).
- `vars/secrets.<name>.nix` — each becomes a runtime-switchable
  `specialisation.<name>` (auto-discovered by `flake.nix` via `readDir`). It is a
  **delta** on the parent: it inherits shared keys via `inheritParentConfig` and
  `mkForce`-overrides only what differs (identity, location, keys, proxy set),
  plus any system overrides (e.g. a different user's identity +
  timezone/service tweaks).

They are injected into `config.userConfiguration.secrets`; the full schema is
defined in `system/userInfo.nix`. The secrets evaluate because the flake is
accessed via the `path:` fetcher — always build with `--impure`
(`--flake path:./#…` from inside the repo).

Access secrets in modules via `config.userConfiguration.secrets.<key>`.

Required keys:

| Key | Purpose |
|-----|---------|
| `HASHED_PASSWORD` | User password hash |
| `proxies` | Attrset of shell scripts for different proxies |
| `defaultProxy` | Default proxy name |
| `OPENAI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY` | AI API keys |
| `OPENAI_API_HOST` | API host override |
| `location` | `{latitude, longitude}` for praytimes/redshift |
| `taskwarrior-secret` | Task sync encryption |
| `NOTIFIER_BOT_TOKEN`, `CHAT_ID` | Telegram notifications |
| `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL` | Custom Anthropic proxy (z.ai) |
| `awg-config` | AmneziaVPN config |
| `openvpn` | OpenVPN config |

Hardware config goes in `vars/hardware-configuration.nix`.

## Host-Specific Notes

| Host | Special Features |
|------|------------------|
| `nixos-new-laptop` | Main system, keyboard remap via udev, TLP |
| `nixos-home-desktop` | NVIDIA drivers, taskchampion sync server |
| `tablet` | KDE Plasma6, disko partitions |
| `usb` | LUKS encryption, disko partitions |
| `iso` | Live image |

## Networking & Proxies

- Proxy always available on `localhost:1080` (socks5)
- VPN options: ExpressVPN, OpenVPN, AmneziaVPN (awg), Tor
- `slipstream` package provides covert DNS channel
- `chproxy` utility (systemd proxy.service) switches between proxies
- Configured in `system/network.nix`

## Claude Code Integration

Located in `programming/claude-code.nix` (imported by `programming/default.nix`):
- Custom API endpoint: `https://api.z.ai/api/anthropic`
- Model: `glm-5.1`
- MCP servers: `web-search-prime`, `zai-mcp-server`, `web-reader`, `zread`
- Hooks: notify-send + Telegram notifications

## Nixvim Configuration

Modular Neovim config in `programming/nixvim/`:
- Each aspect is a separate module (lsp, telescope, agentic, terminal, treesitter, etc.)
- Built via nixvim wrapper in flake.nix
- Accessible via the `nvim` binary (nixvim) or the `nv` alias (`neovide --fork`)

## Custom Shell Applications

Many utilities use `writeShellApplication`:
- `gui/notitrans-fa.nix` - Translate selected text to Persian
- `gui/notitrans-en.nix` - Translate selected text to English
- `gui/notitrans-dict.nix` - Dictionary lookup
- `gui/search-select.nix` - Search selected text in Firefox
- `gui/ensure-class-hyprland.nix` - Force a Hyprland window to run with a specific class
