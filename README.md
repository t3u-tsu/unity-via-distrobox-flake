# unity-via-distrobox-flake

[![Nix Flake Check](https://github.com/t3u-tsu/unity-via-distrobox-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/t3u-tsu/unity-via-distrobox-flake/actions/workflows/ci.yml)

Runs Unity Hub and the Unity Editor on NixOS inside a [Distrobox](https://github.com/89luca89/distrobox) Ubuntu 22.04 container, where Unity is officially supported (the native nixpkgs package fails in the Editor's build subprocesses).

## Usage

```nix
# flake.nix
inputs.unity-via-distrobox.url = "github:t3u-tsu/unity-via-distrobox-flake";
```

```nix
# home-manager module
{ inputs, ... }: {
  imports = [ inputs.unity-via-distrobox.homeManagerModules.unity ];
  my.unity.enable = true;
}
```

After `nixos-rebuild switch`, launching `unityhub` provisions the container on first run and starts Unity Hub.

### Options

| Option | Default | Description |
| --- | --- | --- |
| `my.unity.enable` | `false` | Enable Unity development tools via Distrobox. |

## What it installs

- `~/.config/distrobox/distrobox.ini` — container spec for `distrobox assemble create`
- `~/.local/bin/unityhub` — launcher (auto-provisioning, self-healing)
- `~/.local/share/applications/unityhub.desktop` — desktop entry

## Maintenance

- Rebuild the container: `distrobox rm -f unity-via-distrobox`, then launch `unityhub`
- On setup failure the launcher prints the container log tail and keeps the full log at `/tmp/unity-assemble-*.log`

## Development

- `nix flake check` — module evaluation + shellcheck
- GitHub Actions runs `nix flake check` on every push/PR

## License

0BSD — see [LICENSE](LICENSE).
