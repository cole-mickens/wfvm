{ pkgs }:
let
  wfvm = import ../. { inherit pkgs; };
in
{
  anaconda3 = {
    name = "Anaconda3";
    script = let
      Anaconda3 = pkgs.fetchurl {
        name = "Anaconda3.exe";
        url = "https://repo.anaconda.com/archive/Anaconda3-2020.02-Windows-x86_64.exe";
        sha256 = "0n31l8l89jrjrbzbifxbjnr3g320ly9i4zfyqbf3l9blf4ygbhl3";
      };
    in
      ''
      ln -s ${Anaconda3} ./Anaconda3.exe
      win-put Anaconda3.exe .
      echo Running Anaconda installer...
      win-exec 'start /wait "" .\Anaconda3.exe /S /D=%UserProfile%\Anaconda3'
      echo Anaconda installer finished
      '';
  };
  msys2 = {
    name = "MSYS2";
    buildInputs = [ pkgs.expect ];
    script = let
      msys2 = pkgs.fetchurl {
        name = "msys2.exe";
        url = "https://github.com/msys2/msys2-installer/releases/download/2020-06-02/msys2-x86_64-20200602.exe";
        sha256 = "1mswlfybvk42vdr4r85dypgkwhrp5ff47gcbxgjqwq86ym44xzd4";
      };
      msys2-auto-install = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/msys2/msys2-installer/master/auto-install.js";
        sha256 = "0ww48xch2q427c58arg5llakfkfzh3kb32kahwplp0s7jc8224g7";
      };
    in ''
      ln -s ${msys2} ./msys2.exe
      ln -s ${msys2-auto-install} ./auto-install.js
      win-put msys2.exe .
      win-put auto-install.js .
      echo Running MSYS2 installer...
      # work around MSYS2 installer bug that prevents it from closing at the end of unattended install
      expect -c 'set timeout 600; spawn win-exec ".\\msys2.exe --script auto-install.js -v InstallPrefix=C:\\msys64"; expect FinishedPageCallback { close }'
      echo MSYS2 installer finished
    '';
  };
  msys2-packages = msys-packages: {
    name = "MSYS2-packages";
    script = let
      msys-packages-put = pkgs.lib.strings.concatStringsSep "\n"
          (map (package: ''win-put ${package} 'msyspackages' '') msys-packages);
    in
      # Windows command line is so shitty it can't even do glob expansion. Why do people use Windows?
      ''
      win-exec 'mkdir msyspackages'
      ${msys-packages-put}
      cat > installmsyspackages.bat << EOF
      set MSYS=c:\msys64
      set ARCH=64
      set PATH=%MSYS%\usr\bin;%MSYS%\mingw%ARCH%\bin;%PATH%
      bash -c "pacman -U --noconfirm C:/Users/wfvm/msyspackages/*"
      EOF
      win-put installmsyspackages.bat .
      win-exec installmsyspackages
      '';
  };
  msvc = {
    # Those instructions are vaguely correct:
    # https://docs.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio?view=vs-2019
    name = "MSVC";
    script = let
      bootstrapper = pkgs.fetchurl {
        name = "RESTRICTDIST-vs_Community.exe";
        url = "https://download.visualstudio.microsoft.com/download/pr/ac05c4f5-0da1-429f-8701-ce509ac69926/cc9556137c66a373670376d6db2fc5c5c937b2b0bf7b3d3cac11c69e33615511/vs_Community.exe";
        sha256 = "04amc4rrxihimhy3syxzn2r3gjf5qlpxpmkn0dkp78v6gh9md5fc";
      };
      # This touchy-feely "community" piece of trash seems deliberately crafted to break Wine, so we use the VM to run it.
      download-vs = wfvm.utils.wfvm-run {
        name = "download-vs";
        image = wfvm.makeWindowsImage { };
        isolateNetwork = false;
        script =
          ''
          ln -s ${bootstrapper} vs_Community.exe
          ${wfvm.utils.win-put}/bin/win-put vs_Community.exe
          rm vs_Community.exe
          ${wfvm.utils.win-exec}/bin/win-exec "vs_Community.exe --quiet --norestart --layout c:\vslayout --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --lang en-US"
          ${wfvm.utils.win-get}/bin/win-get /c:/vslayout
          '';
      };
      cache = pkgs.stdenv.mkDerivation {
        name = "RESTRICTDIST-vs";

        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = "0fp7a6prjp8n8sirwday13wis3xyzhmrwi377y3x89nxzysp0mnv";

        phases = [ "buildPhase" ];
        buildInputs = [ download-vs ];
        buildPhase =
          ''
          mkdir $out
          cd $out
          wfvm-run-download-vs
          '';
      };
    in
      ''
      ln -s ${cache}/vslayout vslayout
      win-put vslayout /c:/
      echo "Running Visual Studio installer"
      win-exec "cd \vslayout && start /wait vs_Community.exe --passive --wait && echo %errorlevel%"
      '';
  };
  # You need to run the IDE at least once or else most of the Visual Studio trashware won't actually work.
  msvc-ide-unbreak = {
    name = "MSVC-ide-unbreak";
    script =
      ''
      win-exec 'cd "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE" && devenv /ResetSettings'
      sleep 40
      '';
  };
}
