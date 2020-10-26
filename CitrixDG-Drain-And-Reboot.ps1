#############################################################################################################
#   Author: Megan Fuhr
#   Description: This script will tag a server in a delivery group that
#                is not in maintenance mode with the word DRAIN and place in maintenance mode.
#                Upon next run, it checks for a tagged server and if it is in maintenance mode 
#                and has no sessions, the tag will be removed, server taken out of maintenance mode,
#                and rebooted.  It will tag a new server if none has already been tagged.
#                Only one server will be tagged and placed in maintenance mode by this script 
#                at a time.
#############################################################################################################

try {
    Add-PSSnapin Citrix.* -ErrorAction SilentlyContinue
}
catch {RETURN}

#Variables
$DDC = "YourDDC.Domain.com"
$deliverygroups = Get-BrokerDesktopGroup -AdminAddress $DDC -MaxRecordCount 10000 -Filter {SessionSupport -eq "MultiSession"}


foreach ($deliverygroup in $deliverygroups) {
    #Get Desktops in each deliverly group that are tagged already with DRAIN
    $taggedserver = @()
    $taggedserver = Get-BrokerDesktop -AdminAddress $DDC -DesktopGroupName $deliverygroup.Name -MaxRecordCount 10000 -Tag "DRAIN*"

    if ($taggedserver -eq $null) {
        
        $target = Get-BrokerDesktop -AdminAddress $DDC -MaxRecordCount 10000 -DesktopGroupName $deliverygroup.name -Filter { InMaintenanceMode -eq $false } | sort LastDeregistrationTime | Select -first 1
        
        if ($target -ne $null) {
            #update tag for DRAIN and date/time machine was placed in maintenance mode by script
            $date = (Get-Date).toString("yyyy-MM-dd HH,mm,ss")
            New-BrokerTag -AdminAddress $ddc -Name "DRAIN - $date - $($Target.HostedMachineName)" | Add-BrokerTag -Machine $target.MachineName
                
            #Place server in maintenance mode
            $target.MachineName | Set-BrokerMachineMaintenanceMode -adminAddress $DDC -MaintenanceMode $true
            #Write-Host "Tagging: " + $target.machinename
        }
    }
    else {
        $sessions = Get-BrokerSession -AdminAddress $DDC -MaxRecordCount 10000 -MachineName $taggedserver.MachineName
        if (($taggedserver.InMaintenanceMode -eq $true) -and ($sessions.count -eq 0)) {
                #Remove tag
                $removeTag = Get-BrokerTag -AdminAddress $ddc -MachineUid $taggedserver.MachineUid
                Remove-BrokerTag -AdminAddress $DDC -Machine $taggedserver.MachineName $Removetag
                Remove-BrokerTag -AdminAddress $DDC $Removetag

                #Remove from maintenance mode
                $taggedserver.MachineName | Set-BrokerMachineMaintenanceMode -adminAddress $DDC -MaintenanceMode $false

                #reboot server
                #Write-Host "This is where I would reboot: " $taggedServer.DNSName   
                New-BrokerHostingPowerAction -adminAddress $DDC -MachineName $taggedserver.MachineName -Action Restart   
        }
    }
}