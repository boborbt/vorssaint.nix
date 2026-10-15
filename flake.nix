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
      systems = [ "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      overlays.default = final: _prev: {
        vorssaint = final.callPackage ./package.nix { };
      };
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      inherit overlays;
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) vorssaint;
          default = pkgs.vorssaint;
        });
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      homeManagerModules = {
        vorssaint = import ./modules/home-manager.nix;
        default = self.homeManagerModules.vorssaint;
      };
      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
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
        });
    };
}
