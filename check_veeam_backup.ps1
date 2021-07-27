<#
  .SYNOPSIS
  Checks Veeam backup jobs.

  .DESCRIPTION
  This Plugin is capable to check the status of jobs and host backups inside a job.

  .PARAMETER Mode
  Choose between three modes:
    job_status: This mode checks if the job was successful and if the last run is older then the given days. (Default)
    host_backup: Check if the last backup of the hosts in the job are corrupted or inconsistent.
    all_jobs: This mode checks all jobs if they were successful. You can use the day thresholds like above. Prints the job with the worst status first. If one or more jobs are WARNING (or CRITICAL), the all over status is WARNING (or CRITICAL)

  .PARAMETER JobName
  Name of the VEEAM Backup Job

  .PARAMETER JobExclude
  Exclude given job name from being checked.

  .PARAMETER days_warning
  Issues a WARNING if the time of the last execution was longer than the specified number of days ago.

  .PARAMETER days_critical
  Issues a CRITICAL if the time of the last execution was longer than the specified number of days ago.

  .PARAMETER ShowDetails
  Choose any of this modes. Multiple choises are comma-separated:
    none:          Shows no details. (Default)
    all:           Shows all of the following options.
    latest_run:    Returns the number of days of the latest run of each job.
    last_status:   Shows last job result.
    last_failures: Shows the count of VMs wich was failed in the last session.
    last_warnings: Shows the count of VMs wich got a warning in the last session.

  .INPUTS
  None. You cannot pipe objects.

  .OUTPUTS
  Returns Nagios status code. Outputs multiple lines of text. Outputs no perfdata yet. See https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/pluginapi.html.

  .EXAMPLE
  PS> .\check_veeam_backup.ps1 -JobName 'ProdVMs' -Mode job_status -days_warning 2 -days_critical 4
  OK: Last Job result was successful: ProdVMs

  .EXAMPLE
  .\check_veeam_backup.ps1 -Mode "all_jobs"
  OK: Job is currently running: DevVMs - Last Job result was successful: ProdVMs - Job is currently running: TestVMs

  .EXAMPLE
  .\check_veeam_backup.ps1 -Mode "all_jobs"
  OK: Job is currently running: DevVMs - Last Job result was successful: ProdVMs - Job is currently running: TestVMs

  .EXAMPLE
  .\check_veeam_backup.ps1 -JobName 'ProdVMs' -Mode host_backup
  prod-node1 Last Backup is fine.
  test-prod-2 Last Backup is fine.
  windows-host1 Last Backup is fine.
  windows-host2 Last Backup is fine.
  foobar1 Last Backup is fine.
  icinga-master Last Backup is fine.
  icinga-satellite Last Backup is fine.
  db-server Last Backup is fine.
  OK: No Backups failed in job: ProdVMs

  .LINK
  Repository: https://git.geo.intranet.bs.ch/GeoDB/zabbix-checks/check_veeam_backup/check_veeam_backup.ps1

  .LINK
  Forked from: https://github.com/jonasboettcher/check_veeam_backup
#>

    [CmdletBinding()]

param(
    [Parameter(Mandatory = $true)] [String] $Mode = 'job_status',
    [Parameter(Mandatory = $false)][String] $JobName,
    [Parameter(Mandatory = $false)][String] $JobExclude,
    [Parameter(Mandatory = $false)][int]    $days_warning = 3,
    [Parameter(Mandatory = $false)][int]    $days_critical = 5,
    [Parameter(Mandatory = $false)][Array]  $ShowDetails = 'none'
)

$Verbosity = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent

. "$PSScriptRoot\nagios-utils.ps1"

try
{
    Write-Verbose "Load VEEAM Backup SnapIn"
    Add-PSSnapin VeeamPSSnapin;
}
catch
{
    Plugin-Exit $NagiosUnknown "Could not load VEEAM Backup SnapIn: $error"
}

try
{

    If ($Mode -eq 'all_jobs')
    {
        Write-Verbose "Mode=$Mode"
        $jobs = Get-VBRJob
    }
    ElseIf ($Mode -eq 'job_status')
    {
        Write-Verbose "Mode=$Mode"
        $jobs = Get-VBRJob -Name "$JobName"
    }

    $msg = @()

    ForEach ($job In $jobs)
    {
        if ($job.Name -ne $JobExclude)
        {

            if ($Verbosity)
            {
                $jobname = "$( $job.Name ) ($( $job.JobType ))"
            }
            else
            {
                $jobname = $job.Name
            }

            $latestrunNow = Get-Date -Format "yyyy-MM-dd"
            $latestrunDate = $job.LatestRunLocal
            $latestrunAge = (New-TimeSpan -Start $latestrunDate -End $latestrunNow).Days

            if ($ShowDetails -ne 'none') {
                $detailsMsg = @()
                if ('latest_run' -in $ShowDetails -or 'all' -in $ShowDetails) {
                    $detailsMsg += "latest run: $latestrunAge days ago" }
                if ('last_result' -in $ShowDetails -or 'all' -in $ShowDetails) {
                    $detailsMsg += "last result: $( $job.Info.LatestStatus )" }
                if ('last_failures' -in $ShowDetails -or 'all' -in $ShowDetails) {
                    $detailsMsg += "last failures: $( $job.FindLastSession().Info.Failures )" }
                if ('last_warnings' -in $ShowDetails -or 'all' -in $ShowDetails) {
                    $detailsMsg += "last failures: $( $job.FindLastSession().Info.Warnings )" }
                $detailsMsg = " ($( $detailsMsg -join ', ' ))"
            }

            Write-Verbose "DayDIFF $latestrunAge Lastjob $latestrunDate NOW: $latestrunNow"

            if ($job.IsRunning -eq $true)
            {
                $status = ($status, $NagiosOK | Measure-Object -Max).Maximum
                $msg += "Job is currently running: $jobname$detailsMsg"
            }
            elseif ( $job.FindLastSession().result -ne 'success')
            {
                $status = ($status, $NagiosCritical | Measure-Object -Max).Maximum
                $msg += "Last job result failed: $jobname$detailsMsg"
            }
            elseif ( $latestrunAge -gt $days_critical )
            {
                $status = ($status, $NagiosCritical | Measure-Object -Max).Maximum
                $msg += "Last job run is $latestrunAge days old: $jobname$detailsMsg"
            }
            elseif ( $latestrunAge -gt $days_warning )
            {
                $status = ($status, $NagiosWarning | Measure-Object -Max).Maximum
                $msg += "Last job run is $latestrunAge days old: $jobname$detailsMsg"
            }
            else
            {
                $status = ($status, $NagiosOK | Measure-Object -Max).Maximum
                $msg += "Last job result was successful: $jobname$detailsMsg"
            }
        }

    }
}
catch
{
    Plugin-Exit $NagiosUnknown "Get-VBRJob failed: $error"
}

try
{
    if ($Mode -eq 'host_backup')
    {
        Write-Verbose "Mode=$Mode"
        [Array]$output = @()

        $bkp_names = Get-VBRBackup -Name "$JobName" | Get-VBRRestorePoint -Name * | Select-Object Name -Unique

        ForEach ($bkp_name in $bkp_names)
        {
            $restorePoints = Get-VBRRestorePoint -Name $bkp_name.Name
            [Array]::Sort([array]$restorePoints.CreationUsn)
            $bkp = $restorePoints | Select-Object -Last 1

            $vm = $bkp.Name

            Write-Verbose "VM: $vm"
            Write-Verbose "CreationTime: $( $bkp.CreationTime )"
            Write-Verbose "Corrupted: $( $bkp.IsCorrupted )"
            Write-Verbose "Recheck: $( $bkp.IsRecheckCorrupted )"
            Write-Verbose "Consistent: $( $bkp.IsConsistent )"

            if ($bkp.IsCorrupted -eq $true -or $bkp.IsRecheckCorrupted -eq $true -or $bkp.IsConsistent -ne $true)
            {
                $failed = $true
                $output += "$vm Last Backup is corrupted or not consistent."
            }
            else
            {
                $output += "$vm Last Backup is fine."
            }
        }
        if ($failed -eq $true)
        {
            Plugin-Exit $NagiosCritical "Backups failed in job $JobName" ($output | out-String)
        }
        else
        {
            Plugin-Exit $NagiosOK "No Backups failed in job: $JobName" ($output | out-String)
        }
    }
}
catch
{
    Plugin-Exit $NagiosUnknown "Get Backup Jobs failed: $error"
}

Plugin-Exit $status "$( $msg -join ' - ' )"
