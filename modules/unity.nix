{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.my.unity;
  # Must match the section name in files/distrobox.ini.
  containerName = "unity-via-distrobox";
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
      ];
      text = ''
        exec ${pkgs.oils-for-unix}/bin/ysh ${script} "$@"
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

    xdg.configFile."distrobox/distrobox.ini".text = distroboxIni;

    # xdg.desktopEntries is broken in this home-manager release, so the file is
    # handwritten. It mirrors the container's official entry; Exec goes through
    # systemd-run so the unit owns the process and %U reaches the launcher.
    xdg.dataFile."applications/unityhub.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Unity Hub
      Comment=The Official Unity Hub
      GenericName=Unity Hub
      Exec=systemd-run --user --no-block --collect ${config.home.profileDirectory}/bin/unityhub %U
      Icon=unityhub
      StartupNotify=true
      Categories=Development;
      MimeType=x-scheme-handler/unityhub;application/x-unityhub;
      Terminal=false
    '';

    home.packages = [ unityhubPkg ];

    # State, exclusivity, and lifecycle are managed by systemd:
    #   activating = provisioning (ExecStartPre), active = Unity Hub running,
    #   failed = provisioning/startup error.
    systemd.user.services."unity-via-distrobox" = {
      Unit = {
        Description = "Unity Hub via Distrobox";
      };
      Service = {
        Type = "simple";
        ExecStart = [ "${config.home.profileDirectory}/bin/unityhub" ];
        # stopOnExit=false: terminate Unity Hub (container stays resident)
        # stopOnExit=true : stop the whole container
        ExecStop = [
          (
            if cfg.stopOnExit then
              "-${pkgs.podman}/bin/podman stop ${containerName}"
            else
              "-${pkgs.podman}/bin/podman exec ${containerName} pkill -TERM unityhub"
          )
        ];
        TimeoutStartSec = "1800";
        TimeoutStopSec = "30";
      };
    };
  };
}
