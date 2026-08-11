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

  mkYshWrapper =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.distrobox
        pkgs.podman
        pkgs.oils-for-unix
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
  };

  config = mkIf cfg.enable {
    xdg.configFile."distrobox/distrobox.ini".text = distroboxIni;

    # xdg.desktopEntries is broken in the current home-manager release.
    # systemd-run escapes browser sandboxes; %U forwards unityhub:// deep links.
    xdg.dataFile."applications/unityhub.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Unity Hub
      GenericName=Unity Hub Launcher
      Exec=systemd-run --user --no-block --collect ${config.home.profileDirectory}/bin/unityhub %U
      Icon=unityhub
      MimeType=x-scheme-handler/unityhub;
      Categories=Development;
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
