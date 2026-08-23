{ config, lib, pkgs, ... }:

let
  # Read all files in the overrides directory
  overrideDir = ../overrides;
  dirContents = builtins.readDir overrideDir;
  
  # Filter for .nix files that are not default.nix (if it exists)
  overrideFiles = builtins.filter
    (name: lib.hasSuffix ".nix" name && name != "default.nix")
    (builtins.attrNames dirContents);
    
  # Map them to absolute paths
  importsList = map (name: overrideDir + "/${name}") overrideFiles;
in
{
  flake.nixosModules.ui-overrides = {
    imports = importsList;
  };
}
