{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.services.unity-via-distrobox;
in
{
  options.services.unity-via-distrobox.enable = mkEnableOption "Unity development tools via Distrobox (system dependencies)";

  config = mkIf cfg.enable {
    # nixpkgs 26.05 still uses the virtualisation.podman namespace.
    virtualisation.podman.enable = true;
    # Rootless podman needs FUSE for container mounts.
    programs.fuse.userAllowOther = true;
    environment.systemPackages = with pkgs; [
      distrobox
      podman
    ];
  };
}
