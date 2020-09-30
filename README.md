# Icinga Check VEEAM Backup

This Plugin is capable to check the status of jobs and host backups inside a job.

## Dependency

Please make sure that the *VeeamPSSnapin* is installed on the server.

The Nagios-Utils are required and need to be in the same directory than the script
[nagios-utils.ps1](https://github.com/NETWAYS/check_exchange_powershell/blob/master/nagios-utils.ps1)

The CheckCommand relies on the *powershell-base* check command from the [check_exchange_powershell](https://github.com/NETWAYS/check_exchange_powershell/blob/master/icinga2-commands.conf) repo.

## Parameters

```
PS C:> get-Help .\check_veeam_backup.ps1
check_veeam_backup.ps1 [[-Mode] <string>] [[-JobName] <string>] [[-days_warning] <int>] [[-days_critical] <int>] [-Verbose]
```

## Mode job_status

This mode checks if the job was successful and if the last run is older then the given days.

```
 .\check_veeam_backup.ps1 -JobName 'ProdVMs' -Mode job_status -days_warning 2 -days_critical 4
OK: Last Job result was successful: ProdVMs
```

## Mode host_backup

This mode checks if the backups of hosts are corrupted or inconsistent.

```
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
e
```

## Mode job_all

This mode checks if the all jobs were successful and also you can add filter.

```
 .\check_veeam_backup.ps1 -Mode job_all -Filter INFRA
OK: All Jobs are fine...
```
```
 .\check_veeam_backup.ps1 -Mode job_all
CRITICAL: There are some failed jobs..
Corrupted/Consistent : TEST
```

## Contributing

Feel free to ask questions and open issues. Feedback is always welcome and appreciated.

## License

    Copyright (C) 2019 Thilo Wening <thilo.wening@netways.de>
	              2019 NETWAYS GmbH <info@netways.de>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
