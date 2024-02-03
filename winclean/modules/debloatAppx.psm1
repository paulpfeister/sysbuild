#Requires -Version 7.0
#Requires -RunAsAdministrator

function filterManifest {
    param (
        [Parameter(Position=0,Mandatory=$true)] $itemNames
    )
    return $itemNames `
    | Where-Object { $_ -notmatch "::" } `
    | Where-Object { $_ -notmatch "set" } `
    | Where-Object { $_ -notmatch "rem" } `
    | Where-Object { $_ -notmatch "#" } `
    | Where-Object { $_ -notmatch "^\s*$" } # blank lines/whitespace lines
}

function loadPackageManifest {
    param (
        [Parameter(Position=0,Mandatory=$true)] [string] $Manifest
    )

    # Load package manifests given their relative path, preferring local copy (typically "{category}/{name}")
    #$itemNames = @('')
    #if ((Test-Path -Path "defs/$manifestRelativeUri.txt") -and (-not $options[$menuItem_PreferRemoteLists])) {
    #    $itemNames = Get-Content -Path "defs/$manifestRelativeUri.txt"
    #} else {
    #    try {            
    #        $itemNames = ((Invoke-WebRequest -Uri "$manifestRootUri/$manifestRelativeUri.txt" -Verbose:$false) -split "`n")
    #    } catch {
    #        Write-Error("Local package manifest or connection to $manifestRootUri needed.")
    #        return
    #    }
    #}

    try {
        $itemNames = Get-Content -Path "$Manifest" -ErrorAction Stop
    } catch {
        throw "Failed to load AppX manifest $Manifest."
    }

    $itemNames = filterManifest $itemNames
    return $itemNames
}

function isHostCompatible {
    $sysenv = "$([System.Environment]::OSVersion.Platform)"
    if ($sysenv -eq "Win32NT") {
        $build = "$([System.Environment]::OSVersion.Version.Build)"
        if ($build -ge 10240) { # Windows 10 1507 (10240) or later (Windows 11 21H2 begins at 22000)
            return $true
        }
    }
    return $false
}

function debloatAppx {
    <#
    .SYNOPSIS
    Remove Windows 10/11 AppX packages by manifest.
    .PARAMETER Manifest
    Absolute local URI to the manifest file. Remote URI not yet supported.
    .PARAMETER runOnIncompatible
    If set, all system compatibility checks will be skipped (useful for development and diagnostics).
    #>
    param (
        [Parameter(Position=0,Mandatory=$true)] [string] $Manifest,
        [Parameter(Position=1,Mandatory=$false)] [switch] $runOnIncompatible = $false
    )

    # Check if running on compatible edition or version of Windows for this mode
    if (-not $runOnIncompatible -and -not (isHostCompatible)) {
        throw "Incompatible host for AppX debloat."
    }

    Write-Debug "debloatAppx: Entering job."

    # Load list of crapware, preferring local copy
    $itemNames = loadPackageManifest -Manifest "$Manifest"
    

    Write-Verbose "debloatAppx: Loaded $($itemNames.Count) items by name from manifest $Manifest."

    # Iterate over the loaded manifest, removing each item that exists on the system
    #$installed = Get-AppxPackage -AllUsers | Select-Object Name
    $itemNames | Foreach-Object -ThrottleLimit 5 -AsJob -Parallel {
        
        $singletRemover = {    
            # UNISNTALLING packages
            try {
                $installed = Get-AppxPackage -AllUsers -ErrorAction Stop | Select-Object PackageFullName,Name `
                | Where-Object Name -eq PACKAGE_PLACEHOLDER `
                | Select-Object -ExpandProperty PackageFullName
            } catch {
                throw "Failed to query installed AppX packages."
            }
    
            if ($installed) {
                try {
                    Remove-AppxPackage -Verbose:$false -Package $installed -ErrorAction Stop
                    Write-Verbose "Removed AppX package PACKAGE_PLACEHOLDER."
                } catch {
                    Write-Error("Failed to remove AppX package PACKAGE_PLACEHOLDER.")
                }
                Clear-Variable installed
            }
    
            # DEPROVISIONING packages
            try {
                $provisioned = Get-AppxProvisionedPackage -Online -Verbose:$false -ErrorAction Stop `
                | Where-Object DisplayName -eq PACKAGE_PLACEHOLDER `
                | Select-Object -ExpandProperty PackageName
            } catch {
                throw "Failed to query for provisioned AppX packages under name PACKAGE_PLACEHOLDER."
            }
    
           if ($provisioned) {
                try {
                    Remove-AppxProvisionedPackage -Online -Verbose:$false -PackageName $provisioned -ErrorAction Stop | Out-Null
                    Write-Verbose "Deprovisioned AppX package PACKAGE_PLACEHOLDER."
                } catch {
                    Write-Error("Failed to deprovision AppX package PACKAGE_PLACEHOLDER.")
                }
                Clear-Variable provisioned
            }
            return
        }


        Write-Verbose "debloatAppx is attempting to remove $_"
        try {
            # why does powershell suck so much
            $singletRemover = [ScriptBlock]::Create(($singletRemover.tostring() -replace "PACKAGE_PLACEHOLDER", $_))
            # unless you know EXACTLY what to do to fix this so we can use variables, don't touch it. just leave it be. it's working finally. sort of.
            Invoke-Expression -Command "powershell -ExecutionPolicy Bypass -Command {$singletRemover}"
        } catch {
            Write-Error("Failed to remove AppX package $_. idk why. this section is a mess. maybe try prayer or something.")
        }
    } | Watch-Job -AutoRemoveJob -Delay 5
    Write-Debug "debloatAppx: Leaving job."
}

Export-ModuleMember -Function "debloatAppx"