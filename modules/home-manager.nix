{ config, lib, pkgs, ... }:

let
cfg = config.programs.vorssaint;
isPlistData = value:
  builtins.isAttrs value
  && (value._type or null) == "plist-data";

dataSettings = lib.filterAttrs
  (_: value: isPlistData value)
  cfg.settings;

normalSettings = lib.filterAttrs
  (_: value: !(isPlistData value))
  cfg.settings;

dataPreferenceCommands = lib.mapAttrsToList (name: value: ''
  hex="$(printf '%s' ${lib.escapeShellArg value.base64} \
    | /usr/bin/base64 -D \
    | /usr/bin/od -An -v -tx1 \
    | /usr/bin/tr -d '[:space:]')"
  /usr/bin/defaults write com.vorssaint.utils \
    ${lib.escapeShellArg name} -data "$hex"
'') dataSettings;
plistValue = (with lib.types; oneOf [
    bool
    int
    float
    str
    (listOf plistValue)
    (attrsOf plistValue)
]) // {
# A finite description also lets invalid recursive values report an error.
description = "property-list value (boolean, integer, float, string, list, or dictionary)";
};
in
{
  options.programs.vorssaint = {
    enable = lib.mkEnableOption "Vorssaint, the macOS menu bar toolkit";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../package.nix { };
      defaultText = lib.literalExpression "the Vorssaint package provided by this flake";
      description = "Vorssaint application package to install.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf plistValue;
      default = { };
      example = {
        appAppearance = "dark";
        showCountdownInMenuBar = true;
        defaultDurationMinutes = 30;
      };
      description = ''
        Native preferences in the com.vorssaint.utils domain. Supports booleans,
               integers, floats, strings, lists, and dictionaries. Only specified keys
                 are managed; other preferences are preserved. Removing a key stops
                 managing it but does not delete its stored value. Quit Vorssaint before
                 switching and reopen it afterward to load the new preferences.
                 Values are stored in the public Nix store; do not include secrets.
                 '';
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
      message = "programs.vorssaint requires Apple Silicon macOS (aarch64-darwin).";
    }
    ];

    home.packages = [ cfg.package ];

    programs.vorssaint.settings.autoCheckUpdates = lib.mkDefault false;
    targets.darwin.defaults."com.vorssaint.utils" = normalSettings;

    home.activation.launchVorssaint =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      app="${cfg.package}/Applications/Vorssaint.app"

      echo "Vorssaint activation: checking $app"

      if [ ! -d "$app" ]; then
        echo "Vorssaint activation: app bundle not found" >&2
          exit 1
          fi

          echo "Vorssaint activation: invoking open"
          ${lib.concatStringsSep "\n" dataPreferenceCommands}
          /usr/bin/open "$app"
          echo "Vorssaint activation: open returned $?"
          '';
  };
}
