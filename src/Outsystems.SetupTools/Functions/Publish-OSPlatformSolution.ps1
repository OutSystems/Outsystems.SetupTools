function Publish-OSPlatformSolution
{
    [CmdletBinding()]
    [OutputType('Outsystems.SetupTools.PublishResult')]
    param (
        [Parameter()]
        [ValidateNotNull()]
        [Alias('Host', 'Environment')]
        [string]$ServiceCenterHost = '127.0.0.1',

        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [string]$Solution,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [switch]$Wait
    )

    begin
    {
        LogMessage -Function $($MyInvocation.Mycommand) -Phase 0 -Stream 0 -Message "Starting"
        SendFunctionStartEvent -InvocationInfo $MyInvocation

        # Initialize the results object
        $publishResult = [pscustomobject]@{
            PSTypeName = 'Outsystems.SetupTools.PublishResult'
            PublishId  = 0
            Success    = $true
            ExitCode   = 0
            Message    = ''
        }
    }

    process
    {
        $publishId = 0

        # Check if file exists
        if (-not (Test-Path -Path $Solution))
        {
            LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 3 -Message "Cant find the solution file $Solution"
            WriteNonTerminalError -Message "Cant find the solution file $Solution"

            $publishResult.Success = $false
            $publishResult.ExitCode = -1
            $publishResult.Message = "Cant find the solution file $Solution"

            return $publishResult
        }

        # Check if file is OSP or OAP

        # Start deployment
        LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 0 -Message "Publishing solution $Solution"
        try
        {
            $publishId = PublishSolutionAsync -SCHost $ServiceCenterHost -File $Solution -Credential $Credential
        }
        catch
        {
            LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 3 -Message "Error starting to publish the solution $Solution" -Exception $_.Exception
            WriteNonTerminalError -Message "Error starting to publish the solution $Solution"

            $publishResult.Success = $false
            $publishResult.PublishId = $publishId
            $publishResult.ExitCode = -1
            $publishResult.Message = "Error starting to publish the solution $Solution"

            return $publishResult
        }

        # Check if publishId is valid
        if (-not $publishId -or ($publishId -eq 0))
        {
            LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 3 -Message "Error starting to publish the solution $Solution"
            WriteNonTerminalError -Message "Error starting to publish the solution $Solution"

            $publishResult.Success = $false
            $publishResult.ExitCode = -1
            $publishResult.Message = "Error starting to publish the solution $Solution"

            return $publishResult
        }

        # If wait switch is not specified just return the publish id
        if (-not $Wait.IsPresent)
        {
            LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 0 -Message "Deployment successfully started"

            $publishResult.Success = $false
            $publishResult.PublishId = $publishId
            $publishResult.Message = "Deployment successfully started"

            return $publishResult
        }

        # Check deployment status
        try
        {
            $result = GetPublishResult -SCHost $ServiceCenterHost -PublishId $publishId -Credential $Credential
        }
        catch
        {
            LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 3 -Message "Error checking the status of publication id $publishId" -Exception $_.Exception
            WriteNonTerminalError -Message "Error checking the status of publication id $publishId"

            $publishResult.Success = $false
            $publishResult.PublishId = $publishId
            $publishResult.ExitCode = -1
            $publishResult.Message = "Error checking the status of publication id $publishId"

            return $publishResult
        }

        switch ($result)
        {
            1
            {
                LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 0 -Message "Solution successfully published with warnings!!"
                $publishResult.PublishId = $publishId
                $publishResult.ExitCode = $result
                $publishResult.Message = "Solution successfully published with warnings!!"

                return $publishResult
            }
            2
            {
                LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 3 -Message "Error publishing the solution"
                WriteNonTerminalError -Message "Error publishing the solution"

                $publishResult.Success = $false
                $publishResult.PublishId = $publishId
                $publishResult.ExitCode = $result
                $publishResult.Message = "Error publishing the solution"

                return $publishResult
            }
        }

        LogMessage -Function $($MyInvocation.Mycommand) -Phase 1 -Stream 0 -Message "Solution successfully published"
        $publishResult.PublishId = $publishId
        return $publishResult
    }

    end
    {
        SendFunctionEndEvent -InvocationInfo $MyInvocation
        LogMessage -Function $($MyInvocation.Mycommand) -Phase 2 -Stream 0 -Message "Ending"
    }

}