# Evaluate the home-manager module in both supported configurations.
# Used by `nix flake check` (see flake.nix checks) to prove the module
# evaluates cleanly and produces a valid home environment.
{ nixpkgs, home-manager }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  eval =
    useDistrobox:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../modules/unity.nix
        {
          my.unity = {
            enable = true;
            inherit useDistrobox;
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
  distrobox = eval true;
  native = eval false;
}
