{ pkgs }:

pkgs.runCommandNoCC "win-bundle-installer.exe" {} ''
  mkdir bundle
  cd bundle
  cp ${./go.mod} go.mod
  cp ${./main.go} main.go
  env HOME=$(mktemp -d) GOOS=windows GOARCH=amd64 ${pkgs.go}/bin/go build
  mv bundle.exe $out
''
