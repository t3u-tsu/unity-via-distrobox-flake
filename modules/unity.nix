{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.my.unity;
  launcher = builtins.readFile ../files/launcher.sh;
  distroboxIni = builtins.readFile ../files/distrobox.ini;
in
{
  options.my.unity = {
    enable = mkEnableOption "Unity development tools";

    useDistrobox = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use Distrobox (Ubuntu 22.04 container) for Unity Hub and Editor
        instead of the native nixpkgs package.

        The native `unityhub` package on NixOS uses bubblewrap for FHS
        emulation, but the Unity Editor build process runs outside that
        sandbox and fails to find system libraries.

        Distrobox provides a full Ubuntu FHS environment where Unity is
        officially supported.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # ── Native package path ────────────────────────────────────────
    # Directly install the nixpkgs `unityhub` package. Prefer
    # `useDistrobox = true` for actual Unity Editor work.
    (mkIf (!cfg.useDistrobox) {
      home.packages = [ pkgs.unityhub ];
    })

    # ── Distrobox path ─────────────────────────────────────────────
    (mkIf cfg.useDistrobox {
      # Declarative distrobox spec consumed by `distrobox assemble create`.
      # Written to $XDG_CONFIG_HOME/distrobox/distrobox.ini.
      xdg.configFile."distrobox/distrobox.ini".text = distroboxIni;

      # Desktop entry for host integration.
      # NOTE: xdg.desktopEntries is broken in the current home-manager
      # release (the removed `extraConfig` option is evaluated for every
      # entry), so the .desktop file is shipped directly via xdg.dataFile.
      # Exec goes through systemd-run --user so browsers (which run in their
      # own sandboxed namespaces) can deep-link into the container via the
      # unityhub:// scheme.
      xdg.dataFile."applications/unityhub.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Unity Hub
        GenericName=Unity Hub Launcher
        Exec=systemd-run --user --collect -- ${config.home.profileDirectory}/bin/unityhub %U
        Icon=unityhub
        MimeType=x-scheme-handler/unityhub;
        Categories=Development;
        Terminal=false
      '';

      # Self-healing launcher. runtimeInputs pins distrobox/podman on PATH
      # (the script itself still falls back to a PATH lookup when run
      # directly). shellcheck runs at build time via writeShellApplication.
      home.packages = [
        (pkgs.writeShellApplication {
          name = "unityhub";
          runtimeInputs = [
            pkgs.distrobox
            pkgs.podman
          ];
          text = launcher;
        })
      ];
    })
  ]);
}
