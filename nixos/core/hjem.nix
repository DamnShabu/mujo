{inputs, ...}: {
  flake.nixosModules.hjem = {
    config,
    pkgs,
    ...
  }: let
    user = config.preferences.user.name;
    gitName = config.preferences.git.userName;
    gitEmail = config.preferences.git.userEmail;

    gitconfig = pkgs.writeText "gitconfig" ''
      [user]
        name = ${gitName}
        email = ${gitEmail}

      [init]
        defaultBranch = main

      [pull]
        rebase = true

      [push]
        autoSetupRemote = true

      [rebase]
        autoStash = true

      [merge]
        conflictstyle = zdiff3

      [diff]
        algorithm = histogram
        colorMoved = plain
        mnemonicPrefix = true
        renames = true

      [fetch]
        prune = true
        pruneTags = true
        all = true

      [core]
        autocrlf = input

      [safe]
        directory = *

      [include]
        path = ~/.gitconfig.local
    '';
  in {
    imports = [
      inputs.hjem.nixosModules.default
    ];

    config = {
      persistence.data.files = [
        ".gitconfig.local"
      ];

      hjem = {
        users."${user}" = {
          enable = true;
          directory = "/home/${user}";
          user = "${user}";

          files = {
            ".gitconfig".source = gitconfig;
          };
        };

        clobberByDefault = true;
      };
    };
  };
}
