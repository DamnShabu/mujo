{...}: {
  flake.nixosModules.security-audit = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.security.mujo;
  in {
    config = lib.mkIf (cfg.enable && cfg.audit.enable) {
      security.audit = {
        enable = lib.mkDefault true;
        rules = [
          # Monitor changes to authentication configuration
          "-w /etc/pam.d/ -p wa -k pam_changes"
          "-w /etc/shadow -p wa -k shadow_changes"
          "-w /etc/passwd -p wa -k passwd_changes"
          # Monitor sudoers configuration
          "-w /etc/sudoers -p wa -k sudoers_changes"
        ];
      };

      # Auditd service for event logging
      security.auditd.enable = lib.mkDefault true;

      # Vulnerability scanner and curated false-positive / build-time artifact whitelist
      environment.systemPackages = [
        pkgs.vulnix
        pkgs.lynis
      ];

      environment.etc."mujo/vulnix-whitelist.toml".source = ./vulnix-whitelist.toml;
      environment.etc."lynis/mujo.prf".source = ./lynis-mujo.prf;
    };
  };
}
