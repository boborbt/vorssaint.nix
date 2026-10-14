{
  description = "Vorssaint for macOS, packaged and configured with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = {
        vorssaint = pkgs.callPackage ./package.nix { };
        default = self.packages.${system}.vorssaint;
      };

      homeManagerModules = {
        vorssaint = import ./modules/home-manager.nix;
        default = self.homeManagerModules.vorssaint;
      };

      checks.${system} = {
        package = self.packages.${system}.vorssaint;
        home-manager = (home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.default
            {
              home.username = "vorssaint-check";
              home.homeDirectory = "/Users/vorssaint-check";
              home.stateVersion = "26.05";
              programs.vorssaint = {
                enable = true;
                settings = {
                  appAppearance = "dark";
                  showCountdownInMenuBar = true;
                  defaultDurationMinutes = 30;
                  smoothScrollExceptions = [ "com.apple.Terminal" ];
                };
              };
            }
          ];
        }).activationPackage;
      };
    };
}
