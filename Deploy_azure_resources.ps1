#Install Azure powershell first:
#Install-Module -Name Az -AllowClobber -Scope CurrentUser
#set-executionpolicy -scope process -executionpolicy bypass -force
param (
    [Parameter(Mandatory=$false)][string]$azusername,
    [Parameter(Mandatory=$false)][string]$azpassword,
	[Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$loginusername,
    [Parameter(Mandatory=$true)][string]$loginpassword,
    [Parameter(Mandatory=$true)][string]$VMlist
)


$location = "westus2"
$resourcegroupname = $ResourceGroupName
$storageaccountname = "523bbcf97f0d"
$virtualnetworkname = "Demovirtualnetwork"
$pubipaddressname = "Demo-pubip2"
$networksecuritygroupname = "Internetfacing-westus2"
$availabilityset1 = "Demo-as1"
#$demosecurepassword = Convertto-SecureString -String $azpassword -AsPlainText -force
#$democredentials = New-object System.Management.Automation.PSCredential $azusername,$demosecurepassword
$loginsecurePassword = Convertto-SecureString -String $loginpassword -AsPlainText -force
$logincredentials=New-object System.Management.Automation.PSCredential $loginusername,$loginsecurePassword

Function Deploy-VMfromCsv
    {
     param(
          [parameter(Mandatory)][string]$vmcsvfile,
          [parameter(Mandatory)][string]$resourcegroup,
          [parameter(Mandatory)][string]$location,
          [parameter(Mandatory)][Object]$virtualnetwork,
          [parameter(Mandatory)][Object]$nsg,
          [parameter(Mandatory)][Object]$oscredentials
          )
    $vms = Import-CSV $vmcsvfile
    ForEach ($vm in $vms)
        {
        $vmname = $vm.VMName
        $vmsize = $vm.VMSize
        $vmpublisher = $vm.VMPublisher
        $vmoffer = $vm.VMOffer
        $vmsku = $vm.VMSKU
        $vmversion = $vm.VMVersion
        $vmos = $vm.VMOS
        write-host $vmos
        $vmnicname = $vmname + "-NIC"
        $pubipaddressname = $vmname + "-PublicIPA"
        $pubipaddress = New-AzPublicIpAddress -AllocationMethod Dynamic -ResourceGroupName $resourcegroup -IpAddressVersion IPv4 -Location $location -Name $pubipaddressname
        write-host "Public IP address Created - name is $pubipaddressname"
        $vmnic = New-AzNetworkInterface -Name $vmnicname -ResourceGroupName $resourcegroup -Location $location -SubnetId $virtualnetwork.Subnets[0].Id -PublicIpAddressId $pubipaddress.Id -NetworkSecurityGroupId $nsg.Id
        write-host "New NIC Created - name $vmnicname"
        if ($vmos -eq "Windows")
                {
                write-host "Windows OS deploying" -ForegroundColor Green
                $vmconfig = New-AzVMConfig -VMName $vmname -VMSize $vmsize | `
                Set-AzVMOperatingSystem -Windows -ComputerName $vmname -Credential $oscredentials | `
                Set-AzVMSourceImage -PublisherName $vmpublisher -Offer $vmoffer -Skus $vmsku -Version $vmversion | `
                Add-AzVMNetworkInterface -Id $vmnic.Id
                write-host "Configuration Object Created - name is $vmname"
                New-AzVM -ResourceGroupName $resourcegroup -Location $location -VM $vmconfig
                write-host "New VM created - Name is $vmname"
                }
        ElseIf ($vmos -eq "Linux")
                {
                write-host "Linux OS deploying" -ForegroundColor Green
                $vmconfig = New-AzVMConfig -VMName $vmname -VMSize $vmsize | `
                Set-AzVMOperatingSystem -Linux -ComputerName $vmname -Credential $oscredentials | `
                Set-AzVMSourceImage -PublisherName $vmpublisher -Offer $vmoffer -Skus $vmsku -Version $vmversion | `
                Add-AzVMNetworkInterface -Id $vmnic.Id
                write-host "Configuration Object Created - name is $vmname"
                New-AzVM -ResourceGroupName $resourcegroup -Location $location -VM $vmconfig
                write-host "New VM created - Name is $vmname"
                }
        Else
                {
                Write-Host "OS Field Invalid" -ForegroundColor Red
                }
        }
    }

Import-Module Az.Accounts
clear-azcontext

if (!$azusername) {
	write-host "azusername is null"
    Connect-AzAccount
}
else {
    write-host "azusername is present"  
	$securepassword = Convertto-SecureString -String $azpassword -AsPlainText -force
	$democredentials = New-object System.Management.Automation.PSCredential $azusername,$securepassword
	Connect-AzAccount -credential $democredentials -ErrorAction Stop
}


$resourcegroup = New-AzResourceGroup -Location $location -Name $resourcegroupname
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix "10.11.1.0/24"
$backendSubnet = New-AzVirtualNetworkSubnetConfig -Name backendSubnet -AddressPrefix "10.11.2.0/24"
$virtualnetwork = New-AzVirtualNetwork -Name $virtualnetworkname -ResourceGroupName $resourcegroupname -Location $location -AddressPrefix "10.11.0.0/16" -Subnet $frontendSubnet,$backendSubnet
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$rule2 = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" -Access Allow -Protoc Tcp -Direction Inbound -Priority 110 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22
$networksecuritygroup = New-AzNetworkSecurityGroup -ResourceGroupName $resourcegroupname -Location $location -Name $networksecuritygroupname -SecurityRules $rule1,$rule2

Deploy-VMfromCsv $VMlist $resourcegroupname $location $virtualnetwork $networksecuritygroup $logincredentials
