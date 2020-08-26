<#
.NAME
check_veeam_backup
.SYNOPSIS
Checks the backup
.SYNTAX
check_veeam_backup -Mode <job_status,host_backup>
.PARAMETER Mode
Choose between two modes:
 job_status: Check if the given job was successful. (Default)
 host_backup: Check if the last backup of the hosts in the job are corrupted or inconsistent.
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

  if ($Mode -eq 'job_status') {

    $job = Get-VBRJob -Name "$JobName"

    if ($job.IsRunning -eq $true ) {
      Plugin-Exit $NagiosOK "Job is currently running: $JobName"
    }

    $n = Get-Date -Format "yyyy-MM-dd"
    $l = $job.LatestRunLocal
    $ts = (New-TimeSpan -Start $l -End $n).Days

    if ($verbose){
      write-Host "DayDIFF $ts Lastjob $l NOW: $n"
    }

    if ( $job.FindLastSession().result -ne 'success') {
      Plugin-Exit $NagiosCritical "Last Job result failed: $JobName"
    } Elseif ( $ts -gt $days_critical ){
      Plugin-Exit $NagiosCritical "Last job run is $ts days old: $JobName"
    } Elseif ( $ts -gt $days_warning ){
      Plugin-Exit $NagiosWarning "Last job run is $ts days old: $JobName"
    } else {
      Plugin-Exit $NagiosOK "Last Job result was successful: $JobName"
    }
  }
} catch {
    Plugin-Exit $NagiosUnknown "Get-VBRJob failed: $error"
}

try {
  if ($Mode -eq 'host_backup')
  {
   [Array]$output = @()

   $bkp_names = Get-VBRBackup -Name "$JobName" | Get-VBRRestorePoint -Name * | Select-Object Name -Unique

   if ($verbose)
   {
    Write-Debug $bkp_names
   }

   ForEach($n in $bkp_names)
   {

     $bkp = Get-VBRRestorePoint -Name $n.Name | Sort-Object –Property CreationTime –Descending | Select -First 1
     $vm = $bkp.Name

     if ($verbose)
     {
      write-Host "VM: $vm"
      Write-Host "Corrupted: $bkp.IsCorrupted"
      write-Host "Recheck: $bkp.IsRecheckCorrupted"
      write-Host "Consistent: $bkp.IsConsistent"

     }

     if ($bkp.IsCorrupted -eq $true -or $bkp.IsRecheckCorrupted -eq $true -or $bkp.IsConsistent -ne $true ){
       $failed = $true
       $output += "$vm Last Backup is corrupted or not consistent."
     } else {
       $output += "$vm Last Backup is fine."
     }
   }
   if ($failed -eq $true){
     Plugin-Output $NagiosCritical "Backups failed in job $JobName" ($output | out-String)
     #Plugin-Exit $NagiosCritical
   } else {
     #Plugin-Exit $NagiosOK "No Backups failed in job: $JobName"
     Plugin-Output $NagiosOK "No Backups failed in job: $JobName" ($output | out-String)
   }
  }
} catch {
   Plugin-Exit $NagiosUnknown "Get Backup Jobs failed: $error"
}

