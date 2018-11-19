﻿Get-Item $PSScriptRoot  | Get-ChildItem -Recurse -Filter '*.ps1' -File | where FullName -NotLike '*Tests.ps1' | Sort Name | foreach {
    Write-Verbose "Loading $($_.Name)" 
    . $_.fullname
}

Export-ModuleMember -Function *