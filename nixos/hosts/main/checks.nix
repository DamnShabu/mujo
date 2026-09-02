# `nix flake check` walks flake outputs it recognises. nixosConfigurations is
# not one of them, so for as long as this file did not exist the host
# configuration was never evaluated by CI at all — it had in fact stopped
# evaluating (a sysctl collision in nixos/security/privacy.nix) without any
# check going red. Exposing the toplevel as a check closes that hole: an option
# conflict, a failed assertion or a broken module now fails `nix flake check`.
{
  self,
  lib,
  ...
}: {
  perSystem = {system, ...}: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      hostMain = self.nixosConfigurations.main.config.system.build.toplevel;
    };
  };
}
