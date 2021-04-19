try {
    Add-PSSnapin Citrix.* -ErrorAction SilentlyContinue
    }
    catch {RETURN}
    
    $day = (Get-Date).DayOfWeek
    
    if ($day -eq "Saturday" -or $day -eq "Sunday"){
    Write-Host "Do nothing.  Day is $day"
    $LastExitCode = 1
    exit $LASTEXITCODE
    }
    
    #Variables
    $deliveryGroups = @()
    
    $temp = New-Object psobject -Property @{
    DDC = "YourDDC.Company.com"
    DeliveryGroup = "DeliveryGroupName"
    }
    
    $deliveryGroups += $temp
    
    #This always shows up on the Studio Dashboard as a create - regardless if it already exists
    foreach ($dg in $deliveryGroups) {
    if (!(Get-BrokerTag -AdminAddress $dg.DDC -Name "DRAIN")) {
        New-BrokerTag -AdminAddress $dg.DDC -Name "DRAIN"
    }
    else {
        Write-Host "Tag already exists."
    }
    }
    
    #for each DG in DGs
    foreach ($DeliveryGroup in $deliveryGroups) {
    
        #get total number of desktops in each DG
        $desktopsAll = Get-BrokerDesktop -AdminAddress $deliveryGroup.ddc -MaxRecordCount 10000 -DesktopGroupName $DeliveryGroup.DeliveryGroup
        #calculate the allowed number of VMs in maintenance mode at once
        #casting as an int, but this is a problem for delivery groups with 2 or less cast as an int rounds down to 0
        [int]$allowedThreshold = ($desktopsall.count * .20)
        #get what is tagged for draining
        $WhatIsTaggedForDraining = $DesktopsAll | where {$_.InMaintenanceMode -eq $true -and $_.tags -contains "DRAIN"}
    
        #Max number is tagged and in maint.
        if ($AllowedThreshold -eq $whatistaggedfordraining.count) {
            #Look at targets already tagged, can the be rebooted?
            foreach ($desktop in $WhatIsTaggedForDraining) {
                If ($desktop.SummaryState -eq "Available"){
                    
                    #Remove tag
                    $removeTag = Get-BrokerTag -AdminAddress $DeliveryGroup.ddc -MachineUid $desktop.MachineUid
                    Remove-BrokerTag -AdminAddress $DeliveryGroup.ddc -Machine $desktop.MachineName $Removetag
        
                    #Remove from maintenance mode
                    $desktop.MachineName | Set-BrokerMachineMaintenanceMode -adminAddress $DeliveryGroup.DDC -MaintenanceMode $false
    
                    #reboot server
                    #A powered off VM sent a Restart action will power it on. 
                    New-BrokerHostingPowerAction -adminAddress $DeliveryGroup.DDC -MachineName $desktop.MachineName -Action Restart 
                }
            }
            #making a decision here not to look at placing new servers in maintenance mode during the same cycle.
            #Because a reboot can take several minutes to process, there is the risk of having greater than 20% unavailable at a time
        }
        elseif ($WhatIsTaggedForDraining.count -lt $allowedThreshold) { 
            #get teh difference.  This will be the number of additional machines we can place in maintenance mode
            $difference = ($allowedThreshold - $whatistaggedfordraining.count)
    
            $toBe = Get-BrokerDesktop -AdminAddress $DeliveryGroup.ddc -MaxRecordCount 10000 -DesktopGroupName $DeliveryGroup.DeliveryGroup | `
                        Where {$_.InMaintenanceMode -eq $false} | `
                        sort LastDeregistrationTime | `
                        Select -first $difference
    
            #tag new servers based on the amount tobe within allowed threshold
            $target = Get-BrokerDesktop -AdminAddress $DeliveryGroup.DDC -MaxRecordCount 10000 -DesktopGroupName $DeliveryGroup.DeliveryGroup -Filter { InMaintenanceMode -eq $false } | sort LastDeregistrationTime | Select -first $toBe.count
        
            if ($target -ne $null) {
                #update tag for DRAIN and date/time machine was placed in maintenance mode by script
                foreach ($item in $target) {
                
                Get-BrokerTag -AdminAddress $DeliveryGroup.DDC -Name "DRAIN" | Add-BrokerTag -Machine $item.MachineName
                    
                #Place server in maintenance mode
                $item.MachineName | Set-BrokerMachineMaintenanceMode -adminAddress $DeliveryGroup.DDC -MaintenanceMode $true
                }
            }
            #get this value again that will include newly tagged           
            $WhatIsTaggedForDraining = Get-BrokerDesktop -AdminAddress $DeliveryGroup.ddc -MaxRecordCount 10000 -DesktopGroupName $DeliveryGroup.DeliveryGroup | where {$_.InMaintenanceMode -eq $true -and $_.tags -contains "DRAIN"}
    
            #let's check if we can reboot anything.
            foreach ($desktop in $WhatIsTaggedForDraining) {
                If ($desktop.SummaryState -eq "Available"){
                    
                    #Remove tag
                    $removeTag = Get-BrokerTag -AdminAddress $DeliveryGroup.ddc -MachineUid $desktop.MachineUid
                    Remove-BrokerTag -AdminAddress $DeliveryGroup.ddc -Machine $desktop.MachineName $Removetag
        
                    #Remove from maintenance mode
                    $desktop.MachineName | Set-BrokerMachineMaintenanceMode -adminAddress $DeliveryGroup.DDC -MaintenanceMode $false
    
                    #reboot server
                    #A powered off VM sent a Restart action will power it on. 
                    New-BrokerHostingPowerAction -adminAddress $DeliveryGroup.DDC -MachineName $desktop.MachineName -Action Restart 
                }
            }
        }
        else {
            Write-host "Default exit"
        }
    }