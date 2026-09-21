{inputs, ...}: {
  flake.nixosModules.skwd-wall = {pkgs, ...}: {
    imports = [
      inputs.skwd-wall.nixosModules.default
    ];

    services.skwd-deck.enable = true;

    # Convenience wrapper: 'skwd-wall' invokes 'skwd-wall-v2'
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "skwd-wall" ''
        exec skwd-wall-v2 "$@"
      '')
    ];

    persistence.data.directories = [
      ".config/skwd"
      ".local/share/skwd"
      ".local/state/skwd"
    ];
  };
}
