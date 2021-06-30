{ pkgs ? import <nixpkgs> {}, impureMode ? false }:

let
  wfvm = (import ./default.nix { inherit pkgs; });
in
wfvm.makeWindowsImage {
  # Build install script & skip building iso
  inherit impureMode;

  # Custom base iso
  # windowsImage = pkgs.requireFile rec {
  #   name = "Win10_21H1_English_x64.iso";
  #   sha256 = "1sl51lnx4r6ckh5fii7m2hi15zh8fh7cf7rjgjq9kacg8hwyh4b9";
  #   message = "Get ${name} from https://www.microsoft.com/en-us/software-download/windows10ISO";
  # };

  # impureShellCommands = [
  #   "powershell.exe echo Hello"
  # ];

  # User accounts
  # users = {
  #   artiq = {
  #     password = "1234";
  #     # description = "Default user";
  #     # displayName = "Display name";
  #     groups = [
  #       "Administrators"
  #     ];
  #   };
  # };

  # Auto login
  # defaultUser = "artiq";

  # fullName = "M-Labs";
  # organization = "m-labs";
  # administratorPassword = "12345";

  # Imperative installation commands, to be installed incrementally
  installCommands =
    if impureMode
    then []
    else with wfvm.layers; [
      (collapseLayers [
        disable-autosleep
        disable-autolock
        disable-firewall
      ])
      anaconda3 msys2 msvc msvc-ide-unbreak
    ];

  # services = {
  #   # Enable remote management
  #   WinRm = {
  #     Status = "Running";
  #     PassThru = true;
  #   };
  # };

  # License key (required)
  # productKey = throw "Search the f* web"
  imageSelection = "Windows 10 Pro";


  # Locales
  # uiLanguage = "en-US";
  # inputLocale = "en-US";
  # userLocale = "en-US";
  # systemLocale = "en-US";

}
