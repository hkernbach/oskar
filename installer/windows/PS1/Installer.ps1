﻿function UpdatePath
{
    $env:Path = [System.Environment]::ExpandEnvironmentVariables([System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User"))
}

function ExternalProcess($process,$arguments,$wait)
{
    if($wait -eq $false)
    {
        UpdatePath
        Start-Process $process -Verb runAs -ArgumentList $arguments
    }
    if($wait -eq $true)
    {
        UpdatePath
        Start-Process $process -Verb runAs -ArgumentList $arguments -PassThru | Wait-Process
    }
}

function Disable-InternetExplorerESC 
{
    If (Test-Path -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}')
    {
        If (-Not ((Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name "IsInstalled") -eq 0))
        {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Force
        }
    }
    If (Test-Path -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{AA509B1A8-37EF-4b3f-8CFC-4F3A74704073}')
    {
        If (-Not ((Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -Name "IsInstalled") -eq 0))
        {
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Force
        }
    }
    Stop-Process -Name Explorer -Force
}

function DownloadFile($src,$dest)
{
    Disable-InternetExplorerESC
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    (New-Object System.Net.WebClient).DownloadFile($src,$dest)
}


If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    ExternalProcess -process Powershell -arguments $arguments -wait $false
    Break
}

If (-Not ((Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled') -eq 1))
{
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value '1'
}

If (-NOT((Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\PathSet' -Name '(default)' -ErrorAction SilentlyContinue ) -eq 1))
{
    $oldpath = (Get-ItemProperty -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ -Name PATH).path
    $newpath = “$oldpath;%ALLUSERSPROFILE%\chocolatey\bin;C:\tools\DevKit2\bin;C:\tools\DevKit2\mingw\bin;%PROGRAMFILES(x86)%\Windows Kits\10\Debuggers\x64”
    Set-ItemProperty -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ -Name PATH -Value $newPath

    If(Get-ItemPropertyValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\PathSet' -Name '(default)' -ErrorAction SilentlyContinue)
    {
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\PathSet' -Name '(default)' -Value '1'
    }
    Else
    {
        New-Item -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows' -Name "PathSet" -Value "1"
    }
}


DownloadFile -src 'https://github.com/Microsoft/vssetup.powershell/releases/download/2.0.1/VSSetup.zip' -dest "C:\Windows\Temp\VSSetup.zip"
Expand-Archive -Force "C:\Windows\Temp\VSSetup.zip" "$env:ProgramFiles\WindowsPowerShell\Modules\VSSetup"
Expand-Archive -Force "C:\Windows\Temp\VSSetup.zip" "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules\VSSetup"
Remove-Item "C:\Windows\Temp\VSSetup.zip"
UpdatePath
Import-Module VSSetup

$arguments = @'
-NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
'@
ExternalProcess -process Powershell -arguments $arguments -wait $true

$arguments = @("choco install -y dotnet4.7.1 vcredist-all cmake.portable nsis python2 procdump windbg wget nuget.commandline vim notepadplusplus putty.install openssh","choco install -y git winflexbison3 ruby","choco install -y ruby2.devkit nodejs jdk8","gem install bundler persistent_httparty rspec rspec-core","npm install -g gitbook-cli","pip3.5 install git+https://github.com/frerich/clcache.git")
ForEach($argument in $arguments)
{
    ExternalProcess -process Powershell -arguments $argument -wait $true
}

DownloadFile -src 'https://aka.ms/vs/15/release/vs_community.exe' -dest "C:\Windows\Temp\vs_community.exe"
$arguments = "--add Microsoft.VisualStudio.Workload.Node --add Microsoft.VisualStudio.Workload.NativeCrossPlat --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --includeOptional --quiet"
ExternalProcess -process "C:\Windows\Temp\vs_community.exe" -arguments $arguments -wait $true
Remove-Item "C:\Windows\Temp\vs_community.exe"

DownloadFile -src 'https://www.npcglib.org/~stathis/downloads/openssl-1.1.0f-vs2017.7z' -dest "C:\Windows\Temp\openssl-1.1.0f-vs2017.7z"
ExternalProcess -process 7za -arguments "x C:\Windows\Temp\openssl-1.1.0f-vs2017.7z -oC:\" -wait $true
Rename-Item "C:\openssl-1.1.0f-vs2017" "C:\OpenSSL-Win64"
#[Environment]::SetEnvironmentVariable("OPENSSLDIR", "C:\OpenSSL-Win64", "Machine")
Remove-Item "C:\Windows\Temp\openssl-1.1.0f-vs2017.7z"

$clpath = $(Split-Path -Parent $(Get-ChildItem $(Get-VSSetupInstance).InstallationPath -Filter cl.exe -Recurse | Select-Object Fullname |Where {$_.FullName -match "Hostx64\\x64"}).FullName) 
DownloadFile -src 'https://github.com/frerich/clcache/releases/download/v4.1.0/clcache-4.1.0.zip' -dest "C:\Windows\Temp\clcache-4.1.0.zip"
DownloadFile -src 'https://github.com/arangodb-helper/clcheat/raw/master/clcheat.exe' -dest $clpath
Expand-Archive -Force "C:\Windows\Temp\clcache-4.1.0.zip" "$clpath"
Rename-Item -Path "$clpath\cl.exe" -NewName "clo.exe"
Rename-Item -Path "$clpath\cl.exe.config" -NewName "clo.exe.config"
Rename-Item -Path "$clpath\clcheat.exe" -NewName "cl.exe"
[Environment]::SetEnvironmentVariable("CLCACHE_CL", "$($(Get-ChildItem $(Get-VSSetupInstance).InstallationPath -Filter clo.exe -Recurse | Select-Object Fullname |Where {$_.FullName -match "Hostx64\\x64"}).FullName)", "Machine")
Remove-Item "C:\Windows\Temp\clcache-4.1.0.zip"