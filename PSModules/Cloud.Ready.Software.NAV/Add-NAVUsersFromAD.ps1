﻿function Add-NAVUsersFromAD {

    <#
    .Synopsis
        Adds user based on AD search to a certain ServerInstance
    .DESCRIPTION
        Adds user based on AD search to a certain ServerInstance. The function has two principal steps.
        The first one will traverse through AD elements (OUs, containers, groups etc.) and in the second one
        you can specify a user filter.
        The third step will add the users.
    .NOTES
        Default PermissionSetId is 'SUPER'
    .EXAMPLE
        Add-NAVUsersFromAD -ServerInstance 'DynamicsNAV100'
    #>


    param(
        [parameter(Mandatory=$true)]
        [String] $ServerInstance,

        [parameter(Mandatory=$false)]
        [String] $PermissionSetId='SUPER'
    )


    if ((Get-Command -Module ActiveDirectory) -eq 0) {
        throw "ActiveDirectory module is missing. You can add it using [Add-WindowsFeature RSAT-AD-PowerShell] command."
    }

    Import-Module ActiveDirectory

    try {

        Push-Location

        $elementSelected = $null
        $menuElementSelected = $null

        do {

            if ($elementSelected -ne $null) {
                $path = 'AD:\' + $elementSelected.distinguishedName
            } else {
                $path = 'AD:\'
            }
            cd $path

            $elementIndex = 0
            #$elements = dir | Where-Object -Property ObjectClass -in "builtinDomain", "container", "domainDNS", "organizationalUnit", "group", "user"
            $elements = dir | Where-Object -Property ObjectClass -in "builtinDomain", "container", "domainDNS", "organizationalUnit", "group"
            $elementSelection = $elements | ForEach-Object { 
                New-Object PSObject -Property @{
                    'Index'="[" + (++$elementIndex) + "]"
                    'Name'= $_.Name
                    'ObjectClass' = $_.ObjectClass
                    'Users' = ( dir $_.PSChildName | Where-Object -Property ObjectClass -eq "user").Count 
                    'GroupMembers' = if ( $_.ObjectClass -eq "group" ) { (Get-ADGroupMember $_.distinguishedName | Where-Object -Property ObjectClass -eq "user").Count } else { 0 }
                 } 
            }

            # MENU SELECTION
            [int]$menuChoice = -1
            while ( $menuChoice -lt 0 -or $menuChoice -gt $elements.Count ) {
                Clear-Host
                Write-Host "`t(1) - CONTAINER SELECTION STEP `n" -ForegroundColor Cyan
                $elementSelection | Format-Table Index, Name, Users, GroupMembers, ObjectClass -AutoSize | Out-Host
                Write-Host "CURRENT AD PATH: $path" -ForegroundColor Cyan
                if ($menuElementSelected -ne $null) {
                    Write-Host "USERS: $($menuElementSelected.Users) / GROUP MEMBERS: $($menuElementSelected.GroupMembers)" -ForegroundColor Cyan
                }

                $menuText = "`nPlease, select one of the options available:`n"
                if ($elements.Count -ne 0) {
                    $menuText += " - [1]..[$($elements.Count)] to enter the specific AD element,`n"
                }
                $menuText += " - [0] or [ENTER] to confirm $path and proceed to the next step (user specification),`n"
                $menuText += " - pressing [CTRL+C] to quit the process.`n"

                do {
                    $askAgain = $false                    
                    try {
                        [Int]$menuChoice = Read-Host $menuText
                    }
                    catch {
                        $askAgain = $true
                        Write-Warning "Incorrect option, please, try it againg..."
                    }
                } while ($askAgain -eq $true)                
            }

            if ($menuChoice -ne 0) {
                $elementSelected = $elements[$menuChoice - 1]
                $menuElementSelected = $elementSelection[$menuChoice - 1]
            }

        } while ($menuChoice -ne 0)

        if ($elementSelected -ne $null) {

            $path = 'AD:\' + $elementSelected.distinguishedName
            cd $path

            switch ($elementSelected.objectClass) {                
                'group' {
                    $users = Get-ADGroupMember $elementSelected.distinguishedName | Where-Object -Property ObjectClass -eq "user" | Get-ADUser
                }
                default {
                    $users = dir | Where-Object -Property ObjectClass -eq "user" | Get-ADUser
                }
            }

            $users = $users | Where-Object -Property Enabled -eq $true
        
            do {

                Clear-Host
                Write-Host "`t(2) - USER SPECIFICATION STEP `n" -ForegroundColor Cyan

                Write-Host "CURRENT AD PATH: $path" -ForegroundColor Cyan
                if ($menuElementSelected -ne $null) {
                    Write-Host "USERS: $($menuElementSelected.Users) / GROUP MEMBERS: $($menuElementSelected.GroupMembers)" -ForegroundColor Cyan
                }

                $userMenuChoice = $null
                while ([String]::IsNullOrEmpty($userMenuChoice)) {
                    $users | Format-Table Name -AutoSize | Out-Host
                    [String]$userMenuChoice = Read-Host "`nPlease, write user name of search pattern or write just [*] to add all of them.`n"`
                                                "You can also stop the process pressing [CTRL+C]."
                }

                $usersToAdd = $users | Where-Object -Property Name -Like $userMenuChoice

                if ($usersToAdd.Count -eq 0) {
                
                    Write-Host "There is no user that matches the filter."

                } else {
                
                    [ValidateSet('Y','N')]$answer = 'Y'
                    
                    $usersToAdd | Format-Table | Out-Host
                    Write-Host                    
                    #$answer = Read-Host "Do you want to add $($usersToAdd.Count) users ([Y]es/[N]o)?"
                    try {
                        $answer = Read-Host "Do you want to add $($usersToAdd.Count) user(s) ([Y]es/[N]o)?"
                    }
                    catch {
                        $answer = 'N'
                        Write-Warning "You can answer [Y]es or [N]o, there is no other choice."                        
                    }

                    if ($answer -eq 'Y') {

                        foreach ($userToAdd in $usersToAdd) {
                        
                            Write-Verbose "`n === Adding $($userToAdd.Name) === "
                                            
                            if (-not (Get-NAVServerUser -ServerInstance $ServerInstance | where WindowsSecurityID -eq $userToAdd.SID)){
                                New-NAVServerUser -ServerInstance $ServerInstance -Sid $userToAdd.SID -FullName $userToAdd.Name
                            } else {
                                Write-Warning "User $($userToAdd.Name) already exists."
                            }
                            if (-not(Get-NAVServerUserPermissionSet -ServerInstance $ServerInstance -Sid $userToAdd.SID -PermissionSetId $PermissionSetId)){
                                New-NAVServerUserPermissionSet -ServerInstance $ServerInstance -PermissionSetId $PermissionSetId -Sid $userToAdd.SID
                            } else {
                                Write-Warning "Permissionset $($PermissionSetId) already assigned to user $($userToAdd.Name)."
                            }
                                            
                        }

                    }
                }
                
                do {
                    $askAgain = $false
                    [ValidateSet('Q','C')]$repeatAnswer = 'C'
                    try {
                        $repeatAnswer = Read-Host "Do you want to [c]ontinue and add next users or do you want to [q]uit?"
                    }
                    catch {
                        $repeatAnswer = 'C'
                        $askAgain = $true
                        Write-Warning "You can answer [C]continue or [Q]uit, there is no other choice."
                    }
                } while ($askAgain -eq $true)

            } while ($repeatAnswer -eq 'C')

        }

    }
    catch {

        throw "Add AD users failed: $($_.Exception)"

    }
    finally {

        Pop-Location

    }

}