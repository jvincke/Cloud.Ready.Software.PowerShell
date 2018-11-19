﻿<#
Install New DEV experience on a local environment
Step 1: create an ISO from the DVD on the VM image by executing "CreateISOandZipOnAzureImage.ps1"
Step 2: Copy the the files to a local machine in the folder 'C:\_Installs'
Step 3: execute this script
#>


$DVDFilePath = "C:\_Installs\NAVDVD.iso"
$FullInstallNAV2017Config = '<Configuration><Component Id="ClickOnceInstallerTools" State="Local" ShowOptionNode="yes"/><Component Id="NavHelpServer" State="Local" ShowOptionNode="yes"/><Component Id="WebClient" State="Local" ShowOptionNode="yes"/><Component Id="AutomatedDataCaptureSystem" State="Local" ShowOptionNode="yes"/><Component Id="OutlookAddIn" State="Absent" ShowOptionNode="yes"/><Component Id="SQLServerDatabase" State="Local" ShowOptionNode="yes"/><Component Id="SQLDemoDatabase" State="Local" ShowOptionNode="yes"/><Component Id="ServiceTier" State="Local" ShowOptionNode="yes"/><Component Id="Pagetest" State="Local" ShowOptionNode="yes"/><Component Id="STOutlookIntegration" State="Local" ShowOptionNode="yes"/><Component Id="ServerManager" State="Local" ShowOptionNode="yes"/><Component Id="RoleTailoredClient" State="Local" ShowOptionNode="yes"/><Component Id="ExcelAddin" State="Local" ShowOptionNode="yes"/><Component Id="ClassicClient" State="Local" ShowOptionNode="yes"/><Parameter Id="TargetPath" Value="C:\Program Files (x86)\Microsoft Dynamics NAV\100"/><Parameter Id="TargetPathX64" Value="C:\Program Files\Microsoft Dynamics NAV\100"/><Parameter Id="NavServiceServerName" Value="localhost"/><Parameter Id="NavServiceInstanceName" Value="NAV"/><Parameter Id="NavServiceAccount" Value="NT AUTHORITY\NETWORK SERVICE"/><Parameter Id="NavServiceAccountPassword" IsHidden="yes" Value=""/><Parameter Id="ManagementServiceServerPort" Value="7045"/><Parameter Id="ManagementServiceFirewallOption" Value="true"/><Parameter Id="NavServiceClientServicesPort" Value="7046"/><Parameter Id="WebServiceServerPort" Value="7047"/><Parameter Id="WebServiceServerEnabled" Value="true"/><Parameter Id="DataServiceServerPort" Value="7048"/><Parameter Id="DataServiceServerEnabled" Value="true"/><Parameter Id="NavFirewallOption" Value="true"/><Parameter Id="CredentialTypeOption" Value="Windows"/><Parameter Id="DnsIdentity" Value=""/><Parameter Id="ACSUri" Value=""/><Parameter Id="SQLServer" Value="localhost"/><Parameter Id="SQLInstanceName" Value=""/><Parameter Id="SQLDatabaseName" Value="DemoDB"/><Parameter Id="SQLReplaceDb" Value="DROPDATABASE"/><Parameter Id="SQLAddLicense" Value="true"/><Parameter Id="PostponeServerStartup" Value="false"/><Parameter Id="PublicODataBaseUrl" Value=""/><Parameter Id="PublicSOAPBaseUrl" Value=""/><Parameter Id="PublicWebBaseUrl" Value=""/><Parameter Id="PublicWinBaseUrl" Value=""/><Parameter Id="WebServerPort" Value="8080"/><Parameter Id="WebServerSSLCertificateThumbprint" Value=""/><Parameter Id="WebClientRunDemo" Value="true"/><Parameter Id="WebClientDependencyBehavior" Value="install"/><Parameter Id="NavHelpServerPath" Value="C:\Inetpub\wwwroot"/><Parameter Id="NavHelpServerName" Value="localhost"/><Parameter Id="NavHelpServerPort" Value="49000"/></Configuration>'
$NAVLicenseFile = "C:\Users\Administrator\Dropbox\Dynamics NAV\Licenses\2017 DEV License.flf"
$ZipFile = "C:\_Installs\NewDEVTools.zip"
$Destination = 'C:\_Installs'
$DevServerInstance = 'W1'


#CreateConfigFile
$FullInstallNAV2017ConfigFile = [io.path]::GetTempFileName()
Set-Content -Value $FullInstallNAV2017Config -Path $FullInstallNAV2017ConfigFile

#UnzipIso
if ([io.path]::GetExtension($DVDFilePath) -eq '.zip'){
    Unzip-Item -SourcePath $DVDFilePath -DestinationPath ([io.path]::GetDirectoryName($DVDFilePath))
    $DVDIsoFilePath = Get-ChildItem -Path ([io.path]::GetDirectoryName($DVDFilePath)) -Filter '*.iso'
} else {
    $DVDIsoFilePath = get-item $DVDFilePath
}

#Load Waldo's Module
Find-Module | where author -eq waldo | Install-Module -Force
Import-Module -Name Cloud.Ready.Software.NAV

#InstallNAV
Install-NAVFromISO `
    -ISOFilePath $DVDIsoFilePath.FullName `
    -ConfigFile $FullInstallNAV2017ConfigFile `
    -Licensefile $NAVLicenseFile `
    -Log c:\temp `
    -DisableCompileBusinessLogic 

#Unzip
Write-Host -ForegroundColor Green "Unzipping $ZipFile"
$DEVExpPath = 'C:\DEMO\New Developer Experience'
Unzip-Item $ZipFile -DestinationPath $DEVExpPath

#Install VSCode
$Folder = $Destination
$Filename = "$Folder\VSCodeSetup-stable.exe"
New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
    
if (!(Test-Path $Filename)) {
    Write-Host -ForegroundColor Green "Downloading Visual Studio Code Setup Program"
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://go.microsoft.com/fwlink/?LinkID=623230", $Filename)
}

Write-Host -ForegroundColor Green "Installing Visual Studio Code"
$setupParameters = "/VerySilent /CloseApplications /NoCancel /LoadInf=""c:\demo\vscode.inf"" /MERGETASKS=!runcode"
Start-Process -FilePath $Filename -WorkingDirectory $Folder -ArgumentList $setupParameters -Wait -Passthru | Out-Null
Write-Host -ForegroundColor Green  "Remove and add http binding for local access using Windows Auth"
Get-WebBinding -Name "Microsoft Dynamics NAV TENERIFE Web Client" -Protocol http | Remove-WebBinding
New-WebBinding -Name "Microsoft Dynamics NAV TENERIFE Web Client" -Port 8080 -Protocol http -IPAddress "*" | Out-Null
#Install Extension (thanks to Freddy's code)
Write-Host -ForegroundColor Green "Install Extension (thanks to Freddy's code)"
$code = "C:\Program Files (x86)\Microsoft VS Code\bin\Code.cmd"
Get-ChildItem -Path $DEVExpPath -Filter "*.vsix" | % {   
   & $code @('--install-extension', $_.FullName) 
}
if ([Environment]::UserName -ne "SYSTEM") {
    # If installation is from template - the vsix ends up under default user...:-(
    $username = [Environment]::UserName
    if (Test-Path -path "c:\Users\Default\.vscode" -PathType Container -ErrorAction Ignore) {
        if (!(Test-Path -path "c:\Users\$username\.vscode" -PathType Container -ErrorAction Ignore)) {
            Log "Copy .vscode to $username"
            Copy-Item -Path "c:\Users\Default\.vscode" -Destination "c:\Users\$username\" -Recurse -Force -ErrorAction Ignore
        }
    }
}
#Create DEV instance
Import-Module 'C:\Program Files\Microsoft Dynamics NAV\100\Service\NavAdminTool.ps1' -WarningAction SilentlyContinue -Scope Global -Force| out-null
Import-Module 'C:\Program Files (x86)\Microsoft Dynamics NAV\100\RoleTailored Client\Microsoft.Dynamics.NAV.Model.Tools.psd1' -WarningAction SilentlyContinue -Scope Global -Force | out-null
Import-Module 'C:\Program Files (x86)\Microsoft Dynamics NAV\100\RoleTailored Client\Microsoft.Dynamics.Nav.Apps.Tools.psd1' -WarningAction SilentlyContinue -Scope Global -Force | out-null
Get-NAVServerInstance -ServerInstance NAV | Copy-NAVEnvironment -ToServerInstance $DevServerInstance

New-NAVWebServerInstance -ServerInstance $DevServerInstance -WebServerInstance $DevServerInstance -Server localhost 

Set-NAVServerConfiguration -ServerInstance $DevServerInstance -KeyName DeveloperServicesEnabled -KeyValue True
Set-NAVServerConfiguration -ServerInstance $DevServerInstance -KeyName PublicWebBaseUrl -KeyValue ((Get-NAVWebServerInstance -WebServerInstance $DevServerInstance).Uri)
Set-NAVServerInstance -ServerInstance $DevServerInstance -Restart

write-host -ForegroundColor Green "Start the test environment with: 'Start $((Get-NAVWebServerInstance -WebServerInstance $DevServerInstance).Uri)'"

#Enable In-Client Designer
$NAVWebConfigFile = "C:\inetpub\wwwroot\$DevServerInstance\Web.config"
$NAVWebConfig = [xml](Get-Content $NAVWebConfigFile)
$designerKey = $NAVWebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='designer']")
if ($designerkey) {
    $designerkey.value = "true"
} else {
    $addelm = $NAVWebConfig.CreateElement("add")
    $keyatt = $NAVWebConfig.CreateAttribute("key")
    $keyatt.Value = "designer"
    $addelm.Attributes.Append($keyatt) | Out-Null
    $valatt = $NAVWebConfig.CreateAttribute("value")
    $valatt.Value = "true"
    $addelm.Attributes.Append($valatt) | Out-Null
    $NAVWebConfig.configuration.DynamicsNAVSettings.AppendChild($addelm) | Out-Null
}
$NAVWebConfig.Save($NAVWebConfigFile)

#Enable Debugger
$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$serverConfigFile = Join-Path $ServiceTierFolder "Microsoft.Dynamics.Nav.Server.exe.config"
$serverConfig = [xml](Get-Content -Path $serverConfigFile)
$serverConfig.SelectSingleNode("//configuration/runtime/NetFx40_LegacySecurityPolicy").enabled = "false"
$serverConfig.Save($serverConfigFile)
Set-NavServerInstance -serverInstance $DevServerInstance -restart
