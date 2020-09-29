<#----Start Header Section----
.SYNOPSIS
    This script checks to see if service is stopped and attempts to start it.
.DESCRIPTION
    This script checks to see if a service is stopped on the local or remote
        computer and logs the results in either the Application or System event logs.

    One can set number of times to try starting a service.  It will wait 20 seconds
        between attempts.

    One can have the computer be rebooted if the service does not start successfully.

    If logging is enabled (it is by default), events will be logged on the computer
        the script is being run from and on the computer it is being run against.
        The Source of the event is PowerShell and the event IDs and 
        messages are as follows:
            0 - "Service $Service does not exist"
            1 - "Service $Service Started"
            2 - "Service $Service failed to start on"
            3 - "Unable to connect to $ComputerName"
            4 - "Restarting $ComputerName"
            5 - "Service successfully started after reboot" - Only used when running script
                against remote computer
            6 - "Service failed to start after reboot" - Only used when running script
                against remote computer
            7 - "Service status is unable to be determined after reboot" - Only used when running script
                against remote computer
            8 - "Rebooting Computer to see if $Service will start" - Only used when running script
                locally
.PARAMETER Service
    Specifies the name of the service to run the script against.
    This parameter is Mandatory.
    Alias for this parameter is s
.PARAMETER ComputerName
    Specifies the name of the computer the service is on.
    This parameter is optional.
    Alias for this parameter is cn
.PARAMETER Reboot
    Specifies whether to reboot the computer if the service does not start.
    This parameter is optional.
    Valid values for this parameter:
        False       -Default
        True
        0
        1
        Yes
        No
    Alias for this parameter is r
.PARAMETER Tries
    Specifies the number of times to try and start the service.
    This parameter is optional.
    Valid values for this parameter:
        1           -Default
        2
        3
        4
    Alias for this parameter is t
.PARAMETER Logging
    Specifies whether to log results or not.
    This parameter is optional.
    Valid values for this parameter:
        False
        True        -Default
        0
        1
        Yes
        No
    Alias for this parameter is l
.PARAMETER EventLog
    Specifies what eventlog to send results to.
    This parameter is optional.
    Valid values for this parameter:
        Application  -Default
        System
    Alias for this parameter is e
.EXAMPLE
    PS C:\PSScript > .\CheckStart-Service.ps1 -Service "Print Spooler" -ComputerName server1 -Reboot yes

    This will try to start the service 1 time and reboot the computer if it is unsuccessful.
        Events will be logged in the Application log.
.EXAMPLE
    PS C:\PSScript > .\CheckStart-Service.ps1 -Service "Print Spooler" -ComputerName server1 -Tries 3

    This will try to start the service 3 times. Events will be logged in the Application log.
.EXAMPLE
    PS C:\PSScript > .\CheckStart-Service.ps1 -Service "Print Spooler" -ComputerName server1 -Tries 3 -Logging No

    This will try to start the service 3 times. Events will not be logged.
.INPUTS
	None.  You cannot pipe objects to this script.
.OUTPUTS
	No objects are output from this script.  This script creates a plain text document.
.NOTES
    NAME: CheckStart-Service.ps1
    AUTHOR: David Prows
    VERSION: 1.1
    LASTEDIT: September 29, 2020
-----End Header Section-----#>
#--------Start Parameters section--------------

Param(
    [parameter(Mandatory=$true)]
    [alias("s")]
    [string]
    $Service=""
,
    [parameter(Mandatory=$false)]
    [alias("cn")]
    [string]
    $ComputerName=""
,
    [parameter(Mandatory=$false)]
    [ValidateSet("True","False",0,1,"Yes","No")]
    [alias("r")]
    [string]
    $Reboot="False"
,
    [parameter(Mandatory=$false)]
    [ValidateSet(1,2,3,4)]
    [alias("t")]
    [int]
    $Tries=1
,
    [parameter(Mandatory=$false)]
    [ValidateSet("True","False",0,1,"Yes","No")]
    [alias("l")]
    [string]
    $Logging="True"
,
    [parameter(Mandatory=$false)]
    [ValidateSet("Application","System")]
    [alias("e")]
    [string]
    $EventLog="Application"
)
#--------End Parameters section----------------

# Function to convert string to boolean
function ConvertStringToBoolean ([string]$value)
{
    $value = $value.ToLower();

    switch ($value)
    {
        "true" { return $true; }
        "1" { return $true; }
        "yes" { return $true; }
        "false" { return $false; }
        "0" { return $false; }
        "no" { return $false; }
    }
}

#---------Start Variables to Configure---------
$EventSource = "CheckStart-Service"
$Log = ConvertStringToBoolean($Logging)
$Restart = ConvertStringToBoolean($Reboot)
$i = $Tries
#---------End Variables to Configure-------------

if (-not ([string]::IsNullOrWhiteSpace($ComputerName)))
{
    if (Test-Connection -ComputerName $ComputerName -Quiet)
    {
        if (Get-Service -ComputerName $ComputerName $Service -ea 0)
        {
            # Setup logging if $Logging is enabled
            if ($Log -eq $true)
            {
                # Add Event Source on local machine if it doesn't exist
                New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue

                # Add Event Source on remote machine if it doesn't exist
                New-EventLog -LogName $EventLog -Source $EventSource -ComputerName $ComputerName -ErrorAction SilentlyContinue
            }

            while (($i -gt 0) -and ((Get-Service -ComputerName $ComputerName $Service).Status -eq 'Stopped'))
            {
                # Start Service
                Get-Service -ComputerName $ComputerName $Service | Start-Service -ErrorAction SilentlyContinue

                # Wait 20 seconds for service to start
                Start-Sleep 20

                # If logging enabled, then log results
                if ($Log -eq $true)
                {
                    # If service didn't start, log it
                    if ((Get-Service -ComputerName $ComputerName $Service).Status -eq 'Stopped')
                    {
                        # Log event on remote computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 2 `
                            -Message "Service $Service failed to start on $ComputerName" -ComputerName $ComputerName

                        # Log event on local computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 2 `
                            -Message "Service $Service failed to start on $ComputerName"
                    }
                    # If service started, log it
                    elseif ((Get-Service -ComputerName $ComputerName $Service).Status -eq 'Running')
                    {
                        # Log event on remote computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 1 `
                            -Message "Service $Service Started on $ComputerName" -ComputerName $ComputerName
                        
                        # Log event on local computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 1 `
                        -Message "Service $Service Started on $ComputerName"
                    }
                }

                # Decrement # of tries
                $i--
            }

            # Check if service didn't start and reboot if $Reboot is set to true (default value is false)
            if ((Get-Service -ComputerName $ComputerName $Service).Status -eq 'Stopped' -and ($Restart -eq $true)) 
            {
                # Send Restart command to computer and wait up to 5 minutes for it to come up
                Restart-Computer -ComputerName $ComputerName -Wait -For PowerShell -Timeout 300 -Delay 2

                # If logging enabled, then log results
                if ($Log -eq $true)
                {
                    # Log event on remote computer
                    Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 4 `
                        -Message "Successfully restarted $ComputerName" -ComputerName $ComputerName
                    
                    # Log event on local computer
                    Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 4 `
                        -Message "Successfully restarted $ComputerName"
                    
                    # Wait 20 seconds for service to start
                    Start-Sleep 20
                    
                    # Check status of service
                    $ServiceStatus = (Get-Service -ComputerName $ComputerName $Service).Status

                    # If service is running, log that it successfully started
                    if ($ServiceStatus -eq 'Running')
                    {
                        # Log status of service on remote computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 5 `
                            -Message "Service successfully started after reboot of $ComputerName" -ComputerName $ComputerName
                        
                        # Log status of service on local computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 5 `
                            -Message "Service successfully started after reboot of $ComputerName"
                    }
                    # If service is stopped, log that it failed to start
                    elseif ($ServiceStatus -eq 'Stopped')
                    {
                        # Log status of service on remote computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 6 `
                            -Message "Service failed to start after reboot of $ComputerName" -ComputerName $ComputerName
                        
                        # Log status of service on local computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 6 `
                            -Message "Service failed to start after reboot of $ComputerName"
                    }
                    else
                    {
                        # Log status of service on remote computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 7 `
                            -Message "Service status is unable to be determined after reboot of $ComputerName" -ComputerName $ComputerName
                        
                        # Log status of service on local computer
                        Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 7 `
                            -Message "Service status is unable to be determined after reboot of $ComputerName"
                    }
                }
            }
        }
        else
        {
            # Log event on remote computer
            Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 0 `
                -Message "Service $Service does not exist on $ComputerName" -ComputerName $ComputerName

            # Log event on local computer
            Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 0 `
                -Message "Service $Service does not exist on $ComputerName"
        }
    }
    else
    {
        if ($Log -eq $true)
        {
            # Add Event Source on local machine if it doesn't exist
            New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
            
            # Log event on local computer
            Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 3 `
            -Message "Unable to connect to $ComputerName"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ComputerName))
{
    if (Get-Service $Service -ea 0)
    {
        # Setup logging if $Logging is enabled
        if ($Log -eq $true)
        {
            # Add Event Source on local machine if it doesn't exist
            New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
        }
        while (($i -ne 0) -and ((Get-Service $Service).Status -eq 'Stopped'))
        {
            # Start Service
            Start-Service $Service -ErrorAction SilentlyContinue

            # Wait 20 seconds for service to start
            Start-Sleep 20

            # If service didn't start, log it
            if ((Get-Service $Service).Status -eq 'Stopped')
            {
                # Log event on local computer
                Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 2 `
                    -Message "Service $Service failed to start"
            }
            
            # If service started, log it
            elseif ((Get-Service $Service).Status -eq 'Running')
            {
                # Log event on local computer
                Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 1 `
                -Message "Service $Service Started"
            }

            # Decrement # of tries
            $i--
        }

        # Check if service didn't start and reboot if $Reboot is set to true (default value is false)
        if ((Get-Service $Service).Status -eq 'Stopped' -and ($Restart -eq $true)) 
        {
            # Send Restart command to computer
            Restart-Computer -Delay 10

            # If logging enabled, then log results
            if ($Log -eq $true)
            {
                # Log event on local computer
                Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 8 `
                    -Message "Rebooting Computer to see if $Service will start"
            }
        }
    }
    else
    {
        if ($Log -eq $true)
        {
            # Add Event Source on local machine if it doesn't exist
            New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue

            # Log event on local computer
            Write-EventLog -LogName "$EventLog" -Source $EventSource -EventId 0 `
                -Message "Service $Service does not exist"
        }
    }
}