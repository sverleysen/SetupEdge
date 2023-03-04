A PowerShell script to setup Edge Profiles

Most of the work is done by [Albert-Jan Schot](https://github.com/appieschot) and described in a [blogpost](https://www.cloudappie.nl/create-configure-edge-profiles-powershell/).

I wanted to extend this with some default browser extensions and bookmarks and make it easy to use for my colleagues.

---
**NOTE**

Use it at your own risk. If the script fails, your existing profiles are gone. You can manually restore it by replacing the file `%LOCALAPPDATA%\Microsoft\Edge\User Data\Local State` with `%LOCALAPPDATA%\Microsoft\Edge\User Data\Local State Backup`

---
# Installation
To use this follow the next steps:
* open PowerShell
* run command `code $profile`
* add the following line of code at the end of the file. It will always get the latest version of the script when you startup PowerShell.
``` powershell
iex (iwr 'https://raw.githubusercontent.com/sverleysen/SetupEdge/main/Setup-EdgeProfiles.ps1').Content
```
* *Optional:* add the following code block to install additional browser extensions. To get the extension id, open an extension in the store and copy the last part of the url.
``` powershell
$personalEdgeExtensions = @(
    "extension id"
);
$personalChromeExtensions = @(
    "extension id"
);
```
* run command `. $profile` to reload the settings.

# Usage
## New-EdgeProfile
It will create a new Edge profile, do some default settings, set default bookmarks and load browser extensions(that still needs to be installed manually)

---
**NOTE**

In the process of creating the new profile, it will kill the Edge process, so all your Edge browsers will be closed

---

``` powershell
New-EdgeProfile Customer1
```

## Set-EdgePreferences
It will apply all the settings, bookmarks and extensions to an existing profile

## Set-EdgeProfile
It will apply bookmarks and extensions to an existing profile

## Set-EdgeExtensions
It will load extensions to an existing profile (that still needs to be installed manually)

## Set-EdgeBookmarks
It will load bookmarks to an existing profile