{...}: {
  # Tap-Super opens the ambxst launcher.
  #
  # ambxst's own default for this (axctl.toml keybind 0) is Hyprland's
  # `bindr SUPER, Super_L` — fire on *release* of the bare modifier. niri has no
  # release binds, so axctl skips that bind outright (see the "Skipped binds"
  # note it writes into ~/.local/share/ambxst/niri.kdl), and binding `Super_L`
  # in niri directly is not a substitute: niri fires on press, so every
  # Mod+<key> combo would pop the launcher first.
  #
  # keyd solves it below libinput instead: hold leftmeta = Super as usual, tap
  # it = KEY_F13, which nothing else in this config uses. xkb gives that keycode
  # the keysym XF86Tools (F13..F24 are XF86Tools/XF86Launch5.. on Linux), and
  # niri binds match on keysym, so the bind that fires is named XF86Tools. It
  # lives in modules/wrappers/niri.nix; keyd suppresses the Super it replaces,
  # so niri sees that key alone, with no modifier held.
  #
  # overload_tap_timeout drops the tap behaviour once the key is held past
  # 500ms, so Super-hold gestures that keyd cannot see (Mod+click to move a
  # window, Mod+scroll) do not spit out an F13 on release. It is not
  # overloadt(): that one queues overlapping keys until the timeout, which adds
  # a visible delay to every Super+key combo.
  flake.nixosModules.keyd = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = ["*"];
        settings = {
          # Raise this if a slow tap stops registering; lower it if a Super-drag
          # leaves the launcher open. Hyprland's bindr had no timeout at all.
          global.overload_tap_timeout = 500;
          main.leftmeta = "overload(meta, f13)";
        };
      };
    };
  };
}
