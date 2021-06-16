{ pkgs
, fullName ? "John Doe"
, organization ? "KVM Authority"
, administratorPassword ? "123456"
, uiLanguage ? "en-US"
, inputLocale ? "en-US"
, userLocale ? "en-US"
, systemLocale ? "en-US"
, users ? {}
, productKey ? null
, defaultUser ? "wfvm"
, setupCommands ? []
, timeZone ? "UTC"
, services ? {}
, impureShellCommands ? []
, driveLetter ? "D:"
, efi ? true
, imageSelection ? "Windows 10 Pro"
, ...
}:

let
  lib = pkgs.lib;
  serviceCommands = lib.mapAttrsToList (
    serviceName: attrs: "powershell Set-Service -Name ${serviceName} " + (
      lib.concatStringsSep " " (
        (
          lib.mapAttrsToList (
            n: v: if builtins.typeOf v != "bool" then "-${n} ${v}" else "-${n}"
          )
        ) (
          # Always run without interaction
          { Force = true; } // attrs
        )
      )
    )
  ) services;

  sshSetupCommands =
    # let
    #   makeDirs = lib.mapAttrsToList (n: v: ''mkdir C:\Users\${n}\.ssh'') users;
    #   writeKeys = lib.flatten (lib.mapAttrsToList (n: v: builtins.map (key: let
    #     commands = [
    #       ''powershell.exe Set-Content -Path C:\Users\${n}\.ssh\authorized_keys -Value '${key}' ''
    #     ];
    #   in lib.concatStringsSep "\n" commands) (v.sshKeys or [])) users);
    #   mkDirsDesc = builtins.map (c: {Path = c; Description = "Make SSH key dir";})  makeDirs;
    #   writeKeysDesc = builtins.map (c: {Path = c; Description = "Add SSH key";})  writeKeys;
    # in
    # mkDirsDesc ++ writeKeysDesc ++
  [
    {
      Path = ''powershell.exe ${driveLetter}\install-ssh.ps1'';
      Description = "Install OpenSSH service.";
    }
  ];

  assertCommand = c: builtins.typeOf c == "string" || builtins.typeOf c == "set" && builtins.hasAttr "Path" c && builtins.hasAttr "Description" c;

  commands = builtins.map (x: assert assertCommand x; if builtins.typeOf x == "string" then { Path = x; Description = x; } else x) (
    [
      {
        Path = "powershell.exe Set-ExecutionPolicy -Force Unrestricted";
        Description = "Allow unsigned powershell scripts.";
      }
    ]
    ++ [
      {
        Path = ''powershell.exe ${driveLetter}\win-bundle-installer.exe'';
        Description = "Install any declared packages.";
      }
    ]
    ++ setupCommands
    ++ [
      {
        Path = ''powershell.exe ${driveLetter}\setup.ps1'';
        Description = "Setup SSH and keys";
      }
    ]
    ++ serviceCommands
    ++ impureShellCommands
  );

  mkCommand = attrs: ''
    <RunSynchronousCommand wcm:action="add">
      ${lib.concatStringsSep "\n" (lib.attrsets.mapAttrsToList (n: v: "<${n}>${v}</${n}>") attrs)}
    </RunSynchronousCommand>
  '';
  mkCommands = commands: (
    builtins.foldl' (
      acc: v: rec {
        i = acc.i + 1;
        values = acc.values ++ [ (mkCommand (v // { Order = builtins.toString i; })) ];
      }
    ) {
      i = 0;
      values = [];
    } commands
  ).values;

  mkUser =
    { name
    , password
    , description ? ""
    , displayName ? ""
    , groups ? []
    # , sshKeys ? []  # Handled in scripts
    }: ''
      <LocalAccount wcm:action="add">
        <Password>
          <Value>${password}</Value>
          <PlainText>true</PlainText>
        </Password>
        <Description>${description}</Description>
        <DisplayName>${displayName}</DisplayName>
        <Group>${builtins.concatStringsSep ";" (lib.unique ([ "Users" ] ++ groups))}</Group>
        <Name>${name}</Name>
      </LocalAccount>
    '';

  # Windows expects a flat list of users while we want to manage them as a set
  flatUsers = builtins.attrValues (builtins.mapAttrs (name: s: s // { inherit name; }) users);

  diskId =
    if efi then 2 else 1;

  autounattendXML = pkgs.writeText "autounattend.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
      <settings pass="windowsPE">
        <component name="Microsoft-Windows-PnpCustomizationsWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <DriverPaths>
            <PathAndCredentials wcm:action="add" wcm:keyValue="1">
              <Path>D:\</Path>
            </PathAndCredentials>
            <PathAndCredentials wcm:action="add" wcm:keyValue="2">
              <Path>E:\</Path>
            </PathAndCredentials>
            <PathAndCredentials wcm:action="add" wcm:keyValue="3">
              <Path>C:\virtio\amd64\w10</Path>
            </PathAndCredentials>
            <PathAndCredentials wcm:action="add" wcm:keyValue="4">
              <Path>C:\virtio\NetKVM\w10\amd64</Path>
            </PathAndCredentials>
            <PathAndCredentials wcm:action="add" wcm:keyValue="5">
              <Path>C:\virtio\qxldod\w10\amd64</Path>
            </PathAndCredentials>
          </DriverPaths>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

          <DiskConfiguration>
            <Disk wcm:action="add">
              <CreatePartitions>
                <CreatePartition wcm:action="add">
                  <Order>1</Order>
                  <Type>${if efi then "EFI" else "Primary"}</Type>
                  <Size>300</Size>
                </CreatePartition>
                <CreatePartition wcm:action="add">
                  <Order>2</Order>
                  <Type>${if efi then "MSR" else "Primary"}</Type>
                  <Size>16</Size>
                </CreatePartition>
                <CreatePartition wcm:action="add">
                  <Order>3</Order>
                  <Type>Primary</Type>
                  <Extend>true</Extend>
                </CreatePartition>
              </CreatePartitions>
              <ModifyPartitions>
                <ModifyPartition wcm:action="add">
                  <Order>1</Order>
                  <Format>${if efi then "FAT32" else "NTFS"}</Format>
                  <Label>System</Label>
                  <PartitionID>1</PartitionID>
                </ModifyPartition>
                <ModifyPartition wcm:action="add">
                  <Order>2</Order>
                  <PartitionID>2</PartitionID>
                </ModifyPartition>
                <ModifyPartition wcm:action="add">
                  <Order>3</Order>
                  <Format>NTFS</Format>
                  <Label>Windows</Label>
                  <Letter>C</Letter>
                  <PartitionID>3</PartitionID>
                </ModifyPartition>
              </ModifyPartitions>
              <DiskID>${toString diskId}</DiskID>
              <WillWipeDisk>true</WillWipeDisk>
            </Disk>
          </DiskConfiguration>

          <ImageInstall>
            <OSImage>
              <InstallTo>
                <DiskID>${toString diskId}</DiskID>
                <PartitionID>3</PartitionID>
              </InstallTo>
              <InstallFrom>
                <MetaData wcm:action="add">
                  <Key>/IMAGE/NAME</Key>
                  <Value>${imageSelection}</Value>
                </MetaData>
              </InstallFrom>
            </OSImage>
          </ImageInstall>

          <UserData>
            <ProductKey>
              ${if productKey != null then "<Key>${productKey}</Key>" else ""}
              <WillShowUI>OnError</WillShowUI>
            </ProductKey>
            <AcceptEula>true</AcceptEula>
            <FullName>${fullName}</FullName>
            <Organization>${organization}</Organization>
          </UserData>

        </component>
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <SetupUILanguage>
            <UILanguage>${uiLanguage}</UILanguage>
          </SetupUILanguage>
          <InputLocale>${inputLocale}</InputLocale>
          <SystemLocale>${systemLocale}</SystemLocale>
          <UILanguage>${uiLanguage}</UILanguage>
          <UILanguageFallback>en-US</UILanguageFallback>
          <UserLocale>${userLocale}</UserLocale>
        </component>
      </settings>

      <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <InputLocale>${inputLocale}</InputLocale>
          <SystemLocale>${systemLocale}</SystemLocale>
          <UILanguage>${uiLanguage}</UILanguage>
          <UILanguageFallback>en-US</UILanguageFallback>
          <UserLocale>${userLocale}</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <OOBE>
            <HideEULAPage>true</HideEULAPage>
            <HideLocalAccountScreen>true</HideLocalAccountScreen>
            <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
            <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            <ProtectYourPC>1</ProtectYourPC>
          </OOBE>
          <TimeZone>${timeZone}</TimeZone>

          <UserAccounts>
            ${if administratorPassword != null then ''
    <AdministratorPassword>
      <Value>${administratorPassword}</Value>
      <PlainText>true</PlainText>
    </AdministratorPassword>
  '' else ""}
            <LocalAccounts>
              ${builtins.concatStringsSep "\n" (builtins.map mkUser flatUsers)}
            </LocalAccounts>
          </UserAccounts>

          ${if defaultUser == null then "" else ''
    <AutoLogon>
      <Password>
        <Value>${(builtins.getAttr defaultUser users).password}</Value>
        <PlainText>true</PlainText>
      </Password>
      <Enabled>true</Enabled>
      <Username>${defaultUser}</Username>
    </AutoLogon>
  ''}

        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <Reseal>
            <ForceShutdownNow>true</ForceShutdownNow>
            <Mode>OOBE</Mode>
          </Reseal>
        </component>
      </settings>

      <settings pass="specialize">
          <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <RunSynchronous>
                ${lib.concatStringsSep "\n" (mkCommands commands)}
              </RunSynchronous>
          </component>
          <component name="Microsoft-Windows-SQMApi" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <CEIPEnabled>0</CEIPEnabled>
          </component>
      </settings>

      <!-- Disable Windows UAC -->
      <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <EnableLUA>false</EnableLUA>
        </component>
      </settings>

       <cpi:offlineImage cpi:source="wim:c:/wim/windows-10/install.wim#${imageSelection}" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
    </unattend>
  '';

in {
  # Lint and format as a sanity check
  autounattendXML = pkgs.runCommandNoCC "autounattend.xml" {} ''
    ${pkgs.libxml2}/bin/xmllint --format ${autounattendXML} > $out
  '';

  # autounattend.xml is _super_ picky about quotes and other things
  setupScript = pkgs.writeText "setup.ps1" (
    ''
      # Setup SSH and keys
    '' +
    lib.concatStrings (
      builtins.map (c: ''
        # ${c.Description}
        ${c.Path}
      '') sshSetupCommands
    )
  );

}
