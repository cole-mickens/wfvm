{ pkgs }:

{
  makeWindowsImage = attrs: import ./win.nix ({ inherit pkgs; } // attrs);
  layers = (import ./layers { inherit pkgs; });
  utils = (import ./utils.nix { inherit pkgs; });
}
