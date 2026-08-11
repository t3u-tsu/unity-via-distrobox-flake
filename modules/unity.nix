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
  launcher = builtins.readFile ../files/launcher.sh;
  distroboxIni = builtins.readFile ../files/distrobox.ini;
in
{
  options.my.unity.enable = mkEnableOption "Unity development tools via Distrobox";

  config = mkIf cfg.enable {
    xdg.configFile."distrobox/distrobox.ini".text = distroboxIni;

    # xdg.desktopEntries is broken in the current home-manager release.
    # systemd-run --user escapes browser sandboxes for unityhub:// deep links.
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

    home.packages = [
      (pkgs.writeShellApplication {
        name = "unityhub";
        runtimeInputs = [
          pkgs.distrobox
          pkgs.podman
        ];
        text = ''
          CONTAINER_NAME="${containerName}"
          ${launcher}
        '';
      })
    ];
  };
}
