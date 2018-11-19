function Get-NCHDockerImageName {
    <#
    .SYNOPSIS
    Compiles a Docker Image string

    .PARAMETER ImageType
    The type of docker image that you would like to select.  There are 4 possibilities:
    - CurrentNAV - a released NAV Version
    - CurrentBusinessCentral - the current released version on Business Central
    - NextBusinessCentral - The next version of Business Central
    - NextMajorBusinessCentral - The next major release of Business Central
    
    .PARAMETER VersionOrBuild
    The Version of NAV or the Build of Business Central of the image you'd like to get.   

    .PARAMETER Cu
    The Cumulative Update No. (only applicable for ImageType "CurrentNAV")

    .PARAMETER Country
    The Country (two letters).

    .EXAMPLE
    Get-NAVDockerImageName -ImageType CurrentNAV -Cu 3 

    Returns: microsoft/dynamics-nav:cu3

    .EXAMPLE
    Get-NAVDockerImageName -ImageType CurrentNAV -VersionOrBuild 2018 -Country BE -Cu 4

    Returns: microsoft/dynamics-nav:2018-cu4-be

    .EXAMPLE
    Get-NAVDockerImageName -ImageType CurrentBusinessCentral -VersionOrBuild "12.0.21229.0" -Country be    
    
    Returns: microsoft/bcsandbox:12.0.21229.0-be

    .EXAMPLE
    Get-NAVDockerImageName -ImageType NextBusinessCentral -Country DK
    
    Returns: bcinsider.azurecr.io/bcsandbox:dk

    .EXAMPLE
    Get-NAVDockerImageName -ImageType NextMajorBusinessCentral -Country BE

    Returns: bcinsider.azurecr.io/bcsandbox-master:be
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentNAV', 'CurrentBusinessCentral', 'NextBusinessCentral', 'NextMajorBusinessCentral')]
        [String] $ImageType,
        [Parameter(Mandatory = $false)]
        [String] $VersionOrBuild,
        [Parameter(Mandatory = $false)]
        [Int] $Cu,
        [Parameter(Mandatory = $false)]
        [String] $Country
    )
    Switch ($ImageType) {
        "CurrentNAV" {
            $ImageName = 'microsoft/dynamics-nav'                
        }
        "CurrentBusinessCentral" {
            $ImageName = 'microsoft/bcsandbox'  
            if ($Cu) { 
                write-error -Message "Not possible to include a Cu in $input"
                break
            }         
        }
        "NextBusinessCentral" {
            $ImageName = 'bcinsider.azurecr.io/bcsandbox'            
            if ($Cu) { 
                write-error -Message "Not possible to include a Cu in $input"
                break
            }         
        }
        "NextMajorBusinessCentral" {
            $ImageName = 'bcinsider.azurecr.io/bcsandbox-master'
            if ($Cu) { 
                write-error -Message "Not possible to include a Cu in $input"
                break
            }                  
        }        
    }
    if ($VersionOrBuild -or $Cu -or $Country) {$ImageName += ":"}
    if ($VersionOrBuild) {$ImageName += "-$VersionOrBuild"}
    if ($Cu) {$ImageName += "-Cu$Cu"}
    if ($Country) {$ImageName += "-$Country"}
    $ImageName = ($ImageName -Replace ":-", ":").ToLower()

    Write-Verbose -Message "Compiled ImageName: $ImageName"

    return $ImageName
}
