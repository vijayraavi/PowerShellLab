<# Notes:

Authors: Jason Helmick and Melissa (Missy) Januszko

The bulk of this DC, DHCP, ADCS config is authored by Melissa (Missy) Januszko and Jason Helmick.
Currently on her public DSC hub located here: https://github.com/majst32/DSC_public.git

Additional contributors of note: Jeff Hicks

       
Disclaimer

This example code is provided without copyright and AS IS.  It is free for you to use and modify.
Note: These demos should not be run as a script. These are the commands that I use in the 
demonstrations and would need to be modified for your environment.

#> 

@{
    AllNodes = @(
        @{
            NodeName = '*'

            # Lab Password - assigned to Administrator and Users
            LabPassword = 'P@ssw0rd'
            
            # Common networking
            InterfaceAlias = 'Ethernet'
            DefaultGateway = '192.168.3.1'
            SubnetMask = 24
            AddressFamily = 'IPv4'
            IPNetwork = '192.168.3.0/24'
            IPNatName = 'LabNat'
            DnsServerAddress = '192.168.3.10'

            # Firewall settings to enable
            FirewallRuleNames = @(
                'FPS-ICMP4-ERQ-In',
                'FPS-ICMP6-ERQ-In',
                'FPS-SMB-In-TCP',
                'WMI-WINMGMT-In-TCP-NoScope',
                'WMI-WINMGMT-Out-TCP-NoScope',
                'WMI-WINMGMT-In-TCP',
                'WMI-WINMGMT-Out-TCP'
            )
                       
            # Domain and Domain Controller information
            DomainName = "Company.Pri"
            DomainDN = "DC=Company,DC=Pri"
            DCDatabasePath = "C:\NTDS"
            DCLogPath = "C:\NTDS"
            SysvolPath = "C:\Sysvol"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true 
                        
            # DHCP Server Data
            DHCPName = 'LabNet'
            DHCPIPStartRange = '192.168.3.200'
            DHCPIPEndRange = '192.168.3.250'
            DHCPSubnetMask = '255.255.255.0'
            DHCPState = 'Active'
            DHCPAddressFamily = 'IPv4'
            DHCPLeaseDuration = '00:08:00'
            DHCPScopeID = '192.168.3.0'
            DHCPDnsServerIPAddress = '192.168.3.10'
            DHCPRouter = '192.168.3.1'

 	    # ADCS Certificate Services information
            CACN = 'Company.Pri'
            CADNSuffix = "C=US,L=Phoenix,S=Arizona,O=Company"
            CADatabasePath = "C:\windows\system32\CertLog"
            CALogPath = "C:\CA_Logs"
            ADCSCAType = 'EnterpriseRootCA'
            ADCSCryptoProviderName = 'RSA#Microsoft Software Key Storage Provider'
            ADCSHashAlgorithmName = 'SHA256'
            ADCSKeyLength = 2048
            ADCSValidityPeriod = 'Years'
            ADCSValidityPeriodUnits = 2

            # Lability default node settings
            Lability_SwitchName = 'LabNet'
            Lability_ProcessorCount = 1
            Lability_MinimumMemory = 1GB
            SecureBoot = $false
            Lability_Media = '2016_x64_Standard_Core_EN_Eval' # Can be Core,Win10,2012R2,nano
                                                       # 2016_x64_Standard_EN_Eval
                                                       # 2016_x64_Standard_Core_EN_Eval
                                                       # 2016_x64_Datacenter_EN_Eval
                                                       # 2016_x64_Datacenter_Core_EN_Eval
                                                       # 2016_x64_Standard_Nano_EN_Eval
                                                       # 2016_x64_Datacenter_Nano_EN_Eval
                                                       # 2012R2_x64_Standard_EN_Eval
                                                       # 2012R2_x64_Standard_EN_V5_Eval
                                                       # 2012R2_x64_Standard_Core_EN_Eval
                                                       # 2012R2_x64_Standard_Core_EN_V5_Eval
                                                       # 2012R2_x64_Datacenter_EN_V5_Eval
                                                       # WIN10_x64_Enterprise_EN_Eval
        }

<#    Available Roles for computers
        DC = Domain Controller
        DHCP = Dynamic Host Configuration Protocol
        ADCS = Active Directory Certificate SErvices - plus autoenrollment GPO's and DSC and web server certs
        Web = Basic web server
        RSAT = Remote Server Administration Tools for the client
        RDP = enables RDP and opens up required firewall rules
        DomainJoin = joins a computer to the domain
#>
        @{
            NodeName = 'DOM1'
            IPAddress = '192.168.3.10'
            Role = @('DC', 'DHCP', 'ADCS') 
            Lability_BootOrder = 10
            Lability_BootDelay = 60 # Number of seconds to delay before others
            Lability_timeZone = 'US Mountain Standard Time' #[System.TimeZoneInfo]::GetSystemTimeZones()
            Lability_Media = '2016_x64_Standard_Core_EN_Eval'
            Lability_MinimumMemory = 2GB
            Lability_ProcessorCount = 2
            CustomBootStrap = @'
                    # This must be set to handle larger .mof files
                    Set-Item -path wsman:\localhost\maxenvelopesize -value 1000       
'@
        }
        
        @{
            NodeName = 'SRV1'
            IPAddress = '192.168.3.50'
            #Role = 'DomainJoin' # example of multiple roles @('DomainJoin', 'Web')
            Role = @('DomainJoin')
	        Lability_BootOrder = 20
            Lability_timeZone = 'US Mountain Standard Time' #[System.TimeZoneInfo]::GetSystemTimeZones()
            Lability_Media = '2016_x64_Standard_Core_EN_Eval'
        }

        @{
            NodeName = 'SRV2'
            IPAddress = '192.168.3.51'
            #Role = 'DomainJoin' # example of multiple roles @('DomainJoin', 'Web')
            Role = @('DomainJoin','Web')
	        Lability_BootOrder = 20
            Lability_timeZone = 'US Mountain Standard Time' #[System.TimeZoneInfo]::GetSystemTimeZones()
            Lability_Media = '2016_x64_Standard_Core_EN_Eval'
        }

       @{
            NodeName = 'SRV3'
            IPAddress = '192.168.3.60'
            #Role = 'Nano'
            Lability_BootOrder = 20
            Lability_Media = '2016_x64_Standard_Core_EN_Eval'
            Lability_ProcessorCount = 1
            Lability_StartupMemory = 1GB
        }

        @{
            NodeName = 'WIN10'
            IPAddress = '192.168.3.100'
            Role = @('domainJoin', 'RSAT', 'RDP')
            Lability_ProcessorCount = 2
            Lability_MinimumMemory = 2GB
            Lability_Media = 'WIN10_x64_Enterprise_EN_Eval'
            Lability_BootOrder = 20
            Lability_timeZone = 'US Mountain Standard Time' #[System.TimeZoneInfo]::GetSystemTimeZones()
            Lability_Resource = @('Win10RSAT')
            CustomBootStrap = @'
                    # To enable PSRemoting on the client
                    Enable-PSRemoting -SkipNetworkProfileCheck -Force;
'@
        }
#>
        
    );
    NonNodeData = @{
        Lability = @{
            # EnvironmentPrefix = 'PS-GUI-' # this will prefix the VM names                                    
            Network = @( # Virtual switch in Hyper-V
                @{ Name = 'LabNet'; Type = 'Internal'; NetAdapterName = 'Ethernet'; AllowManagementOS = $true;}
            );
            DSCResource = @(
                ## Download published version from the PowerShell Gallery or Github
                @{ Name = 'xActiveDirectory'; RequiredVersion="2.16.0.0"; Provider = 'PSGallery'; },
                @{ Name = 'xComputerManagement'; RequiredVersion = '2.0.0.0'; Provider = 'PSGallery'; },
                @{ Name = 'xNetworking'; RequiredVersion = '3.2.0.0'; Provider = 'PSGallery'; },
                @{ Name = 'xDhcpServer'; RequiredVersion = '1.5.0.0'; Provider = 'PSGallery';  },
                @{ Name = 'xWindowsUpdate' ; RequiredVersion = '2.7.0.0'; Provider = 'PSGallery';},
                @{ Name = 'xPSDesiredStateConfiguration'; RequiredVersion = '6.4.0.0'; },
                @{ Name = 'xPendingReboot'; RequiredVersion = '0.3.0.0'; Provider = 'PSGallery';},
                @{ Name = 'xADCSDeployment'; RequiredVersion = '1.1.0.0'; Provider = 'PSGallery';},
                @{ Name = 'xDnsServer';RequiredVersion = "1.7.0.0";Provider = 'PSGallery';},
                @{ Name = 'xWebAdministration';RequiredVersion = '1.15.0.0';Provider = 'PSGallery'}        

            );
            Resource = @(
                @{                    
                    Id = 'Win10RSAT'
                    Filename = 'WindowsTH-RSAT_WS2016-x64.msu'
                    Uri = 'https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/WindowsTH-RSAT_WS2016-x64.msu'
                    Expand = $false                    
                    #DestinationPath = '\software' # Default is resources folder
                }
            );

        };
    };
};
