{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.my.unity;
  distroboxIni = builtins.readFile ../files/distrobox.ini;
  unityhub = ../files/unityhub.ysh;
  minimizeToTray = ../files/ensure-minimize-to-tray.ysh;

  mkYshWrapper =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      # distrobox/podman/notify-send are called by name; oils is invoked by path.
      runtimeInputs = [
        pkgs.distrobox
        pkgs.podman
        pkgs.libnotify
        pkgs.util-linux
      ];
      text = ''
        # Report already-running to the terminal and via notify-send.
        # A still-starting instance is detected by its transient unit
        # (ysh unityhub.ysh), whose output goes to journald.
        if podman exec unity-via-distrobox pgrep -x unityhub-bin >/dev/null 2>&1 \
          || pgrep -f 'unityhub.ysh' >/dev/null 2>&1; then
          echo 'Unity Hub is already running.'
          notify-send -i unityhub 'Unity Hub' 'Unity Hub is already running.' 2>/dev/null || true
          exit 0
        fi
        # Launch through a transient unit so the CLI and the desktop entry
        # share one systemd-managed path; logs land in journald.
        echo 'Starting Unity Hub...'
        exec ${pkgs.systemd}/bin/systemd-run --user --no-block --collect \
          --setenv=UNITY_STOP_ON_EXIT=${if cfg.stopOnExit then "true" else "false"} \
          --setenv=PATH="$PATH" \
          ${pkgs.oils-for-unix}/bin/ysh ${script} "$@"
      '';
    };

  unityhubPkg = mkYshWrapper "unityhub" unityhub;
in
{
  options.my.unity = {
    enable = mkEnableOption "Unity development tools via Distrobox";

    stopOnExit = mkOption {
      type = types.bool;
      default = false;
      description = "Stop the Distrobox container when Unity Hub exits.";
    };

    minimizeToTray = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether Unity Hub minimizes to the system tray when its window is
        closed. When false (default), closing the window quits Unity Hub.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.activation.ensureMinimizeToTray = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.oils-for-unix}/bin/ysh ${minimizeToTray} ${boolToString cfg.minimizeToTray}
    '';

    xdg.configFile."unity-via-distrobox/distrobox.ini".text = distroboxIni;

    # xdg.desktopEntries is broken in this home-manager release, so the file is
    # handwritten. It mirrors the container's official entry; the launcher runs
    # the launch itself via systemd-run, so %U reaches it as an argument.
    xdg.dataFile."applications/unityhub.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Unity Hub
      Comment=The Official Unity Hub
      GenericName=Unity Hub
      Exec=${config.home.profileDirectory}/bin/unityhub %U
      Icon=unityhub
      StartupNotify=true
      Categories=Development;
      MimeType=x-scheme-handler/unityhub;application/x-unityhub;
      Terminal=false
    '';

    home.packages = [ unityhubPkg ];
  };
}
