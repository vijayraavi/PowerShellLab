#requires -version 4.0

#install all Windows updates on a Hyper-V VM
#you must be running Hyper-V on Windows 10 or Windows Server 2016

[CmdletBinding(DefaultParameterSetName="VM")]
Param(
    [Parameter(Mandatory,ParameterSetName='VM')]
    #specify the name of a VM
    [string[]]$VMName,
    [Parameter(Mandatory,ParameterSetName='VM')]
    #Specify the user credential
    [pscredential]$Credential,
    [Parameter(Mandatory,ParameterSetName="session")]
    #specify an existing PSSession object
    [System.Management.Automation.Runspaces.PSSession[]]$Session,
    [switch]$AsJob

)

    Write-Host "Be aware that running Windows Update may take some time to complete, especially for multiple virtual machines." -ForegroundColor yellow
    #define a script block to be run on each virtual machine via Invoke-Command
$sb = {    
    Write-Host "[$env:computername] Create update session objects"
    $updateSession = New-Object -ComObject "Microsoft.Update.Session"
    $updateSearcher = $updateSession.CreateupdateSearcher()
    $updatesToDownload = New-Object -ComObject "Microsoft.Update.UpdateColl"
    $updatesToInstall = New-Object -ComObject "Microsoft.Update.UpdateColl"
    $downloader = $updateSession.CreateUpdateDownloader() 
    $installer = $updateSession.CreateUpdateInstaller()
    
    #get the collection of available updates
    Write-Host "[$env:computername] Retrieving available updates"
    $results=$updateSearcher.Search("IsInstalled=0 and Type='Software'")
    Write-Host "[$env:computername] Retrieved $($results.updates.count) updates"
       
    #initialize
    $updates=@()
    
    # get by severity
    $updates+=$results.updates 
    
    if ($updates) {
        write-Host "[$env:computername] Processing $($updates.count) updates"
        
        #download updates if needed
        $updates | where {-not $_.IsDownloaded} | foreach {
            
            $updatesToDownload.Add($_) | out-null
        }
        if ($updatesToDownload.count -gt 0) {
            Write-host "[$env:computername] Downloading $($updatesToDownload.count) updates"
            $downloader.Updates = $updatesToDownload
            $downloader.Download()
        }
            
        Write-Host "[$env:computername] Installing $($updates.count) updates"   
        foreach ($item in $updates) {
            $updatesToInstall.add($item) | out-Null
        }
        
        $installer.Updates = $updatesToInstall
        
        foreach ($update in $updates) {   
            #uncomment the next line for troubleshooting or debugging
            #write-host "[$env:computername] $($update | out-string)"

            #accept EULAs
            if ($update.EULAAccepted -eq $false) {
                $update.AcceptEULA=$True
            }
            
            #install the updates
            Write-Host "[$env:computername] Installing $($update.title)"
        
             $installationResult = $installer.Install()
              
              #decode results
              Switch ($installationResult.ResultCode) {
                  0 {$result="Not Started"}
                  1 {$result="In Progress"}
                  2 {$result="Success" }
                  3 {$result="Success with errors"}
                  4 {$result="Failed"}
                  5 {$result="Process stopped before completing" }
                  default {$result="Unknown"}
              } #switch
              
              #determine if any updates require a reboot
              if ($installationResult.RebootRequired) {
                $RebootRequired=$True
              }
              #create a custom result object
              New-Object PSObject -Property @{
                Computername=$env:computername
                Title=$update.title
                Result=$result
                RebootRequired=$installationResult.RebootRequired
                Severity=$update.msrcSeverity
                InstallDate=Get-Date
              } #new-object
        } #end foreach
       
       if ($rebootRequired) {
            write-host "[$env:computername] One or more updates requires a reboot." -ForegroundColor Red -BackgroundColor Black
       }
   } #if $updates
   else {
    Write-Warning "[$env:computername] No matching updates found"
   }
   
} #close scriptblock

Try {
    if ($PSCmdlet.ParameterSetName -eq 'VM') {
        Write-Host "Creating PSSession to $VMName" -ForegroundColor cyan
        if ($PSBoundParameters.ContainsKey("AsJob")) {
            $PSBoundParameters.Remove("AsJob") | Out-Null
        }
        $session = New-PSSession @PSBoundParameters -ErrorAction stop
    }
    if ($AsJob) {
        Write-Host "Creating background jobs" -ForegroundColor cyan
        $session | Foreach {
            Invoke-Command -ScriptBlock $sb -Session $_ -AsJob -JobName "WinUp-$($_.Computername)"
        }
        write-Host "You will need to manually remove PSSessions after the jobs complete." -ForegroundColor yellow
    }
    else {
        Invoke-Command -ScriptBlock $sb -Session $session
    }
    if ($PSCmdlet.ParameterSetName -eq 'VM' -AND (-Not $AsJob)) {
        Write-Host "Removing PSSession" -ForegroundColor cyan
        $Session | Remove-PSSession
    }

}
Catch {
    Throw $_
}


