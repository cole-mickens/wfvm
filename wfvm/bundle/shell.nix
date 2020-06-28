{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {

  buildInputs = [
    pkgs.go
  ];

  shellHook = ''
    unset GOPATH
  '';

}
