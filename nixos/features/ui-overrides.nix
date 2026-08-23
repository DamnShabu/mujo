{lib, ...}: let
  overrideDir = ../overrides;
  entries = builtins.readDir overrideDir;

  # enabled overrides = *.nix, minus the committed template. Disabled ones are
  # *.disabled and simply don't match, so the loader skips them.
  names =
    builtins.filter
    (n: lib.hasSuffix ".nix" n && n != "template.nix" && n != "default.nix")
    (builtins.attrNames entries);

  # tryEval catches parse errors at import so one broken drop-in reports instead
  # of failing the whole rebuild.
  # ponytail: only parse-time errors are isolated; a file that parses but sets a
  # bad NixOS option still fails the build (disable it to recover). Full per-file
  # isolation would need a throwaway nixosSystem per override — not worth it.
  tried =
    map (n: {
      inherit n;
      path = overrideDir + "/${n}";
      r = builtins.tryEval (import (overrideDir + "/${n}"));
    })
    names;

  ok = builtins.filter (t: t.r.success) tried;
  bad = builtins.filter (t: !t.r.success) tried;
in {
  flake.nixosModules.ui-overrides = {
    imports = map (t: t.path) ok;

    config.preferences.overrides.report =
      builtins.listToAttrs
      (map (t: {
          name = t.n;
          value = "failed to import (parse error)";
        })
        bad);
  };
}
