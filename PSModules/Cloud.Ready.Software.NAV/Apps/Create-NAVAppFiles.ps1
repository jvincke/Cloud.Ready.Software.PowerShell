﻿function Create-NAVAppFiles
{    <#
    .Synopsis
       Create delta's, specifically meant to do NAVApps, which means: including permissionsets and Web Services
    .DESCRIPTION
       
    .NOTES
       <TODO: Some tips>
    .PREREQUISITES
       <TODO: like positioning the prompt and such>
    #>

    [CmdLetBinding()]
    param(
        [string] $OriginalServerInstance,
        [string] $ModifiedServerInstance,
        [string] $BuildPath,
        [String] $PermissionSetId='',
        [String] $WebServicePrefix='',
        [String[]] $IncludeFilesInNavApp)

    $BuildPath = Join-Path -Path $BuildPath -ChildPath 'CreateNAVAppFiles'

    $orginalObjects = Join-Path -Path $BuildPath -ChildPath 'original.txt'
    $modifiedObjects = Join-Path -Path $BuildPath -ChildPath 'modified.txt'
    $modifiedObjectsPartial = Join-Path -Path $BuildPath -ChildPath 'modified_partial.txt'

    $OriginalServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $OriginalServerInstance
    $ModifiedServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $ModifiedServerInstance

    $AppFilesFolder = Join-Path -Path $BuildPath -ChildPath 'AppFiles'
    $AppFilesFolder = New-Item -ItemType Directory -Force -Path $AppFilesFolder 

    $originalFolder = Join-Path -Path $BuildPath -ChildPath 'Original'
    $originalFolder = New-Item -ItemType Directory -Force -Path $originalFolder 

    $modifiedFolder = Join-Path -Path $BuildPath -ChildPath 'Modified'
    $modifiedFolder = New-Item -ItemType Directory -Force -Path $modifiedFolder
    
    $ExportJobs = @()
         
    if (!(Test-Path -Path $orginalObjects))
    {
        Write-Host -Foregroundcolor Green 'Exporting ORIGINAL objects ...'
        Export-NAVApplicationObject -DatabaseServer $OriginalServerInstanceObject.DatabaseServer -DatabaseName $OriginalServerInstanceObject.Databasename -Path $orginalObjects -ExportTxtSkipUnlicensed | Out-Null
        Split-NAVApplicationObjectFile -Source $orginalObjects -Destination $originalFolder -PreserveFormatting -Force 
        Write-Host -Foregroundcolor Green "ORIGINAL objects exported to $originalObjects"        
    } else {
        write-warning "$orginalObjects already exists.  ORIGINAL objects are NOT exported again!"
    }
    
    Write-Host -Foregroundcolor Green 'Exporting MODIFIED objects ...'
       
    if (!(Test-Path -Path $modifiedObjects))
    {
        Export-NAVApplicationObject -DatabaseServer $ModifiedServerInstanceObject.DatabaseServer -DatabaseName $ModifiedServerInstanceObject.DatabaseName -Path $modifiedObjects -ExportTxtSkipUnlicensed | Out-Null   
        Split-NAVApplicationObjectFile -Source $modifiedObjects -Destination $modifiedFolder -PreserveFormatting -Force
        Write-Host -Foregroundcolor Green "All objects from $ModifiedServerInstance exported to $modifiedObjects"
    } else {
        Export-NAVApplicationObject -DatabaseServer $ModifiedServerInstanceObject.DatabaseServer -DatabaseName $ModifiedServerInstanceObject.DatabaseName -Path $modifiedObjectsPartial -Filter 'Modified=1' -ExportTxtSkipUnlicensed -Force | Out-Null   
        
        if (!(Test-Path $modifiedObjectsPartial) -or ((get-item $modifiedObjectsPartial).Length -eq 0)){
            write-error 'No modified objects found! Nothing exported'
        } else {
            Split-NAVApplicationObjectFile -Source $modifiedObjectsPartial -Destination $modifiedFolder -PreserveFormatting -Force
            write-warning "$modifiedObjects already existed.  Only objects with MODIFIED=TRUE were exported!"
            Write-Host -Foregroundcolor Green "Modified objects from $ModifiedServerInstance exported to $modifiedObjects"
        }                
        
    }
        
    Write-Host -Foregroundcolor Green 'Comparing and creating Deltas...'
    Get-ChildItem -Path $AppFilesFolder -Include *.* -File -Recurse | Remove-Item
    $result = Compare-NAVApplicationObject -OriginalPath ($originalFolder.FullName + '\*.txt') -ModifiedPath ($modifiedFolder.FullName + '\*.txt') -DeltaPath $AppFilesFolder -NoCodeCompression -Force 
    Write-Host -Foregroundcolor Green "Deltas extracted to $AppFilesFolder"


    #Create Permission Sets
    if(!([String]::Isnullorempty($PermissionSetId))){
        Write-Host -Foregroundcolor Green "Exporting PermissionSet $PermissionSetId from $ModifiedServerInstance ..."
        #try { 
            $PermissionSetExists = Get-NAVServerPermissionSet -ServerInstance $ModifiedServerInstance | where PermissionSetID -eq $PermissionSetId
            if ($PermissionSetExists){
                Export-NAVAppPermissionSet `                    -ServerInstance $ModifiedServerInstance `                    -PermissionSetId $PermissionSetID `                    -Path (join-path $AppFilesFolder "$PermissionSetID.xml") `                    -ErrorAction SilentlyContinue
            } else {
                Get-NAVServerPermissionSet -ServerInstance $ModifiedServerInstance | 
                Where PermissionSetID -iLike "$PermissionSetID*" |                    foreach {                        Export-NAVAppPermissionSet `                            -ServerInstance $ModifiedServerInstance `                            -PermissionSetId $_.PermissionSetID `                            -Path (join-path $AppFilesFolder "$($_.PermissionSetID).xml")                     }                    
            }
            
        #}
        #Catch { 
        #    Write-Warning -Message 'Something went wrong with exporting Permission sets!'}
     }   

    #Create WebServiceXML
    if(!([String]::Isnullorempty($WebServicePrefix))){
        Write-Host -Foregroundcolor Green "Exporting Tenant Web Services with prefix '$WebServicePrefix' from $ModifiedServerInstance ..."

        Invoke-NAVSQL -ServerInstance $ModifiedServerInstance -SQLCommand "Select * From [Tenant Web Service] where [Service Name] like '%$WebServicePrefix%'" | 
            select 'Object Type', 'Service Name', 'Object ID' |
                foreach {
                    switch ($_.'Object Type')
                    {
                        '8' {$ObjectType = 'Page'}
                        '5' {$ObjectType = 'CodeUnit'}
                        Default {$ObjectType = $null}        
                    }
                    if (!([String]::IsNullOrEmpty($ObjectType))){
                        Export-NAVAppTenantWebService `
                            -ServiceName $_.'Service Name' `                            -ObjectType $ObjectType `                            -ObjectId $_.'Object ID' `                            -Path (join-path $AppFilesFolder "$($_.'Service Name').xml") `                            -ServerInstance $ModifiedServerInstance
                    }
                }
    }

    #IncludeFiles
    if(!([String]::Isnullorempty($IncludeFilesInNavApp))){
        foreach ($IncludeFileInNavApp in $IncludeFilesInNavApp){
            Write-Host -ForegroundColor Gray "Copying $([io.path]::GetFileName($IncludeFileInNavApp)) to $AppFilesFolder"
            Copy-Item -Path $IncludeFileInNavApp -Destination (join-path $AppFilesFolder ([io.path]::GetFileName($IncludeFileInNavApp)))
        }
    }   


    return $AppFilesFolder
}

