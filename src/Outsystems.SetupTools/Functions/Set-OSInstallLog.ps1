function Set-OSInstallLog
{
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    <#
    .SYNOPSIS
    Sets the log file location.

    .DESCRIPTION
    This will set the name and location where the log file will be stored.
    By default, the log will have the verbose stream. If you set the -LogDebug switch it will also contain the debug stream.

    .PARAMETER Path
    The log file path. The function will try to create the path if not exists.

    .PARAMETER File
    The log filename.

    .PARAMETER LogDebug
    If should log also the debug stream

    .EXAMPLE
    Set-OSInstallLog -Path $ENV:Windir\temp -File Install.log -LogDebug

    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$File,

        [Parameter()]
        [switch]$LogDebug
    )
    begin
    {
        SendFunctionStartEvent -InvocationInfo $MyInvocation
    }

    process
    {
        If ( -not (Test-Path -Path $Path))
        {
            try
            {
                New-Item -Path $Path -ItemType directory -Force -ErrorAction Stop | Out-Null
            }
            catch
            {
                WriteNonTerminalError -Message "Error creating the log file location"

                return
            }
        }

        $Script:OSLogFile = "$Path\$File"
        $Script:OSLogDebug = $LogDebug
    }

    end
    {
        SendFunctionEndEvent -InvocationInfo $MyInvocation
        LogMessage -Function $($MyInvocation.Mycommand) -Phase 2 -Stream 0 -Message "************* Starting Log **************"
    }
}
