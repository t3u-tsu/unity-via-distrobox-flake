{ nixpkgs, home-manager }:

let
  mkConfig =
    {
      stopOnExit ? false,
      minimizeToTray ? false,
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ../modules/unity.nix
        {
          my.unity = {
            enable = true;
            inherit stopOnExit minimizeToTray;
          };
        }
        {
          home = {
            username = "test";
            homeDirectory = "/tmp/unity-test";
            stateVersion = "26.05";
          };
        }
      ];
    };
in
{
  default = mkConfig { };
  stopOnExit = mkConfig { stopOnExit = true; };
  minimizeToTray = mkConfig { minimizeToTray = true; };
}
