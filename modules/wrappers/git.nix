{
  flake.wrappers.git = {
    wlib,
    lib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.git;
  };
}
