![XBill](xbill.png)

WFVM
====

A Nix library to create and manage virtual machines running Windows, a medieval operating system found on most computers in 2020. The F stands for "Functional" or a four-letter word of your choice.

* Reproducible - everything runs in the Nix sandbox with no tricks.
* Fully automatic, parameterizable Windows 10 installation.
* Uses QEMU with KVM.
* Supports incremental installation (using "layers") of additional software via QEMU copy-on-write backing chains. For example, ``wfvm.makeWindowsImage { installCommands = [ wfvm.layers.anaconda3 ]; };`` gives you a VM image with Anaconda3 installed, and ``wfvm.makeWindowsImage { installCommands = [ wfvm.layers.anaconda3 wfvm.layers.msys2 ]; };`` gives you one with both Anaconda3 and MSYS2 installed. The base Windows installation and the Anaconda3 data are shared between both images, and only the MSYS2 installation is performed when building the second image after the first one has been built.
* Included layers: Anaconda3, a software installer chock full of bugs that pretends to be a package manager, Visual Studio, a spamming system for Microsoft accounts that includes a compiler, and MSYS2, which is the only sane component in the whole lot.
* Supports running arbitrary commands in a VM image in snapshot mode inside a derivation and retrieving the result.
* Network access from the VM is heavily restricted to avoid issues with Microsoft spyware and similar programs.
* When used with Hydra, redistribution of nonfree content can be blocked.

Example applications:
* Creating reproducible Windows VM images with pre-installed software.
* Compiling Conda packages with Visual Studio in a fully reproducible manner and without having to deal with the constant data corruption caused by Conda.
* Running Windows unit tests on Hydra.


Thanks to Adam Höse from Tweag.io for help with this development.

How to use
==========

Install a Windows image
-----------------------

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


Impure/pure mode
----------------

Sometimes it can be useful to build the image _outside_ of the Nix sandbox for debugging purposes.

For this purpose we have an attribute called `impureMode` which outputs the shell script used by Nix inside the sandbox to build the image.
