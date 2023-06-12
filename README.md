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
WIP

# Notes
- In Windows PowerShell (5.1) the `Set-Service` cmdlet does not have a `-Force` parameter. This means attempts to stop a service with `Set-Service -Status "Stopped"` can fail (such as when a service is dependent on other services). This module implements a custom workaround under the hood for that case, by running `Stop-Service -Force` instead.
- In all cases, the module first polls the target endpoints for the current status of the target service, then does the desired actions (if any were specified), and then polls for the status again. The initial and ending status are reported.
- You can see an endpoint's current service status without taking any actions by simply omitting both the `-Status` and `-StartType` parameters.
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.