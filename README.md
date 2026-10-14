# Vorssaint for Nix / Home Manager

Packages the signed upstream **Vorssaint 3.4.1** release and provides a Home Manager
module for native macOS preferences. Requires **Apple Silicon and macOS 14+**.
Intel Macs and Linux are not supported by this release.

## Build the application

```sh
nix build .#vorssaint
```

The bundle is at `result/Applications/Vorssaint.app`. Building does not install or
launch the application. The release DMG is pinned by version and SHA-256;
`flake.lock` pins Nixpkgs and Home Manager.

## Use with Home Manager

Add this repository to your existing configuration flake's inputs. Until you
publish it, use its absolute local path:

```nix
inputs.vorssaint = {
  url = "path:/absolute/path/to/vorssaint.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Include the module in your Home Manager `modules` list (or `imports` when `inputs`
is available through `extraSpecialArgs`):

```nix
inputs.vorssaint.homeManagerModules.default
```

Then configure your home:

```nix
{
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
```

Quit Vorssaint, run your usual `home-manager switch --flake ...`, then open it
from `~/Applications/Home Manager Apps`. Do not run a second Homebrew or manually
installed copy alongside it.

The module uses Home Manager's own application installation mechanism. With
`home.stateVersion >= "25.11"`, current Home Manager copies app bundles by default,
which supports Spotlight. For an older state version, you can explicitly opt in
without changing your state version:

```nix
{
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;
}
```

These options affect all Home Manager applications, not just Vorssaint. macOS may
ask you to grant your terminal App Management permission during activation.

## Module options

| Option | Default | Purpose |
| --- | --- | --- |
| `programs.vorssaint.enable` | `false` | Install the app and apply preferences. |
| `programs.vorssaint.package` | This repository's package | Override the app derivation. |
| `programs.vorssaint.settings` | `{ }` | Manage native preference keys. |

When enabled, the module adds `autoCheckUpdates = false` at default priority.
You can override it in `settings`, but updating through Nix is recommended. Do
not use the in-app updater on a Nix-managed installation: it cannot update the
store bundle, and changes to a Home Manager copy can be overwritten on activation.

Preferences are applied through `targets.darwin.defaults."com.vorssaint.utils"`:

- Values support booleans, integers, floats, strings, lists, and dictionaries.
  `null`, Nix paths, and functions are not supported preference values.
- Only configured keys are overwritten. Unspecified keys are preserved.
- Removing a key, or disabling the module, does **not** delete stored preferences.
- Managed keys are reapplied on each switch; changes made in the app between
  switches remain possible.
- Quit the app before switching so its in-memory preferences cannot compete with
  activation. Reopen it afterward; the module does not quit or launch it for you.
- The module does not register a login item or grant macOS permissions. Configure
  startup in the app if desired. Accessibility, Screen Recording, and other
  permissions remain interactive macOS decisions.
- Settings enter the readable Nix store. Never include credentials or private
  snippets. This is preference management, not a backup of app databases or files.

Use the exact native keys and value encodings from the pinned upstream
[`Defaults.swift`](https://github.com/vorssaint/vorssaint-utils/blob/v3.4.1/Sources/Vorssaint/Core/Defaults.swift).
Some settings use encoded strings rather than native lists or dictionaries;
follow the upstream representation. The module validates property-list types,
not every feature's allowed values or dependencies.

To inspect your existing preferences, quit the app and export them:

```sh
defaults export com.vorssaint.utils ~/Desktop/vorssaint-preferences.plist
plutil -convert json -o ~/Desktop/vorssaint-preferences.json ~/Desktop/vorssaint-preferences.plist
```

Review and sanitize exports before sharing or committing them. Prefer selecting
intentional user preferences rather than importing the entire domain, which also
contains onboarding state, machine-specific paths, and runtime recovery flags.
The app's own settings export may use a different envelope; it is not consumed
automatically by this module.

## Verification

```sh
nix flake check
```

On `aarch64-darwin`, this builds both the app package and a representative Home
Manager activation package; it does not activate a home configuration.

Development smoke verification also exercised the generated application-copy
step in a temporary directory, verified the copied bundle with
`codesign --verify --deep --strict`, and executed the generated defaults import
against a disposable domain. Typed values, preservation of an unmanaged key,
and repeat activation were verified without modifying the real app domain.
The app GUI and macOS permission prompts have not been exercised.

## Updating

Update `version`, the DMG URL if its naming changes, and `src.hash` in
`package.nix` together. Obtain the checksum from the upstream release and verify
it by building. `nix flake update` updates dependencies, not the app version.
After an app update, recheck preference keys, build with `nix flake check`, and
verify the installed bundle's signature. Quit the old app before switching to
the new generation.

Upstream: [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils)
(GPL-3.0-or-later).
