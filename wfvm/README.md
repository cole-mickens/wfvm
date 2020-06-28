# Preparation steps

## Install a Windows image

1. Adjust demo-image.nix accordingly
2. Run:

If in impure mode
```shell
nix-build demo-image.nix
./result
```
Results in a file called c.img

If in pure mode
```shell
nix-build demo-image.nix
ls -la ./result
```
Results in a symlink to the image in the nix store


# Impure/pure mode
Sometimes it can be useful to build the image _outside_ of the Nix sandbox for debugging purposes.

For this purpose we have an attribute called `impureMode` which outputs the shell script used by Nix inside the sandbox to build the image.
