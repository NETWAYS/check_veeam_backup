# Icinga check VEEAM Backup
For help run:
```
Get-Help .\check_veeam_backup.ps1 -full
```

## Dependency
Please make sure that the *VeeamPSSnapin* is installed on the server.

The Nagios-Utils are required and need to be in the same directory as the script
[nagios-utils.ps1](https://github.com/NETWAYS/check_exchange_powershell/blob/master/nagios-utils.ps1)

## Development
For development on your computer connect to the Veeam server first before running the check script:
```
Add-PSSnapin VeeamPSSnapin; Connect-VBRServer -server "bvdgdi-svpvee1.bs.ch" -Credential (Get-Credential)
```
