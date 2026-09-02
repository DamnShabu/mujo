{...}: {
  flake.nixosModules.security-users = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    config = lib.mkIf (cfg.enable && cfg.users.enable) {
      security.sudo = {
        enable = lib.mkDefault true;
        # Restrict execution of sudo binary to members of the wheel group only
        execWheelOnly = lib.mkDefault true;
        # Enforce password timestamp timeout to 5 minutes.
        #
        # log_input/log_output is deliberately absent. It transcribes every sudo
        # session to /var/log/sudo-io, which impermanence persists, so any
        # password typed at a nested prompt, any token pasted into an editor and
        # any vault content read under sudo would land in plaintext on
        # unencrypted disk -- the exact leak docs/privacy-model.md forbids.
        extraConfig = ''
          Defaults timestamp_timeout=5
          Defaults passwd_tries=3
        '';
      };

      # Set restrictive default umask for newly created user files
      environment.extraInit = ''
        umask 027
      '';
    };
  };
}
