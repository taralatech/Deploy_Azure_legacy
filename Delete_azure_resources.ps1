#Install Azure powershell first:
#Install-Module -Name Az -AllowClobber -Scope CurrentUser
#set-executionpolicy -scope process -executionpolicy remotesigned
#Import-Module Az.Accounts
#connect-azaccount
param (
    [Parameter(Mandatory=$false)][string]$azusername,
    [Parameter(Mandatory=$false)][string]$azpassword,
	[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
Disconnect-AzAccount

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

$mtresourcegroupname = $ResourceGroupName

$demovm = Get-AzVM -resourcegroupname $mtresourcegroupname
write-host "Stopping VM"
$demovm | Stop-AzVM -SkipShutdown -force
write-host "Deleting VM"
$demovm | Remove-AzVM -Force
write-host "Deleting VM NIC"
Get-AzNetworkInterface -ResourceGroupName $mtresourcegroupname | Remove-AzNetworkInterface -Force
write-host "Deleting VM PubIPA"
Get-AzPublicIpAddress -ResourceGroupName $mtresourcegroupname | Remove-AzPublicIpAddress -Force
write-host "Deleting VM Storage"
Get-AzDisk -ResourceGroupName $mtresourcegroupname | Remove-AzDisk -Force
write-host "Deleting VM Storage Account"
Get-AzStorageAccount -resourcegroupname $mtresourcegroupname | Remove-AzStorageAccount -Force
write-host "Deleting NSG"
Get-AzNetworkSecurityGroup -ResourceGroupName $mtresourcegroupname | Remove-AzNetworkSecurityGroup -Force
write-host "Deleting VNet"
Get-AzVirtualNetwork -ResourceGroupName $mtresourcegroupname | Remove-AzVirtualNetwork -Force
write-host "Deleting Resource Group"
Get-AzResourceGroup -Name $mtresourcegroupname | Remove-AzResourceGroup -Force
