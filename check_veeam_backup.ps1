<#
.NAME
check_veeam_backup
.SYNOPSIS
Checks the backup
.SYNTAX
check_veeam_backup -Mode <job_status,host_backup,all_jobs>
.PARAMETER Mode
Choose between three modes:
 job_status: Check if the given job was successful. (Default)
 host_backup: Check if the last backup of the hosts in the job are corrupted or inconsistent.
 all_jobs: Check if all jobs were successful. Prints the job with the worst status first.
. PARAMETER JobName
Name of the VEEAM Backup Job
. PARAMETER days_warning
Check if the job is older than the given days
. PARAMETER days_critical
Check if the job is older than the given days
#>

param(
    [string] $Mode = 'job_status',
    [string] $JobName,
    [int]    $days_warning = 3,
    [int]    $days_critical = 5,
    [switch] $Verbose
)


. "$PSScriptRoot\nagios-utils.ps1"


try {
    Add-PSSnapin VeeamPSSnapin;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load VEEAM Backup SnapIn: $error"
}

try {

    If ($Mode -eq 'all_jobs') {
        $jobs = Get-VBRJob
    }
    ElseIf ($Mode -eq 'job_status') {
        $jobs = Get-VBRJob -Name "$JobName"
    }

    $msg = @()

    ForEach ($job In $jobs) {
        $jobname = $job.Name

        $n = Get-Date -Format "yyyy-MM-dd"
        $l = $job.LatestRunLocal
        $ts = (New-TimeSpan -Start $l -End $n).Days

        if ($verbose){
          write-Host "DayDIFF $ts Lastjob $l NOW: $n"
        }

        if ($job.IsRunning -eq $true) {
            $status = ($status, $NagiosOK | Measure -Max).Maximum
            $msg += "Job is currently running: $jobname"
        }
        elseif ( $job.FindLastSession().result -ne 'success') {
            $status = ($status,$NagiosCritical | Measure -Max).Maximum
            $msg += "Last job result failed: $jobname"
        }
        elseif ( $ts -gt $days_critical ) {
            $status = ($status,$NagiosCritical | Measure -Max).Maximum
            $msg += "Last job run is $ts days old: $jobname"
        }
        elseif ( $ts -gt $days_warning ) {
            $status = ($status,$NagiosWarning | Measure -Max).Maximum
            $msg += "Last job run is $ts days old: $jobname"
        }
        else {
            $status = ($status,$NagiosOK | Measure -Max).Maximum
            $msg += "Last job result was successful: $jobname"
        }

    }
    Plugin-Exit $status "$($msg -join ' - ')"
}
catch {
    Plugin-Exit $NagiosUnknown "Get-VBRJob failed: $error"
}

try {
  if ($verbose)
  {
    Write-Host "Mode=$Mode"
  }
  if ($Mode -eq 'host_backup')
  {
   [Array]$output = @()

   $bkp_names = Get-VBRBackup -Name "$JobName" | Get-VBRRestorePoint -Name * | Select-Object Name -Unique
   if ($verbose)
   {
    Write-Host $bkp_names
   }

   ForEach($n in $bkp_names)
   {
     $bkp = Get-VBRRestorePoint -Name $n.Name | Sort-Object –Property CreationTime –Descending | Select -First 1
     $vm = $bkp.Name

     if ($verbose)
     {
      write-Host "VM: $vm"
      Write-Host "Corrupted: $($bkp.IsCorrupted)"
      write-Host "Recheck: $($bkp.IsRecheckCorrupted)"
      write-Host "Consistent: $($bkp.IsConsistent)"

     }

     if ($bkp.IsCorrupted -eq $true -or $bkp.IsRecheckCorrupted -eq $true -or $bkp.IsConsistent -ne $true ){
       $failed = $true
       $output += "$vm Last Backup is corrupted or not consistent."
     } else {
       $output += "$vm Last Backup is fine."
     }
   }
   if ($failed -eq $true){
     Plugin-Exit $NagiosCritical "Backups failed in job $JobName" ($output | out-String)
   } else {
     Plugin-Exit $NagiosOK "No Backups failed in job: $JobName" ($output | out-String)
   }
  }
} catch {
   Plugin-Exit $NagiosUnknown "Get Backup Jobs failed: $error"
}
