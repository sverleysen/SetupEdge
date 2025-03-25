function New-EdgeProfile {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $customerName,
        [Parameter(Mandatory = $false)]
        [bool]
        $createBackup = $true,
        [Parameter(Mandatory = $false)]
        [bool]
        $useDefaultValues = $true
    )

    Write-Output "Creating Edge profile for $customerName"

    if ($PSVersionTable.PSEdition -ne "Core") {
        Write-Output "This script only works in PowerShell for Windows: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3"
        return
    }

    $profilePath = "profile-" + $customerName.replace(' ', '-')
    $proc = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--profile-directory=$profilePath --no-first-run --no-default-browser-check --flag-switches-begin --flag-switches-end --site-per-process" -PassThru

    Write-Output "Profile $customerName created, wait 15 seconds before closing Edge"

    Start-Sleep -Seconds 15 #it takes roughly 15 seconds to prepare the profile and write all files to disk.
    Stop-Process -Name "msedge"

    # Edit profile name
    $localStateFile = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"

    if ($createBackup) {
        $localStateBackUp = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State Backup"
        Copy-Item $localStateFile -Destination $localStateBackUp
    }

    $state = Get-Content -Raw $localStateFile
    $json = $state | ConvertFrom-Json

    $edgeProfile = $json.profile.info_cache.$profilePath

    Write-Output "Found profile $profilePath"
    Write-Output "Old profile name: $($edgeProfile.name)"

    $edgeProfile.name = $customerName
    $edgeProfile.shortcut_name = $customerName

    Write-Output "Write profile name to local state: $($edgeProfile.name)"

    # Only uncomment the next line if you know what you're doing!!
    $json | ConvertTo-Json -Compress -Depth 100 | Out-File $localStateFile

    Write-Output "Write profile name to registry: $($edgeProfile.name)"
    Push-Location
    Set-Location HKCU:\Software\Microsoft\Edge\Profiles\$profilePath
    Set-ItemProperty . ShortcutName "$customerName"
    Pop-Location

    Set-EdgePreferences $profilePath $useDefaultValues $createBackup
    Set-EdgeProfile $profilePath $useDefaultValues

    Write-Output "Done, you can start browsing with your new profile"

}

function Set-EdgePreferences {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $profilePath,
        [Parameter(Mandatory = $false)]
        [bool]
        $useDefaultValues = $true,
        [Parameter(Mandatory = $false)]
        [bool]
        $createBackup = $true
    )
    $preferenceSettings = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\$profilePath\Preferences"

    if ($createBackup) {
        $preferenceSettingsBackup = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\$profilePath\Preferences Backup"
        Copy-Item $preferenceSettings -Destination $preferenceSettingsBackup
    }
    $preferences = Get-Content -Raw $preferenceSettings
    $preferenceJson = $preferences | ConvertFrom-Json
    $confirmation;
    if ($useDefaultValues -eq $true) {
        $confirmation = 0;
    }
    else {
        $confirmation = AskQuestion "Hide sidebar?"
    }
    if ($confirmation -eq 0) {
        if ($null -eq $preferenceJson.browser.show_hub_apps_tower) {
            Write-Output "Sidebar is not set and turned on by default, lets disable it"

            $preferenceJson.browser | add-member -Name "show_hub_apps_tower" -value $false -MemberType NoteProperty
        }
        else {
            $sideBarToggle = $preferenceJson.browser.show_hub_apps_tower
            Write-Output "Sidebar is set to: $sideBarToggle lets make it false"
            $preferenceJson.browser.show_hub_apps_tower = $false #disable side bar
        }
    }
    $confirmation;
    if ($useDefaultValues -eq $true) {
        $confirmation = 0;
    }
    else {
        $confirmation = AskQuestion "Enable vertical tabs?"
    }
    if ( $confirmation -eq 0) {
        if ($null -eq $preferenceJson.edge.vertical_tabs) {
            Write-Output "Vertical tabs are turned off by default, lets enable it"
            $blockvalue = @"
            {
                "collapsed": true,
                "first_opened2": true,
                "opened": true
            }
"@

            $preferenceJson.edge | add-member -Name "vertical_tabs" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
        }
        elseif ($null -eq $preferenceJson.edge.vertical_tabs.collapsed) {
            Write-Output "Vertical tabs are turned off by default, lets enable it"

            $preferenceJson.edge.vertical_tabs | add-member -Name "collapsed" -value $true -MemberType NoteProperty
            $preferenceJson.edge.vertical_tabs | add-member -Name "first_opened2" -value $true -MemberType NoteProperty
            $preferenceJson.edge.vertical_tabs | add-member -Name "opened" -value $true -MemberType NoteProperty
        }
        else {
            $verticalTabs = $preferenceJson.edge.vertical_tabs.collapsed
            Write-Output "Vertical Tabs are set to: $verticalTabs, lets enable it"
            $preferenceJson.edge.vertical_tabs.collapsed = $true #enable vertical tabs
            $preferenceJson.edge.vertical_tabs.first_opened2 = $true #enable vertical tabs
            $preferenceJson.edge.vertical_tabs.opened = $true #enable vertical tabs
        }
    }

    if ($null -eq $preferenceJson.local_browser_data_share.enabled) {
        Write-Output "Disable data share between profiles"
        $blockvalue = @"
        {
            "enabled": false,
            "index_last_cleaned_time": "0"
        }
"@

        $preferenceJson | add-member -Name "local_browser_data_share" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
    }
    else {
        Write-Output "Disable data share between profiles"

        $preferenceJson.local_browser_data_share.enabled = $false; #disable sharing data between profiles
    }

    if ($null -eq $preferenceJson.edge_share) {
        Write-Output "Disable enhanced copy paste"
        $blockvalue = @"
        {
            "enhanced_copy_paste": {
                "default_url_format": 1,
                "enable_secondary_ecp": true
            }
        }
"@

        $preferenceJson | add-member -Name "edge_share" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
    }
    else {
        Write-Output "Disable enhanced copy paste"

        $preferenceJson.edge_share.enhanced_copy_paste.default_url_format = 1; #disable enhanced copy paste
    }

    if ($null -eq $preferenceJson.extensions.ui) {
        Write-Output "Chrome webstore is off by default, lets enable it"
        $blockvalue = @"
        {
            "allow_chrome_webstore": true
        }
"@
        $preferenceJson.extensions | add-member -Name "ui" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
    }
    else {
        $allowChrome = $preferenceJson.extensions.ui.allow_chrome_webstore
        Write-Output "Chrome webstore is set to: $allowChrome, lets enable it"
        $preferenceJson.extensions.ui.allow_chrome_webstore = $true #enable chome webstore
    }

    Write-Output "Write new settings to $($profilePath)"

    # Only uncomment the next line if you know what you're doing!!
    $preferenceJson | ConvertTo-Json -Compress -Depth 100 | Out-File $preferenceSettings
}

function Set-EdgeProfile {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $profilePath,
        [Parameter(Mandatory = $false)]
        [bool]
        $useDefaultValues = $true
    )

    Set-EdgeBookmarks $profilePath -useDefaultValues $useDefaultValues
    $proc = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--profile-directory=$profilePath --no-first-run --no-default-browser-check --flag-switches-begin --flag-switches-end --site-per-process" -PassThru
    Start-Sleep -Seconds 5 #allow edge to start up
    Set-EdgeExtensions -useDefaultValues $useDefaultValues
}

function Set-EdgeExtensions {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [bool]
        $useDefaultValues = $true
    )
    $confirmation;
    if ($useDefaultValues -eq $true) {
        $confirmation = 0;
    }
    else {
        $confirmation = AskQuestion "Add extensions?"
    }
    if ($confirmation -eq 0) {
        $edgeExtensions = @(
            'mdjlgdkgmhlmcikdmeehcecolehipicf', #LevelUp
            'jilmabbdmkbakhjganilpihpakkielnl', #PrettyJSON
            'mdjmgobkbnldmmchokoaefcaldhpdfoi', #SP Rest Json
            'bbcinlkgjjkejfdpemiealijmmooekmp' #Lastpass
        );
        $chromeExtensions = @(
            'bapdkmlgodmfeddcbminmghfndolfdcf' #Dynamics 365 Power Pane
        );

        foreach ($extension in $edgeExtensions) {
            [system.Diagnostics.Process]::Start("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "https://microsoftedge.microsoft.com/addons/detail/$extension");
        }
        foreach ($extension in $chromeExtensions) {
            [system.Diagnostics.Process]::Start("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "https://chrome.google.com/webstore/detail/$extension");
        }
        if ($personalEdgeExtensions) {
            foreach ($extension in $personalEdgeExtensions) {
                [system.Diagnostics.Process]::Start("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "https://microsoftedge.microsoft.com/addons/detail/$extension");
            }
        }
        if ($personalChromeExtensions) {
            foreach ($extension in $personalChromeExtensions) {
                [system.Diagnostics.Process]::Start("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "https://chrome.google.com/webstore/detail/$extension");
            }
        }
    }
}

function Set-EdgeBookmarks {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $profilePath,
        [Parameter(Mandatory = $false)]
        [bool]
        $useDefaultValues = $true
    )
    $confirmation;
    if ($useDefaultValues -eq $true) {
        $confirmation = 0;
    }
    else {
        $confirmation = AskQuestion "Add bookmarks";
    }
    if ($confirmation -eq 0) {

        $bookmarks = (iwr 'https://raw.githubusercontent.com/sverleysen/SetupEdge/main/Bookmarks').Content

        $profileFolder = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\$profilePath"

        new-item -Path $profileFolder -name "Bookmarks" -ItemType "file" -Value $bookmarks -Force
    }
}

function AskQuestion {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $question
    )
    $title = ''
    $choices = '&Yes', '&No'

    return $Host.UI.PromptForChoice($title, $question, $choices, 0)
}
