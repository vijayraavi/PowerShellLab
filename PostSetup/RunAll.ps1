#requires -version 5.0

[cmdletbinding()]

Param(
#run the script without any prompting
[Switch]$Force
)
#this is here in case the script is aborted from previous runs
$PSDefaultParameterValues.remove("write-host:foregroundcolor") | Out-Null

if (-Not $Force) {
$msg = @"

 This control script will run all post update tasks on virtual machines that are
 part of the PowerShellLab Autolab configuration. It is assumed you have not
 modified anything in the configuration files.

 The script will do the following:
   - Run Windows Update on all virtual machines
   - Download Git on the Win10 client
   - Download Sysinternals tools on the Win10 client
   - Install VSCode on the Win10 client
   - Update PowerShell help on the Win10 client
   - Reboot all virtual machines

 Before running this script, all configuration setup must be complete. You
 must also have performed an interactive logon on the Windows 10 client with the 
 Company\Administrator account to complete the Windows 10 setup. You can immediately
 log off.

 Running this script will remove any existing PSSessions.
 
 If any of the commands fail, try running it separately.

 Make sure all virtual machines are running before continuing.

   $(Get-VM Win10,SRV1,SRV2,SRV3,DOM1 | out-string)
"@

Clear-Host
Write-Host $msg -ForegroundColor Cyan

$coll = @() 
$coll+= [System.Management.Automation.Host.ChoiceDescription]::new("Yes &Y")              
$coll+= [System.Management.Automation.Host.ChoiceDescription]::new("No &N")
$r = $host.ui.PromptForChoice("Do you want to continue with this script?","",$coll,1)
If ($r -eq 1) {
    return
}
} #if not using -Force

#set a default color for the progress messages
$PSDefaultParameterValues.add("write-host:foregroundcolor","yellow")
Get-Job | Remove-Job -force

$pass = ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force
#credential for domain administrator
$admin = New-Object PSCredential "company\administrator",$pass
#password for SRV3 which is in a workgroup
$wg = New-Object PSCredential "srv3\administrator",$pass

Write-Host "[$(Get-Date -format T)] Starting the post process"
Write-Host "[$(Get-Date -format T)] Creating PSSessions"
#remove any existing PSSessions
Get-PSSession | Remove-PSSession

#create PSSessions. Some of these variables are un-used at this time
$srv3 = New-PSSession -VMName SRV3 -Credential $wg
$win10 = New-PSSession -VMName Win10 -Credential $admin
$servers = New-PSSession -VMName SRV1,SRV2,DOM1 -Credential $admin
$all = Get-PSSession

Write-Host "[$(Get-Date -format T)] Waiting for sessions to become available"
Do {
    Start-Sleep -Seconds 1
} Until ( ($all|get-pssession).Availability -notcontains 'busy')
Write-Host "[$(Get-Date -format T)] Running Windows Update"
.\Run-WindowsUpdate.ps1 -session $all -asJob #| Out-Null

Write-Host "[$(Get-Date -format T)] Waiting for Win10 session to become available"

Do {
    Start-Sleep -Seconds 1
} Until ( ($win10|get-pssession).Availability -eq 'available')
Write-Host "[$(Get-Date -format T)] Install SysInternals on Windows 10"
 .\Install-Sysinternals.ps1 -Session $win10 | Out-Null

Write-Host "[$(Get-Date -format T)] Waiting for Win10 session to become available"
Do {
    Start-Sleep -Seconds 1
} Until ( ($win10|get-pssession).Availability -eq 'available')
Write-Host "[$(Get-Date -format T)] Downloading Git on Windows 10"
.\Download-Git.ps1 -session $win10 | out-Null

Write-Host "[$(Get-Date -format T)] Waiting for Win10 session to become available"
Do {
    Start-Sleep -Seconds 1
} Until ( ($win10|get-pssession).Availability -eq 'available')

<#
#add some name resolution calls to help with errors I'm getting about 
#being unable to resolve the redirected name
Invoke-Command { 
        Resolve-DnsName go.microsoft.com | Out-Null
        Resolve-DnsName azurewebsites.net | out-null
        Resolve-DnsName az764295.vo.msecnd.net | out-null
} -Session $all
#>
Write-Host "[$(Get-Date -format T)] Installing VSCode on Windows 10"
#for some unknown reason this fails when using an existing session 
# .\install-vscode -session $win10 | Out-Null
.\install-vscode -VMName Win10 -Credential $admin | Out-Null

Write-Host "[$(Get-Date -format T)] Updating PowerShell help on Windows 10"
Do {
    Start-Sleep -Seconds 1
} Until ( ($win10|get-pssession).Availability -eq 'available')
#update help and suppress all error messages
Invoke-Command { Update-Help -force -ErrorAction SilentlyContinue } -session $win10

Write-Host "[$(Get-Date -format T)] Waiting for Windows Update Jobs to complete"
Wait-Job WinUp*

Write-Host "[$(Get-Date -format T)] Stopping Windows 10"
Stop-VM Win10 -AsJob | Wait-Job | Out-Null

Write-Host "[$(Get-Date -format T)] Stopping member servers"
Get-VM SRV1,SRV2,SRV3 | Stop-VM -Force -AsJob

Write-Host "[$(Get-Date -format T)] Stopping DOM1"
Stop-VM DOM1 -AsJob | Wait-Job | Out-Null

Write-Host "[$(Get-Date -format T)] Restarting all virtual machines"
Start-VM SRV3,DOM1 -asjob | Wait-job | Out-Null
Start-VM SRV1,SRV2,Win10 -asjob | out-null

#clean up
$all | Remove-PSSession
$PSDefaultParameterValues.remove("write-host:foregroundcolor")

Write-Host "[$(Get-Date -format T)] Ending the post process" -ForegroundColor green