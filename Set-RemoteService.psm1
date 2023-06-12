function Set-RemoteService {
	param(
		[Parameter(Position=0,Mandatory=$true)]
		[string[]]$ComputerNameQuery,
		
		[string]$SearchBase = "OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[Parameter(Mandatory=$true)]
		[string]$Service,
		
		[ValidateSet("Stopped","Started")]
		[string]$Status,
		
		[ValidateSet("Automatic","AutomaticDelayedStart","Disabled","Manual")]
		[string]$StartType,
		
		[switch]$Confirm
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
			$results = Get-ADComputer -SearchBase $SearchBase -Filter "name -like `"$query`"" -Properties *
			$allResults += @($results)
		}
		log "Computer names:" -L 1
		log $allResults -L 2
		$allResults
	}
	
	function Set-ServiceOnComp($comp) {
		Invoke-Command -ComputerName $comp -ArgumentList $Service,$Status,$StartType -ScriptBlock {
			param(
				[string]$Service,
				[string]$Status,
				[string]$StartType
			)
			
			function Get-ServiceState {
				Get-Service -Name $Service | Select *
			}
			
			function Set-ServiceOnComp {
				if($Status -or $StartupType) {
					$params = @{
						Name = $Service
					}
					if($Status) {
						$params.Status = $Status
					}
					if($StartupType) {
						$params.StartType = $StartType
					}
			
					Set-Service @params
				}
			}
							
			$state1 = Get-ServiceState
			#Set-ServiceOnComp
			$state2 = Get-ServiceState
			
			[PSCustomObject]@{
				State1 = $state1
				State2 = $state2
			}
		}
	}
	
	function Set-ServiceOnComps($comps) {
		log "Setting service on all computers..."
		
		$comps | ForEach-Object {
			$comp = $_
			log $comp -L 1
			$state = Set-ServiceOnComp $comp
			
			log "Initial state:" -L 2
			log "Status: `"$($state.State1.Status)`"" -L 3
			log "StartType: `"$($state.State1.StartType)`"" -L 3
			log "Desired state:" -L 2
			log "Status: `"$Status`"" -L 3
			log "StartType: `"$StartType`"" -L 3
			log "Final state:" -L 2
			log "Status: `"$($state.State2.Status)`"" -L 3
			log "StartType: `"$($state.State2.StartType)`"" -L 3
			
			$state
		}
	}
	
	function Confirm-Continue {
		log "Confirming intention..."
		
		if($Status -or $StartType) {
			if($Confirm) {
				log "-Confirm was specified. Continuing." -L 1
			}
			else {
				log "Desired state:" -L 1
				log "Status: `"$Status`"" -L 2
				log "StartType: `"$StartType`"" -L 2
				log "Are you sure you want to continue? Enter 'Y' to confirm" -L 1 -NoNewLine
				$input = Read-Host
				if($input.ToLower() -eq "y") {
					$confirmed = $true
					log "User confirmed. Continuing."
				}
				else {
					log "User did not confirm. Aborting."
				}
			}
		}
		else {
			log "-Status and -StartType are both unspecified. No changes will be made."
			$confirmed = $true
		}
		
		$confirmed
	}
	
	function Do-Stuff {
		$comps = Get-Comps
		if(Confirm-Continue) {
			$states = Set-ServiceOnComps $comps
		}
	}
	
	Do-Stuff
	
	log "EOF"
}