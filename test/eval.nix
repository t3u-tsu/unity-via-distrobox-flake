{ nixpkgs, home-manager }:

home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    ../modules/unity.nix
    { my.unity.enable = true; }
    {
      home = {
        username = "test";
        homeDirectory = "/tmp/unity-test";
        stateVersion = "26.05";
      };
    }
  ];
}
