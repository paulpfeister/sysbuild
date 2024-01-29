# WinCleaner
# github.com/paulpfeister/sysbuild
#
# MAINTAINER : Paul Pfeister (github.com/paulpfeister)
# 
# PURPOSE    : Eliminate much of the crapware that comes with Windows 10 and Windows 11, and disable or otherwise
#              mitigate certain baked-in telemetry items, to the greatest extent possible without breaking Windows.
#
# WARRANTY   : No warranty provided whatsoever. Use at your own risk. See license.

    ##################
  ######################
##########################
##########################
#### Development Only ####

$DebugPreference = "Continue"    # Normally SilentlyContinue
$VerbosePreference = "Continue"  # Normally SilentlyContinue

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

$scriptBanner = @"
	
  <><><><><><><><><><><><><><><><><><><><><><><><>
<><>                                            <><>
<>                   WinCleaner                   <>
<>      Clense Windows of telemtry and bloat      <>
<>                                                <>
<>    https://github.com/paulpfeister/sysbuild    <>
<><>                                            <><>
  <><><><><><><><><><><><><><><><><><><><><><><><>



"@

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

# Define options
$options = @{
    "OEM de-bloat (by name)" = $true
    "OEM de-bloat (by GUID)" = $true
    "Metro de-bloat, Microsoft (i.e. Mahjong)" = $true
    "Metro de-bloat, 3rd Party (i.e. LinkedIn)" = $true
    "Toolbar & BHO Removal (by GUID)" = $true
    "Remove OneDrive" = $true
    "Telemetry disable (quick)" = $true
    "Telemetry disable and dismantle (slow)" = $true
    "Disable system update services" = $false
    "Replace Edge with Firefox" = $false
    "Install winget" = $false
}

function DisplayMenu {
    $selectedIndex = 0
    $optionEntries = $options.GetEnumerator() | Sort-Object Name
    $buttonLabels = @("Begin", "Cancel")
    
    # Move cursor to the top of the console window
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    
    while ($true) {
        # Clear console window
        Clear-Host

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




$result = DisplayMenu
if ($result -eq "Begin") {
    Write-Host "Options after Begin:"
    $options.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }
} elseif ($result -eq "Cancel") {
    Write-Host "Cancel action selected."
} else {
    Write-Host "No action selected."
}

