﻿function Create-NAVXFromDB
{
    [CmdLetBinding()]
    param(
        [string] $AppName,
        [String] $AppPublisher,
        [String] $AppDescription,
        [string] $BuildFolder,
        [string] $OriginalServerInstance,
        [string] $ModifiedServerInstance,
        [String] $InitialVersion = '1.0.0.0',
        [String] $PermissionSetId='',
        [String] $WebServicePrefix='',
        [String] $BackupPath,
        [String] $Dependencies = $null,
        [String[]] $IncludeFilesInNavApp,
        [Int[]] $ExportTableDataFromTableIds,
        [String] $Logo),


    # Set Variables
    $BuildFolder = (join-path $BuildFolder 'Create-NAVXFromDB')

    $navAppManifestFile = (join-path $BuildFolder "$($AppName).xml")

    New-Item -ItemType Directory -Force -Path $BuildFolder | Out-Null

    $packageFolder = Join-Path -Path $BuildFolder -ChildPath 'Packages'
    $packageFolder = New-Item -ItemType Directory -Force -Path $packageFolder
    
    #Restore Manifest from Backup folder
    if ($BackupPath){
        $BackupNAVAppManifestFile = Join-Path $BackupPath "$($AppName).xml"
        if (Test-Path $BackupNAVAppManifestFile){
            $null = Copy-Item -Path $BackupNAVAppManifestFile -Destination $navAppManifestFile -Recurse -Force    
        }
    }

    # Update or Create Manifest
    Write-Host -Foregroundcolor Green 'Setup App-Manifest... '
    
    if (Test-Path -Path $navAppManifestFile){
        $MyNewManifest = Get-NAVAppManifest -Path $navAppManifestFile
    }
    if ($MyNewManifest -eq $null)
    {
        Write-Host -Foregroundcolor Green 'Create APP Package'
        $MyNewManifest = Create-NAVAppPackage `
                                -AppName $AppName `
                                -BuildFolder $BuildFolder `
                                -Version $InitialVersion `
                                -Publisher $AppPublisher `
                                -Description $AppDescription
    } else {
        Write-Host -Foregroundcolor Green 'Update APP Package'
        $newAppVersion = $MyNewManifest.AppVersion.Major.ToString() + '.' + $MyNewManifest.AppVersion.Minor.ToString() + '.' + $MyNewManifest.AppVersion.Build.ToString() + '.' + ($MyNewManifest.AppVersion.Revision + 1).ToString()
        if ([String]::IsNullOrEmpty($Dependencies)){
            $MyNewManifest = Set-NAVAppManifest `
                                -Manifest $MyNewManifest `
                                -Version $newAppVersion `
                                -PrivacyStatement 'http://www.waldo.Be' `
                                -Eula 'http://www.waldo.Be' `
                                -Help 'http://www.waldo.Be' `
                                -Url 'http://www.waldo.Be'
            if ($Dependencies){
                $MyNewManifest = Set-NAVAppManifest `
                                    -Manifest $MyNewManifest `
                                    -Dependencies $Dependencies
            }
                                
        } else {
            $MyNewManifest = Set-NAVAppManifest `
                                        -Manifest $MyNewManifest `
                                        -Version $newAppVersion `
                                        -PrivacyStatement 'http://www.waldo.Be' `
                                        -Eula 'http://www.waldo.Be' `
                                        -Help 'http://www.waldo.Be' `
                                        -Url 'http://www.waldo.Be'
            if ($Dependencies){
                $MyNewManifest = Set-NAVAppManifest `
                                    -Manifest $MyNewManifest `
                                    -Dependencies $Dependencies
            }      
        }
        
    }

    New-NAVAppManifestFile -Path $navAppManifestFile -Manifest $MyNewManifest -Force
        
    # Extract Applications and Create Deltas
    Write-Host -Foregroundcolor Green "Starting to create deltas between $OriginalServerInstance and $ModifiedServerInstance ..."
    $navAppFileDirectory = Create-NAVAppFiles `
                                    -OriginalServerInstance $OriginalServerInstance `
                                    -ModifiedServerInstance $ModifiedServerInstance `
                                    -BuildPath $BuildFolder `
                                    -PermissionSetId $PermissionSetId `
                                    -IncludeFilesInNavApp $IncludeFilesInNavApp `
                                    -WebServicePrefix $WebServicePrefix

    if ($ExportTableDataFromTableIds){
        Write-Host -Foregroundcolor Green "Exporting TableData for:"
        foreach($ExportTableDataFromTableId in $ExportTableDataFromTableIds){
            Write-Host -Foregroundcolor Gray "Table $ExportTableDataFromTableId"
            Export-NAVAppTableData `
                -ServerInstance $ModifiedServerInstance `
                -TableId $ExportTableDataFromTableId `
                -Path $navAppFileDirectory
        }
    }
    
    # Create NavX Package
    $navAppPackageFile = $AppName + '_v' + $MyNewManifest.AppVersion.ToString() + '.navx'
    $navAppPackageFile = Join-Path -Path $packageFolder -ChildPath $navAppPackageFile
    if (Test-Path -Path $navAppPackageFile)
    {
        Remove-item $navAppPackageFile
    }
    
    Write-Host -Foregroundcolor Green "DeltaDir: $navAppFileDirectory"    
    if ([String]::IsNullOrEmpty($logo)){
        $AppPackage = New-NAVAppPackage -Manifest $MyNewManifest -SourcePath $navAppFileDirectory -Path $navAppPackageFile -PassThru 
    } else {
        $AppPackage = New-NAVAppPackage -Manifest $MyNewManifest -SourcePath $navAppFileDirectory -Path $navAppPackageFile -logo $logo -PassThru 
    }

    Write-Host -Foregroundcolor Green "NavX Package File: $navAppPackageFile"
    
    if ($BackupPath){
        $null = Copy-Item -Path $PackageFolder -Destination $BackupPath -Recurse -Force    
        $null = Copy-Item -Path $navAppManifestFile -Destination $BackupPath -Force
    }

    [hashtable]$Return = @{} 
    $Return.Manifest = $MyNewManifest
    $Return.PackageFile = $navAppPackageFile
    return $Return
}