{ pkgs }:

pkgs.runCommandNoCC "win-bundle-installer.exe" {} ''
  cp ${./main.go} main.go
  env HOME=$(mktemp -d) GOOS=windows GOARCH=amd64 ${pkgs.go}/bin/go build
  mv build.exe $out
''
