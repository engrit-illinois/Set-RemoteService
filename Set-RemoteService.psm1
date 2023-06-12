function Set-RemoteService {
	param(
		[Parameter(Position=0,Mandatory=$true)]
		[string[]]$ComputerNameQuery,
		
		[string]$SearchBase = "OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[Parameter(Mandatory=$true)]
		[string]$Service,
		
		[ValidateSet("Stopped","Running")]
		[string]$Status,
		
		[ValidateSet("Automatic","AutomaticDelayedStart","Disabled","Manual")]
		[string]$StartType,
		
		[switch]$Confirm,
		
		[switch]$PassThru
	)
	
	function log {
		param(
			[string]$Msg,
			[int]$L,
			[switch]$NoNewLine
		)
		
		$indent = ""
		for($i = 0; $i -lt $L; $i +=1) {
			$indent = "    $indent"
		}
		
		$ts = Get-Date -Format "HH:mm:ss"
		
		$msg = "[$ts]$indent $msg"
		
		$params = @{
			Object = $msg
		}
		if($NoNewLine) {
			$params.NoNewLine = $true
		}
		
		Write-Host @params
	}
	
	function Get-Comps {
		log "Getting computer names from AD..."
		$allResults = @()
		$ComputerNameQuery | ForEach-Object {
			$results = Get-ADComputer -SearchBase $SearchBase -Filter "name -like `"$_`"" -Properties *
			$allResults += @($results)
		}
		if($allResults) {
			if($allResults.count -lt 0) {
				log "No matching computers found in AD!" -L 1
			}
			else {
				log "Computer names:" -L 1
				log $allResults -L 2
			}
		}
		else {
			log "No matching computers found in AD!" -L 1
		}
		
		$allResults
	}
	
	function Set-ServiceOnComp($comp) {
		
		$scriptBlock = {
			param(
				[string]$Service,
				[string]$Status,
				[string]$StartType
			)
			
			function Get-ServiceState {
				Get-Service -Name $Service | Select *
			}
			
			function Set-StartType($params) {
				if($StartType) {
					# "StartType" is the canonical property name, in both PS 7 and 5.1. "StartupType" is an alias only in PS 7. And "StartMode" is not a property alias.
					# However "-StartupType" is the canonical _parameter_ name for *-Service cmdlets in both 7 and 5.1. "-StartMode" is an alias in both PS 7 and 5.1. And "StartType" is an alias only in PS 7.
					# So, to be safe in both PS 7 and 5.1, always reference the "StartType" property, and always use the "StartupType" parameter.
					# Additionally, the value "AutomaticDelayedStart" is only available PS 7, where it _really_ means StartType = Automatic and DelayedAutoStart = True. DelayedAutoStart does not appear to be exposed at all in PS 5.1.
					$params.StartupType = $StartType
					
					try {
						$result = Set-Service @params
					}
					catch {
						$err = $_
					}
					
					[PSCustomObject]@{
						Result = $result
						Error = $err
						ErrorMsg = $err.Exception.Message
					}
				}
			}
			
			function Set-Status {
				if($Status) {
					$params.Status = $Status
					
					try {
						$result = Set-Service @params
					}
					catch {
						$err = $_
					}
					
					if($err) {
						if(
							($Status -eq "Stopped") -and
							($err.Exception.Message -like "*Cannot stop service * because it is dependent on other services*")
						) {
						
							# Set-Service in PS 5.1 doesn't have a -Force parameter, so we'll have to do it manually with Stop-Service
							try {
								$stopResult = Stop-Service -Name $Service -Force -PassThru
							}
							catch {
								$stopErr = $_
							}
							
							$result = $stopResult
							$err = $stopErr
						}
					}
					
					[PSCustomObject]@{
						Result = $result
						Error = $err
						ErrorMsg = $err.Exception.Message
					}
				}
			}
			
			function Set-ServiceOnComp {
				$params = @{
					Name = $Service
					ErrorAction = "Stop"
					PassThru = $true
				}
				
				# Doing these separately because it makes the logic simpler due to changing the fact that changing the StartType is simple, while stopping a service can run into issues and needs more logic.
				$startTypeResult = Set-StartType $params
				$statusResult = Set-Status
				
				[PSCustomObject]@{
					StartTypeResult = $startTypeResult
					StartTypeError = $startTypeResult.Error
					StartTypeErrorMsg = $startTypeResult.ErrorMsg
					StatusResult = $statusResult
					StatusError = $statusResult.Error
					StatusErrorMsg = $statusResult.ErrorMsg
				}
			}
							
			$initialState = Get-ServiceState
			$result = Set-ServiceOnComp
			$endState = Get-ServiceState
			
			$result | Add-Member -NotePropertyName "InitialState" -NotePropertyValue $initialState
			$result | Add-Member -NotePropertyName "EndState" -NotePropertyValue $endState
			
			$result
		}
		
		try {
			$state = Invoke-Command -ComputerName $comp.Name -ArgumentList $Service,$Status,$StartType -ScriptBlock $scriptBlock -ErrorAction "Stop"
		}
		catch {
			$err = $_
		}
		
		[PSCustomObject]@{
			Name = $comp.Name
			InitialState = $state.InitialState
			InitialStartType = Translate-State "StartType" $state.InitialState.StartType
			InitialStatus = Translate-State "Status" $state.InitialState.Status
			StartTypeResultState = $state.StartTypeResult
			StartTypeResultStartType = Translate-State "StartType" $state.StartTypeResult.StartType
			StartTypeResultStatus = Translate-State "Status" $state.StartTypeResult.Status
			StatusResultState = $state.StatusResult
			StatusResultStartType = Translate-State "StartType" $state.StatusResult.StartType
			StatusResultStatus = Translate-State "Status" $state.StatusResult.Status
			EndState = $state.EndState
			EndStartType = Translate-State "StartType" $state.EndState.StartType
			EndStatus = Translate-State "Status" $state.EndState.Status
			InvokeError = $err
			InvokeErrorMsg = $err.Exception.Message
			StartTypeError = $state.StartTypeError
			StartTypeErrorMsg = $state.StartTypeErrorMsg
			StatusError = $state.StatusError
			StatusErrorMsg = $state.StausErrorMsg
		}
	}
	
	function Translate-State($type, $value) {
		if($value) {
			if($value -is [int]) {
				switch($type) {
					"StartType" {
						# https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicestartmode?view=dotnet-plat-ext-7.0
						switch($value) {
							0 { "Boot" }
							1 { "System" }
							2 { "Automatic" }
							3 { "Manual" }
							4 { "Disabled" }
							default { "Unrecognized value" }
						}
					}
					"Status" {
						# https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontrollerstatus?view=dotnet-plat-ext-7.0
						switch($value) {
							1 { "Stopped" }
							2 { "StartPending" }
							3 { "StopPending" }
							4 { "Running" }
							5 { "ContinuePending" }
							6 { "PausePending" }
							7 { "Paused" }
							default { "Unrecognized value" }
						}
					}
				}
			}
			else {
				$value
			}
		}
	}
	
	function Set-ServiceOnComps($comps) {
		log "Setting service on all computers..."
		
		$comps | ForEach-Object {
			$comp = $_
			log $comp.Name -L 1
			Set-ServiceOnComp $comp
		}
	}
	
	function Confirm-Continue {
		log "Confirming intention..."
		
		if($Status -or $StartType) {
			if($Confirm) {
				log "-Confirm was specified. Continuing." -L 1
				$confirmed = $true
			}
			else {
				log "Service: `"$Service`"" -L 1
				log "Desired state:" -L 1
				log "Status: `"$Status`"" -L 2
				log "StartType: `"$StartType`"" -L 2
				log "Are you sure you want to continue? Enter 'Y' to confirm: " -L 1 -NoNewLine
				$input = Read-Host
				if($input.ToLower() -eq "y") {
					log "User confirmed. Continuing." -L 2
					$confirmed = $true
				}
				else {
					log "User did not confirm. Aborting." -L 2
				}
			}
		}
		else {
			log "-Status and -StartType are both unspecified. No changes will be made." -L 1
			$confirmed = $true
		}
		
		$confirmed
	}
	
	function Report-States($states) {
		$output = $states | Select Name,InitialStatus,InitialStartType,EndStatus,EndStartType,InvokeErrorMsg,StartTypeErrorMsg,StatusErrorMsg | Sort Name | Format-Table * | Out-String
		Write-Host $output
	}
	
	function Do-Stuff {
		$comps = Get-Comps
		if($comps) {
			if(Confirm-Continue) {
				$states = Set-ServiceOnComps $comps
				if($states) {
					Report-States $states
				}
				if($PassThru) {
					$states
				}
			}
		}
	}
	
	Do-Stuff
	
	log "EOF"
}