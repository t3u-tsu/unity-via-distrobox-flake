# unity-via-distrobox-flake

[![Nix Flake Check](https://github.com/t3u-tsu/unity-via-distrobox-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/t3u-tsu/unity-via-distrobox-flake/actions/workflows/ci.yml)

Runs Unity Hub and the Unity Editor on NixOS inside a [Distrobox](https://github.com/89luca89/distrobox) Ubuntu 22.04 container, where Unity is officially supported (the native nixpkgs package fails in the Editor's build subprocesses).

## Usage

```nix
# flake.nix
inputs.unity-via-distrobox.url = "github:t3u-tsu/unity-via-distrobox-flake";
```

```nix
# NixOS module: installs the system dependencies (rootless podman + distrobox)
{ inputs, ... }: {
  imports = [ inputs.unity-via-distrobox.nixosModules.unity ];
  services.unity-via-distrobox.enable = true;
}
```

```nix
# home-manager module: launcher, systemd unit, desktop entry
{ inputs, ... }: {
  imports = [ inputs.unity-via-distrobox.homeManagerModules.unity ];
  my.unity.enable = true;
}
```

After `nixos-rebuild switch`, launching `unityhub` (or the desktop entry) provisions the container on first run and starts Unity Hub.

> If you use only the home-manager module, you must install `podman` (rootless) and `distrobox` yourself; the NixOS module does this for you.

### Options

| Option | Default | Description |
| --- | --- | --- |
| `services.unity-via-distrobox.enable` | `false` | (NixOS) Install podman + distrobox and enable rootless podman. |
| `my.unity.enable` | `false` | (home-manager) Enable the launcher, systemd unit and desktop entry. |
| `my.unity.stopOnExit` | `false` | Stop the Distrobox container when Unity Hub exits. |

## What it installs

- `~/.config/distrobox/distrobox.ini` — container spec for `distrobox assemble create`
- `~/.local/bin/unityhub` — launcher (auto-provisioning, self-healing)
- `~/.local/share/applications/unityhub.desktop` — desktop entry (`systemd-run --user`)
- `~/.config/systemd/user/unity-via-distrobox.service` — systemd unit (provision via `ExecStartPre`, run via `ExecStart`)

## Operation

- Status: `systemctl --user status unity-via-distrobox`
- Logs: `journalctl --user -u unity-via-distrobox`
- Stop the container: `distrobox stop unity-via-distrobox`
- Rebuild the container: `distrobox rm -f unity-via-distrobox`, then launch `unityhub`
- Setup failure logs are kept at `/tmp/unity-assemble-*.log`

## Development

- `nix flake check` — module evaluation + `ysh -n` syntax checks
- GitHub Actions runs `nix flake check` on every push/PR

## License

0BSD — see [LICENSE](LICENSE).
