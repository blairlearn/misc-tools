function Main() {
	# The WebAdministration module requires elevated privileges.
	$isAdmin = Is-Admin
	if( $isAdmin ) {
		Write-Host -foregroundcolor 'green' "Starting..."
		Import-Module WebAdministration
		$OutputFile = GetOutputFile
		GetSiteNames $OutputFile
		GetAppPools $OutputFile
		OutputDoneMessage $OutputFile
	} else {
		Write-Host -foregroundcolor 'red' "This script must be run from an account with elevated privileges."
	}
}


function GetSiteNames( $OutputFile ) {
	Write-Host -foregroundcolor 'green' "Collecting site names."

	# Write Headings in a tab-delimited manner.
	Add-Content $OutputFile -Value "Name`tID`tPath`tbinding"

	# Get a list of sites, with all of their bindings
	Get-WebSite | foreach {
		$text = "`"" + $_.Name + "`"`t" + $_.ID + "`t`"" + $_.physicalPath + "`""
		
		$_.bindings.collection | foreach {
			$localText = $text + "`t" + $_
			Add-Content $OutputFile -Value $localText
		}
	}

	Write-Host -foregroundcolor 'green' "Done."
}

function GetAppPools( $OutputFile ) {
	Write-Host -foregroundcolor 'green' "Collecting site names."

	# Write Headings in a tab-delimited manner.
	Add-Content $OutputFile -Value "`nName`tPipelineMode`tRuntimeVersion`tApplication"

	Get-ChildItem IIS:\AppPools | foreach {
		$text = "`"" + $_.Name + "`"`t" + $_.managedPipelineMode + "`t" + $_.managedRuntimeVersion
		
		# Get the list of associated application names.
		$appList = GetApplicationList $_.Name
		if( $appList.Length -gt 0 ) {  # Applications exist.
			foreach($app in $appList) {
				$localText = $text + "`t`"" + $app + "`""
				Add-Content $OutputFile -Value $localText
			}
		} else {  # No associated applications.
			$text += "`t`"(none)`""
			Add-Content $OutputFile -Value $text
		}
	}
	
	Write-Host -foregroundcolor 'green' "Done."
}

<#
	The list of applications which use a given appPool isn't a property of the
	appPool itself.  This information is actually calculated from the system configuration.
	GetApplicationList finds the sites and applications belonging to $appPoolName and
	returns a list of their names.
	
	Based on: http://stackoverflow.com/a/20751426/282194
#>
function GetApplicationList( $appPoolName ) {
	$pn = $appPoolName
    $sites = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$pn`'and @path='/']/parent::*" machine/webroot/apphost -name name
    $apps = get-webconfigurationproperty "/system.applicationHost/sites/site/application[@applicationPool=`'$pn`'and @path!='/']" machine/webroot/apphost -name path
    $arr = @()
	$output = @()
    if ($sites -ne $null) {$arr += $sites}
    if ($apps -ne $null) {$arr += $apps}
    if ($arr.Length -gt 0) {
      foreach ($s in $arr) { $output += $s.Value }
    }

	return $output
}

function GetOutputFile {
	$Computer = Get-WmiObject -Class Win32_ComputerSystem
	$name = $Computer.Name + ".txt"

	# Create output file, overwrite an existing one.
	$junk = New-Item -Name $name -type File -force

	return $name
}

function OutputDoneMessage( $OutputFile ) {
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "===                       Successful Run"
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "===                 Output is in $OutputFile"
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==========================================================================="
}

function Is-Admin {
 $id = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
 $id.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

Main