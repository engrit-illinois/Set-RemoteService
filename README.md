# Summary
A simplified wrapper for the Set-Service cmdlet for changing the Status and StartType of services on multiple remote machines.  

As of PowerShell 7, Set-Service no longer handles remote machines, so this script works around that.  

# Usage
1. Download `Set-RemoteService.psm1` to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Run it using the documentation and examples provided below.

# Examples

### Disable and then stop the CcmExec service on multiple machines
```powershell
Set-RemoteService -ComputerNameQuery "comp-name-*" -Service "CcmExec" -Status "Stopped" -StartType "Disabled"
```

### Enable and then start the CcmExec service on multiple machines
```powershell
Set-RemoteService -ComputerNameQuery "comp-name-*" -Service "CcmExec" -Status "Running" -StartType "Automatic"
```

# Parameters

# -ComputerNameQuery \<string[]\>
Mandatory string array.  
An array of strings representing wildcard queries for computer names in AD.  

# -SearchBase \<string\>
Optional string.  
The OUDN of an OU under which to limit the search for computers matching the given `-ComputerNameQuery`.  
Default is `OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu`.  

# -Service \<string\>
Mandatory string.  
The name of the target service.  
This is the executable name (without the extension), not the friendly displayname.  

# Status \<string\>
Optional string.  
The desired status of the target service after running the module.  
Must be either `Stopped` or `Running`.  
If omitted, the service status will not be changed.  

# StartType \<string\>
Optional string.  
The desired "Startup type" of the target service after running the module.  
Must be one of: `Automatic`, `AutomaticDelayedStart`, `Disabled`, `Manual`.  
If omitted, the service startup type will not be changed.  
`AutomaticDelayedStart` is only a valid option when the target endpoint is using PowerShell 7+. For endpoints using PowerShell 5.1, there's no easy way to configure this value, so it's not supported in this module. Use `Automatic` instead.  
As far as I can tell, `AutomaticDelayedStart` is really just a alias for `StartType` = `Automatic` plus `DelayedAutoStart` = `True`.  

# -Confirm
Optional switch.  
If specified, the user will NOT be prompted before continuing.  
If omitted, the user will be prompted before continuing, after the list of matching computers and the desired settings are displayed.  

# -PassThru
Optional switch.  
If specified, an array of PowerShell objects will be returned, which have more detailed information about what happened, in addition to the summary table logged to the console.  
If omitted, nothing is returned, besides the console logging.  

# Notes
- In Windows PowerShell (5.1) the `Set-Service` cmdlet does not have a `-Force` parameter. This means attempts to stop a service with `Set-Service -Status "Stopped"` can fail (such as when a service is dependent on other services). This module implements a custom workaround under the hood for that case, by running `Stop-Service -Force` instead.
- In all cases, the module first polls the target endpoints for the current status of the target service, then does the desired actions (if any were specified), and then polls for the status again. The initial and ending status are reported.
- You can see an endpoint's current service status without taking any actions by simply omitting both the `-Status` and `-StartType` parameters.
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.