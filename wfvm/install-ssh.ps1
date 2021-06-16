Write-Host "Expanding OpenSSH"
Expand-Archive D:\OpenSSH-Win64.zip C:\

Push-Location C:\OpenSSH-Win64

Write-Host "Installing OpenSSH"
& .\install-sshd.ps1

Write-Host "Generating host keys"
.\ssh-keygen.exe -A

Write-Host "Fixing host file permissions"
& .\FixHostFilePermissions.ps1 -Confirm:$false

Write-Host "Fixing user file permissions"
& .\FixUserFilePermissions.ps1 -Confirm:$false

Pop-Location

$newPath = 'C:\OpenSSH-Win64;' + [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)

#Write-Host "Adding public key to authorized_keys"
#$keyPath = "~\.ssh\authorized_keys"
#New-Item -Type Directory ~\.ssh > $null
#$sshKey | Out-File $keyPath -Encoding Ascii

Write-Host "Opening firewall port 22"
New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH

Write-Host "Setting sshd service startup type to 'Automatic'"
Set-Service sshd -StartupType Automatic
Set-Service ssh-agent -StartupType Automatic
Write-Host "Setting sshd service restart behavior"
sc.exe failure sshd reset= 86400 actions= restart/500

#Write-Host "Configuring sshd"
#(Get-Content C:\ProgramData\ssh\sshd_config).replace('#TCPKeepAlive yes', 'TCPKeepAlive yes').replace('#ClientAliveInterval 0', 'ClientAliveInterval 300').replace('#ClientAliveCountMax 3', 'ClientAliveCountMax 3') | Set-Content C:\ProgramData\ssh\sshd_config

Write-Host "Starting sshd service"
Start-Service sshd
Start-Service ssh-agent
