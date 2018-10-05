param(
    [Parameter(Mandatory = $true)][ValidateSet('DC', 'LT', 'FE')][string]$OSRole
)

# -- Prompt for Service Center and DB SA credentials
$SCCreds = Get-Credential -Message 'Service Center credentials'
$DBCreds = Get-Credential -Message 'Database Admin credentials'

# -- Stop script on any error
$global:ErrorActionPreference = 'Stop'

# -- Import module from Powershell Gallery
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force  | Out-Null
Install-Module -Name Outsystems.SetupTools -Force -MinimumVersion 2.2.0.0 | Out-Null
Import-Module -Name Outsystems.SetupTools -MinimumVersion 2.2.0.0 -ArgumentList $true, 'UpdateOS' | Out-Null

# -- Get platform major version
$OSServerVersion = Get-OSServerVersion
if (-not $OSServerVersion) { throw "Platform not installed" }
$OSServerMajorVersion = "$(([System.Version]$OSServerVersion).Major).$(([System.Version]$OSServerVersion).Minor)"

# -- Check if update is needed
if ($OSServerVersion -ge $(Get-OSRepoAvailableVersions -Application 'PlatformServer' -MajorVersion $OSServerMajorVersion -Latest))
{
    Write-Output 'Platform is up to date'
    exit 0
}

# -- Before updating lets refresh outdated modules
Get-OSPlatformModules -Credential $SCCreds -PassThru -Filter {$_.StatusMessages.Id -eq 6} | Publish-OSPlatformModule -Wait -Verbose | Out-Null

# -- And finally, lets check if the factory is consistent
if (Get-OSPlatformModules -Credential $SCCreds -PassThru -Filter {$_.StatusMessages.Count -ne 0}) { throw "Factory is inconsistent. Aborting the update." }

# -- Stop OS Services for the update. Configuration tool will restart them after the update
Stop-OSServerServices -Verbose

# -- Install PreReqs (this is supposedly not needed since we are updating the same major)
Install-OSServerPreReqs -MajorVersion $OSServerMajorVersion -Verbose | Out-Null

# -- Download and install OS Server and Dev environment from repo
Install-OSServer -Version $(Get-OSRepoAvailableVersions -Application 'PlatformServer' -MajorVersion $OSServerMajorVersion -Latest) -Verbose | Out-Null
Install-OSServiceStudio -Version $(Get-OSRepoAvailableVersions -Application 'ServiceStudio' -MajorVersion $OSServerMajorVersion -Latest) -Verbose | Out-Null

# -- Run the configuration tool with the existing parameters
Set-OSServer -Apply -Credential $DBCreds -Verbose | Out-Null

if ($OSRole -ne 'FE')
{
    # -- Update Service Center and System Components
    Install-OSPlatformServiceCenter -Verbose | Out-Null
    Publish-OSPlatformSolution -Credential $SCCreds -Solution $("$(Get-OSServerInstallDir)\System_Components.osp") -Wait -Verbose | Out-Null

    if ($OSRole -eq 'LT')
    {
        Publish-OSPlatformSolution -Credential $SCCreds -Solution $("$(Get-OSServerInstallDir)\LifeTime.osp") -Wait -Verbose | Out-Null
    }

    # -- Re-Publish needed modules
    Get-OSPlatformModules -Credential $SCCreds -PassThru -Filter {$_.StatusMessages.Id -eq 13} | Publish-OSPlatformModule -Wait -Verbose | Out-Null
}

# -- Re-apply System tunning and security settings
Set-OSServerPerformanceTunning -Verbose | Out-Null
Set-OSServerSecuritySettings -Verbose | Out-Null
