# WinCleaner
# github.com/paulpfeister/sysbuild
#
# MAINTAINER : Paul Pfeister (github.com/paulpfeister)
# 
# PURPOSE    : Eliminate much of the crapware that comes with Windows 10 and Windows 11, and disable or otherwise
#              mitigate certain baked-in telemetry items, to the greatest extent possible without breaking Windows.
#
# WARRANTY   : No warranty provided whatsoever. Use at your own risk. See license.

#Requires -RunAsAdministrator

    ##################
  ######################
##########################
##########################
#### Development Only ####

$script:DebugPreference = "SilentlyContinue"    # Normally SilentlyContinue
$script:VerbosePreference = "SilentlyContinue"  # Normally SilentlyContinue
$script:runOnUnix = $true                      # Normally false
$script:runOnIncompatibleWin = $true            # Normally false

#### Development Only ####
##########################
##########################
  ######################
    ##################




    #########
  #############
#################
#################
#### Globals ####

New-Variable -Scope Script -Name scriptBanner -Option Constant -Value @"
	
  <><><><><><><><><><><><><><><><><><><><><><><><>
<><>                                            <><>
<>                   WinCleaner                   <>
<>     Windows bloat and telemetry mitigation     <>
<>                                                <>
<>    https://github.com/paulpfeister/sysbuild    <>
<><>                                            <><>
  <><><><><><><><><><><><><><><><><><><><><><><><>



"@

New-Variable -Scope Script -Name sysenv -Option Constant -Value "$([System.Environment]::OSVersion.Platform)"
if ($sysenv -eq "Win32NT") {
    New-Variable -Scope Script -Name distrib -Option Constant -Value "$((Get-WmiObject Win32_OperatingSystem).Caption)"
}

New-Variable -Scope Script -Name manifestRootUri -Option Constant -Value "https://raw.githubusercontent.com/paulpfeister/sysbuild/master/Windows/defs"

#### Globals ####
#################
#################
  #############
    #########


    #######################
  ###########################
###############################
###############################
#### WinCleaner Setup Menu ####

$menuItem_SetVerbosity = "Verbose"
$menuItem_OEMDebloatByName = "OEM de-bloat (by name)"
$menuItem_OEMDebloatByGUID = "OEM de-bloat (by GUID)"
$menuItem_MetroDebloatMS = "Metro de-bloat, Microsoft (i.e. Mahjong)"
$menuItem_MetroDebloat3P = "Metro de-bloat, 3rd Party (i.e. LinkedIn)"
$menuItem_RemoveOneDrive = "Remove OneDrive"
$menuItem_TelemetryDisable = "Telemetry disable (quick)"
$menuItem_TelemetryDismantle = "Telemetry raze (slow)"
$menuItem_DisableUpdateServices = "Disable system update services"
$menuItem_ReplaceEdge = "Replace Edge with Firefox (requires winget)"
$menuItem_InstallWinget = "Install winget" #TODO Add winget installer
$menuItem_wingetPurge = "Debloat Windows App Installer (requires winget)"
$menuItem_PreferRemoteLists = "Ignore local package manifests (requires internet)"

$options = @{
    #$menuItem_OEMDebloatByName = $false
    #$menuItem_OEMDebloatByGUID = $false
    $menuItem_MetroDebloatMS = $true
    $menuItem_MetroDebloat3P = $true
    #$menuItem_RemoveOneDrive = $true
    #$menuItem_TelemetryDisable = $true
    #$menuItem_TelemetryDismantle = $true
    #$menuItem_DisableUpdateServices = $false
    #$menuItem_ReplaceEdge = $false
    #$menuItem_InstallWinget = $false
    $menuItem_SetVerbosity = $false
    $menuItem_PreferRemoteLists = $false
    $menuItem_wingetPurge = $true
}

function DisplayMenu {
    $selectedIndex = 0
    $optionEntries = $options.GetEnumerator() | Sort-Object Name
    $buttonLabels = @("Begin", "Cancel")
    
    # Move cursor to the top of the console window
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    
    while ($true) {
        # Clear console window (if not in debug mode)
        if($DebugPreference -eq "SilentlyContinue") {
            Clear-Host
        }

	[console]::CursorVisible = $false

	Write-Host "$scriptBanner"
	
	$menuOptionLeftPadding = "    "
        
	# Display menu
	for ($i = 0; $i -lt $optionEntries.Count; $i++) {
            $option = $optionEntries[$i].Key
            $isSelected = $options[$option] # Get the current state directly from the $options hashtable
            if ($i -eq $selectedIndex) {
                Write-Host -ForegroundColor Yellow ("$menuOptionLeftPadding[$(if ($isSelected) {'*'} else {' '})] $($option)")
            } else {
                Write-Host ("$menuOptionLeftPadding[$(if ($isSelected) {'*'} else {' '})] $($option)")
            }
        }

	Write-Host ""


        # Display buttons for Begin and Cancel
        $buttonOffset = $optionEntries.Count + 2
        for ($j = 0; $j -lt $buttonLabels.Count; $j++) {
            $buttonLabel = $buttonLabels[$j]
            if ($j -eq $selectedIndex - $optionEntries.Count) {
                Write-Host -ForegroundColor Yellow ("$menuOptionLeftPadding[$($buttonLabel)]")
            } else {
                Write-Host "$menuOptionLeftPadding[$($buttonLabel)]"
            }
        }

	Write-Host ""
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        switch ($key) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                }
            }
            40 { # Down arrow
                if ($selectedIndex -lt ($optionEntries.Count + $buttonLabels.Count - 1)) {
                    $selectedIndex++
                }
            }
            32 { # Spacebar
                if ($selectedIndex -eq $optionEntries.Count) {
                    return "Begin"
                } elseif ($selectedIndex -eq ($optionEntries.Count + 1)) {
                    return "Cancel"
                } else {
                    $options[$optionEntries[$selectedIndex].Key] = !$options[$optionEntries[$selectedIndex].Key]
                }
            }
            13 { # Enter
                if ($selectedIndex -eq $optionEntries.Count) {
                    return "Begin"
                } elseif ($selectedIndex -eq ($optionEntries.Count + 1)) {
                    return "Cancel"
                } else {
                    $options[$optionEntries[$selectedIndex].Key] = !$options[$optionEntries[$selectedIndex].Key]
                }
            }
        }
    }
}

#### WinCleaner Setup Menu ####
###############################
###############################
  ###########################
    #######################


# Because Write-Error annoyingly has no option to disable stack trace
function printErr($message) {
    $originalForegroundColor = (get-host).ui.rawui.ForegroundColor
    $originalBackgroundColor = (get-host).ui.rawui.BackgroundColor
    [console]::ForegroundColor = "Red"
    [console]::BackgroundColor = "Black"
    [console]::Error.WriteLine($message)
    [console]::ForegroundColor = $originalForegroundColor
    [console]::BackgroundColor = $originalBackgroundColor
}

if ($sysenv -ne "Win32NT") {
    if ($sysenv -eq "Unix" -and $runOnUnix) {
    } else {
        Write-Host $scriptBanner
        prinErr("This script is intended to run on Windows only. Exiting.")
    }
}

$result = DisplayMenu

if ($result -eq "Cancel") {
    Write-Host "No action taken.`n"
    return
}

if ($result -ne "Begin") {
    return "Somehow, an invalid result was returned from the menu. Exiting."
}

function setVerbosity {
    if (-not $options[$menuItem_SetVerbosity]) {
        return
    }
    $script:VerbosePreference = 'Continue'
    Write-Verbose "SetVerbosity: Higher verbosity enabled."
}

# The original target lists were prepared for batch scripts. Discard DOS comments and set commands.
function filterTargetList([ref]$itemNames) {
    $itemNames.Value = $itemNames.Value `
    | Where-Object { $_ -notmatch "::" } `
    | Where-Object { $_ -notmatch "set" } `
    | Where-Object { $_ -notmatch "rem" } `
    | Where-Object { $_ -notmatch "#" }
}

function OEMDebloatByName {
    if (-not $options[$menuItem_OEMDebloatByName]) {
        return
    }
    
    # Check if running on compatible edition or version of Windows for this mode
    if (-not $runOnIncompatibleWin) {
        if ($distrib -notmatch "Windows 10" -and $distrib -notmatch "Windows 11") {
            printErr("OEMDebloatByName: Skipping due to incompatible Windows edition.")
            return
        }
    }

    Write-Debug "OEMDebloatByName: Entering job."

    # Load list of crapware, preferring local copy
    $itemNames = @()
    if (Test-Path -Path "defs/oem/programs_to_target_by_name.txt" -and -not $options[$menuItem_PreferRemoteLists]) {
        $itemNames = Get-Content -Path "defs/oem/programs_to_target_by_name.txt"
    } else {
        $itemNames = (Invoke-WebRequest -Uri "$manifestRootUri/oem/programs_to_target_by_name.txt").Content
    }
    filterTargetList([ref]$itemNames)

    Write-Verbose "OEMDebloatByName: Removing $($itemNames.Count) items by name."
    Write-Verbose "OEMDebloatByName: Job not yet implemented."
    Write-Debug "OEMDebloatByName: Leaving job."
}

function loadPackageManifest($manifestRelativeLoc) {
    # Load package manifests given their relative path, preferring local copy (typically "{category}/{name}")
    $itemNames = @('')
    if ((Test-Path -Path "defs/$manifestRelativeLoc.txt") -and (-not $options[$menuItem_PreferRemoteLists])) {
        $itemNames = Get-Content -Path "defs/$manifestRelativeLoc.txt"
    } else {
        try {
            $itemNames = (Invoke-WebRequest -Uri "$manifestRootUri/$manifestRelativeLoc.txt" -Verbose:$false).Content
        } catch {
            printErr("Local package manifest or connection to $manifestRootUri needed.")
            return
        }
    }
    filterTargetList([ref]$itemNames)
    return $itemNames
}

function MetroDebloat($metro_category) {
    # Check if running on compatible edition or version of Windows for this mode
    if (-not $runOnIncompatibleWin) {
        if ($distrib -notmatch "Windows 10" -and $distrib -notmatch "Windows 11") {
            printErr("MetroDebloat: Skipping due to incompatible Windows edition.")
            return
        }
    }

    Write-Debug "MetroDebloat: Entering job."

    # Load list of crapware, preferring local copy
    $itemNames = loadPackageManifest "metro/$metro_category"
    

    Write-Verbose "MetroDebloat: Loaded $($itemNames.Count) items by name (category: $metro_category)."

    # Iterate over the loaded manifest, removing each item that exists on the system
    $installed = Get-AppxPackage -AllUsers | Select-Object Name
    $itemNames | ForEach-Object {
        $item = $_
        Write-Debug "MetroDebloat: Attempting to remove $item."

        # UNISNTALLING packages
        $installed = Get-AppxPackage -AllUsers | Select-Object PackageFullName,Name `
        | Where-Object Name -eq $item `
        | Select-Object -ExpandProperty PackageFullName

        if ($installed) {
            try {
                Remove-AppxPackage -Verbose:$false -Package $installed -ErrorAction Stop
                Write-Verbose "MetroDebloat: Removed $item."
            } catch {
                printErr("MetroDebloat: Failed to remove $item.")
            }
            Clear-Variable installed
        }

        # DEPROVISIONING packages
        $provisioned = Get-AppxProvisionedPackage -Online -Verbose:$false `
        | Where-Object DisplayName -eq $item `
        | Select-Object -ExpandProperty PackageName

        if ($provisioned) {
            try {
                Remove-AppxProvisionedPackage -Online -Verbose:$false -PackageName $provisioned -ErrorAction Stop
                Write-Verbose "MetroDebloat: Deprovisioned $item."
            } catch {
                printErr("MetroDebloat: Failed to deprovision $item.")
            }
            Clear-Variable provisioned
        }
    }

    Write-Debug "MetroDebloat: Leaving job."

}

function installWingetIfNotExist {
    # Return early if winget exists
    try {
        winget --version | Out-Null
        return 0
    } catch {}

    # TODO Add winget autoinstaller (return 0 if successful)
    printErr("replaceEdge: winget does not exist. Install or update Microsoft's App Installer via https://apps.microsoft.com/detail/9NBLGGH4NNS1.")
    return "winget not installed"
}

function purgeWinget {
    if (-not $options[$menuItem_wingetPurge]) { return }
    if (-not $runOnIncompatibleWin) {
        if ($distrib -notmatch "Windows 10" -and $distrib -notmatch "Windows 11") {
            printErr("MetroDebloat: Skipping due to incompatible Windows edition.")
            return
        }
    }
    if ((installWingetIfNotExist)) { return }

    Write-Debug "purgeWinget: Entering job."

    $itemNames = loadPackageManifest "winget/remove-by-name"
    Write-Verbose "purgeWinget: Loaded $($itemNames.Count) items by name (category: purgeByName)."    

    $itemNames | ForEach-Object {
        $item = $_
        $installed = winget list | Select-String -Pattern $item | Select-Object -ExpandProperty LineNumber
        if ($installed) {
            try {
                $out = winget uninstall --name $item --silent --force --purge --accept-source-agreements --disable-interactivity
                if ($out -eq "No installed package found matching input criteria.") {
                    throw "No installed package found matching input criteria."
                }
                Write-Verbose "purgeWinget: Removed: $item."
            } catch {
                printErr("purgeWinget: Failed to remove $item.")
            }
            Clear-Variable installed
        } else {
            Write-Verbose "purgeWinget: Absent: $item"
        }
    }

    Write-Verbose "purgeWinget: Cleaning up registry."
    try {
        $out = reg import defs/winget/housekeeping.reg
        if ($out -ne "The operation completed successfully.") {
            throw "something went wrong with reg import?"
        }
        Write-Verbose "purgeWinget: Cleaned up registry."
    } catch {
        printErr("purgeWinget: Failed to clean up registry. Does the definition exist locally? Remote sourcing is disabled.")
    }

    Write-Debug "purgeWinget: Leaving job."
}



    ####################
  ########################
############################    
############################
#### Run all the things ####

Write-Host "This can take a while.`n"

setVerbosity
OEMDebloatByName
if ($options[$menuItem_MetroDebloatMS]) { MetroDebloat("microsoft") }
if ($options[$menuItem_MetroDebloat3P]) { MetroDebloat("thirdparty") }
purgeWinget