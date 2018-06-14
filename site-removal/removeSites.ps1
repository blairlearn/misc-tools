<#
	Removes web sites from IIS and optionally deletes the site's physical folder code,
	associated AppPool and additional content directories.

	Site Removal

		Every site to be removed receives an entry in the <SiteList> structure.
		Set the attribute values as follows:
		
		name (required) - Contains the site's name from IIS configuration. (Not the host name.)
						  The sitelist powershell script can provide a list of valid site name's.

	    removeFiles (optional) - Controls deletion of the site's physical folder.  Set to one (1)
								to delete.
								
		removeAppPool (optional) - Controls deletion of the site's AppPool.  Set to one (1)
								to delete.


	Removing Additonal Directories

		Directories outside a site's direct file tree (e.g. the "PublishedContent" folder
		associated with a WCMS site) may be deleted by listing them as entries in the
		<DirectoryList> structure.

#>
$siteList = [xml]@"
<SiteList>
	<Site name="CDE CCOP Live" removeFiles="0" removeAppPool="1"/>
	<Site name="CDE CCOP Preview" removeFiles="0" removeAppPool="1" />
</SiteList>
"@

$directoryList = [xml]@"
<DirectoryList>
	<path>E:\Content\PercussionSites\CDESites\CCOP</path>
	<path>E:\publishing\PercussionSites\CDESites\CCOP</path>
</DirectoryList>
"@

$logFile = "" # Initially empty, set in Main().

function Main() {
	# The WebAdministration module requires elevated privileges.
	$isAdmin = Is-Admin
	if( $isAdmin ) {

		# Now that we know we're running, set up the log file.
		$logFile = GetOutputFileName

		WriteToConsoleAndLog "Starting..."
	Import-Module WebAdministration

	# Delete sites.
	foreach($site in $siteList.SiteList.Site) {
		RemoveSite $site.name $site.removeFiles $site.removeAppPool
	}

	# Delete extra paths
	foreach($path in $directoryList.Directorylist.path) {
		RemovePath $path
	}

		OutputDoneMessage $logFile

		} else {
		WriteToConsoleAndLog "This script must be run from an AA account." "red"
	}
}

<#
	Remove $siteName from IIS.
	
	$siteName - IIS name for the site to be removed.

	$removeFiles - If set to one (1), the site's physical directory is removed as well.
					(All other $removeFiles values are ignored.)

	$removeAppPool - If set to one (1), the site's associated AppPool is removed.
					(All other $removeFiles values are ignored.)
#>
function RemoveSite($siteName, $removeFiles, $removeAppPool) {

	WriteToConsoleAndLog "Deleting $siteName."
	
	# Get-WebSite always returns an array.
	$details = GetSiteDetails $siteName
	
	if( $details -ne $null ) {

		Stop-Website $details.Name

		if( $removeFiles -eq 1 ) {
			WriteToConsoleAndLog "Removing Site Folder."
			RemovePath $details.physicalPath
		} else {
			WriteToConsoleAndLog "Skipping Site Folder."
		}
		
		if( $removeAppPool -eq 1 ) {
			$removeAppPoolDetails = "Removing AppPool " + $details.applicationPool + ".";
			WriteToConsoleAndLog $removeAppPoolDetails
			Stop-WebAppPool $details.applicationPool
			Remove-WebAppPool $details.applicationPool
		} else {
			WriteToConsoleAndLog "Skipping AppPool."
			# If we're not removing the AppPool, bounce it.
			Restart-WebAppPool $details.applicationPool
		}
		
		# Remove the acutal site.
		Remove-WebSite $siteName
	} else {
		WriteToConsoleAndLog "Site $siteName not found." "red"
	}
}

<#
	Removes the directory $deletePath and all everything below it.
#>
function RemovePath($deletePath) {

	if( $deletePath -ne $null ) {
		Try {
			$deletePathDetails = 'Removing ' + $deletePath
			WriteToConsoleAndLog $deletePathDetails
			Remove-Item $deletePath -Recurse -Force -ErrorAction Stop
		}
		Catch {[System.SystemException]
			$deletePathDetails = 'Error removing "' + $deletePath + 
				'". Verify path name and check if files are open in another program.';
			WriteToConsoleAndLog $deletePathDetails "red"
		}
		
	} else {
		WriteToConsoleAndLog "RemovePath: Path must not be null." "red"
	}
}

<#
	Looks up IIS details for the site specified in $siteName.
	Returns null if the site is unknown.
#>
function GetSiteDetails( $siteName ) {
	# In PowerShell 2, Get-WebSite returns information for *all* sites, regardless of whether a
	# name is supplied, so we have to do the filtering ourselves. Web site names are unique,
	# and this is an "equals" check, so there's no way the filter will return more than one result.
	$details = Get-WebSite | where {$_.Name -eq $siteName}
	if($details -ne $null) {
		return $details
	} else {
		return $null
	}
}

<#
	Write script output to console and append to log file
	@param $logString - the text to be displayed
	@param $color - the text color for the console; defaults to green if none specified
#>
function WriteToConsoleAndLog($logString, $color) {
	# Print to screen
	if (-Not($color)) { $color = "green" }
	Write-Host $logString -foregroundcolor $color
	# Write to log file
	$timestamp = Get-Date -format "yyyy-MM-dd HH:mm:ss.fff";
	$logEntry = $timestamp + "`t" + $logString;
	Add-content $logFile -value $logEntry
}

<#
	Verify that the currently logged in user has administrator access.
#>
function Is-Admin {
 $id = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
 $id.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function OutputDoneMessage( $OutputFile ) {
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "===                       Successful Run"
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "===                 Please attach $OutputFile"
	Write-Host -foregroundcolor 'green' "===                        to the ticket"
	Write-Host -foregroundcolor 'green' "==="
	Write-Host -foregroundcolor 'green' "==========================================================================="
	Write-Host -foregroundcolor 'green' "==========================================================================="
}

function GetOutputFileName {
	$Computer = Get-WmiObject -Class Win32_ComputerSystem
	$name = "removeSites-" + $Computer.Name + ".log"

	# Create output file, overwrite an existing one.
	$junk = New-Item -Name $name -type File -force

	return $name
}

Main