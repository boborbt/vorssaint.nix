# Vorssaint for Nix / Home Manager

Install and configure [Vorssaint](https://github.com/vorssaint/vorssaint-utils) on Apple Silicon Macs using Nix and Home Manager.

## Requirements

- Apple Silicon (`aarch64-darwin`);
- macOS 14 or newer;
- Nix flakes;
- Home Manager.

The packaged release does not support Intel Macs or Linux.

## Installation

Add the flake to the inputs of your Home Manager configuration:

```nix
inputs.vorssaint = {
  url = "github:boborbt/vorssaint.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

This flake provides both the package overlay and the Home Manager module, so
you do not need a separate package from Nixpkgs or a separate module from Home
Manager.

Add the package overlay and the Home Manager module:

```nix
{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.vorssaint.overlays.default ];

  imports = [
    inputs.vorssaint.homeManagerModules.default
  ];
}
```

If your Home Manager configuration receives its inputs through
`extraSpecialArgs`, use that argument instead of `inputs`.

Enable Vorssaint in your Home Manager configuration:

```nix
{
  programs.vorssaint = {
    enable = true;

    launchOnActivation = true;

    settings = {
      appAppearance = "dark";
      showCountdownInMenuBar = true;
      defaultDurationMinutes = 30;
      smoothScrollExceptions = [ "com.apple.Terminal" ];
    };
  };
}
```

Apply the configuration:

```sh
home-manager switch --flake .#<home>
```

Open Vorssaint from `~/Applications/Home Manager Apps`. Do not run a second
Homebrew or manually installed copy alongside the copy managed by Home Manager.

## Launch behavior

By default, the module does not launch the app during activation. To launch
Vorssaint after every successful Home Manager activation, opt in:

```nix
programs.vorssaint.launchOnActivation = true;
```

This runs macOS `open`, requires a graphical session, and is separate from
login-item configuration.

## Application installation on macOS

Home Manager installs the bundle through its Darwin application mechanism. With
`home.stateVersion >= "25.11"`, current Home Manager versions copy application
bundles by default, which supports Spotlight.

For older state versions, opt in explicitly:
```nix
{
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;
}
```

These options affect every Home Manager application, not just Vorssaint. macOS
may ask you to grant your terminal App Management permission during activation.

## Options

| Option | Default | Description |
| --- | --- | --- |
| `programs.vorssaint.enable` | `false` | Install Vorssaint and manage its preferences. |
| `programs.vorssaint.package` | `pkgs.vorssaint` | Override the application package. |
| `programs.vorssaint.launchOnActivation` | `false` | Run `open` after activation. |
| `programs.vorssaint.settings` | `{ }` | Native preferences for the app. |

When enabled, the module sets `autoCheckUpdates = false` unless you override it
in `settings`. Do not use the in-app updater for a Nix-managed installation: it
cannot modify the Nix store bundle and may be overwritten by the next activation.

## Preferences

Preferences are written to
`targets.darwin.defaults."com.vorssaint.utils"`.

- Supported values are booleans, integers, floats, strings, lists, and
  dictionaries.
- `null`, Nix paths, and functions are not supported.
- Only configured keys are overwritten; other keys are preserved.
- Removing a key or disabling the module does not delete the stored value.
- Managed keys are reapplied on each switch.
- Quit Vorssaint before switching and reopen it afterward if
  `launchOnActivation` is disabled.
- Settings are readable in the Nix store. Do not put credentials or private
  data in `settings`.

Use the exact native keys and encodings from the pinned upstream [`Defaults.swift`](https://github.com/vorssaint/vorssaint-utils/blob/v3.4.1/Sources/Vorssaint/Core/Defaults.swift).

Some upstream settings use encoded strings instead of native lists or dictionaries. The module validates property-list types, but not every feature-specific value or dependency.

### `notchQuickAccessLayout`

`notchQuickAccessLayout` is stored by Vorssaint as JSON-encoded data in a property-list `Data` value. In Home Manager, represent it with `_type = "plist-data"` and provide the JSON as base64:

```nix
programs.vorssaint.settings.notchQuickAccessLayout = {
  _type = "plist-data";
  base64 = "eyJidXR0b25zIjpbeyJhY3Rpb25JRCI6InRpbWVyIiwiaWQiOiIwMDAwMDAwMC0wMDAwLTQwMDAtODAwMC0wMDAwMDAwMDAwMDEiLCJsYWJlbCI6IiIsInNpZGUiOiJsZWZ0In1dLCJ2ZXJzaW9uIjoxfQ==";
};
```
To obtain the base64-encoded value, configure the desired layout in the app and export its settings from the Advanced tab. The generated plist contains the base64 value under `notchQuickAccessLayout`.

### Available settings

To inspect the current preferences:

```sh
defaults read com.vorssaint.utils
```

You can use any key shown in the output in your `settings` configuration.

## Building without Home Manager

Build the application bundle directly:

```sh
nix build github:boborbt/vorssaint.nix#vorssaint
```

The bundle is available at `result/Applications/Vorssaint.app`. Building does not install or launch it.
## Updating the package

To check the pinned package against the latest stable Vorssaint release and
update it when needed:

```sh
./scripts/update-vorssaint.sh
```

The script reads the release asset and its SHA-256 digest from GitHub, updates
`package.nix`, and keeps the upstream `Defaults.swift` link in this README
versioned with the package. Use `--check` to verify alignment without changing
files. The package and README must not contain local Git changes when an
update is required.


## License

This repository is GPL-3.0-or-later. The packaged application is upstream software maintained by [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils).
