# Contributing

Issues and pull requests are welcome. Keep changes focused and test on
`aarch64-darwin` with macOS 14 or newer.

Before opening a pull request:

- run `nix flake check`;
- verify the upstream app bundle signature when changing `package.nix`;
- update the user-facing README when changing module options or installation
  behavior;
- do not commit `result/`, private preference exports, or credentials.

## Publishing the flake

Create a public GitHub repository, push the main branch, and create a semantic
version tag such as `v0.1.0`. Commit `flake.nix`, `flake.lock`, `package.nix`,
`modules/`, `README.md`, `LICENSE`, and this file. Do not commit `result/`.

## Upstream contributions

Home Manager is not a package catalog. Packages consumed by `home.packages`
come from Nixpkgs; the Home Manager repository contains `programs.*` modules.
A complete upstream integration therefore requires two separate contributions:

- propose `vorssaint` to [Nixpkgs](https://github.com/NixOS/nixpkgs), following
  `doc/development/package-notes.md`, with the binary derivation, platform
  metadata, and upstream signature verification;
- propose `modules/home-manager.nix` to
  [Home Manager](https://github.com/nix-community/home-manager), moving it to
  `modules/programs/vorssaint.nix`, using `pkgs.vorssaint` as its default,
  adding a module test, and adding a news entry.

Follow the current contribution guides of both projects before opening the
pull requests. Until those changes are accepted, this flake's overlay provides
the package and `homeManagerModules.default` provides the module.
