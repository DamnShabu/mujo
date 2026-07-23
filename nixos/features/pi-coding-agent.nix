{inputs, ...}: {
  flake.nixosModules.pi-coding-agent = {
    pkgs,
    config,
    ...
  }: let
    user = config.preferences.user.name;
  in {
    imports = [
      inputs.pi-flake.nixosModules.default
    ];

    services.pi-coding-agent = {
      enable = true;
      users = [user];
      mutableDir = true;
      extensions = [
        "npm:pi-free"
      ];
    };
  };
}
