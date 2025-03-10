<#
 * Copyright Microsoft Corporation
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
#>

# Origianl path:  Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
#Import-Module Azure

Function local:GetVMConnection()
{
   param([string]$ServiceName, [string]$vmName)
   Write-Host "Connecting to $($vmName)" -NoNewline
   [System.Uri]$Return_URIS = $null;$Return_URIS = (Get-AzureWinRMUri -ServiceName $ServiceName -Name $vmName)
   if (($Return_URIS -ne $null) -and ($Return_URIS -ne "")) {Write-Host -ForegroundColor Green "... Connected" }
   else{Write-Host -ForegroundColor Red "... Unable to connect";$Return_URIS = $null}
   return ($Return_URIS)
}

# Creates final report of settings
Function local:ShowFinalCreds()
{
  param([string]$choice, [string]$domain, [string]$adminAccount, [string]$adminPassword, [string]$serviceName)

  if($choice -eq 1)
    {
      Write-Host "Credintials: $adminAccount Password: $adminPassword"
      Write-Host "Created Website on http://$serviceName.cloudapp.net"
    }
  elseif ($choice -eq 2)
    {
      Write-Host "Credentials: $domain\$adminAccount Password: $adminPassword"
      Write-Host "Created Website on http://$serviceName.cloudapp.net"
    }
  else
    {
      Write-Host "Credentials: $domain\$adminAccount Password: $adminPassword"
      Write-Host "Created Farm on http://$serviceName.cloudapp.net"
      Write-Host "Created Admin Site on http://$serviceName.cloudapp.net:20000"
    }
}

## wait - better UI 
Function local:Wait ()
{
param([string]$msg="Pausing",[int]$InSeconds=60)
   $Sleep = $InSeconds ; $delay = 1
#   if ($InSeconds -ge 60){[int]$delay = $InSeconds / 60 ; $Sleep = 60}
#    switch ($inSeconds){
#    ($inSeconds -ge 60){[int]$delay = $InSeconds / 60 ; $Sleep = 60}
#    ($inSeconds -lt 60){[int]$delay = 1 ; $Sleep = $InSeconds}
#    default {[int]$delay = 1 ; $Sleep = $InSeconds}
#    }

    if ($inSeconds -ge 60) {
      [int]$delay = $InSeconds / 60 ; $Sleep = 60
    }
    elseif ($inSeconds -lt 60){
      [int]$delay = 1 ; $Sleep = $InSeconds
    }
    else {
      [int]$delay = 1 ; $Sleep = $InSeconds
    }
    
    [int]$Count = 0 ; Write-Host "$($msg) ($($InSeconds.ToString().Trim()) seconds)" -NoNewline
    while ($Count -lt $delay){write-host -NoNewline "."; sleep $Sleep;$count += 1};Write-Host ".. Resuming"
}

##GP 6/10/2014
Function local:EmptyCheck()
{
param($InValue)

   $RetValue=$false;IF (($InValue -eq $null) -or ($InValue -eq "")){$RetValue=$true}
   Return $RetValue
}

##GP 6/10/2014
Function local:GetValueByRef()
{
param($ConfigPath, $Node, [int]$Instance,[string]$ConfigFile="RefNames.xml")

   $RefFilePath = (Split-Path $ConfigPath) + "\$($ConfigFile)"
   if (!(Test-Path $RefFilePath)){return $null}
   [XML] $RefFile = Get-Content $RefFilePath -ErrorAction SilentlyContinue
   $NodeValue = $RefFile.Values.($Node)
   switch ($NodeValue.GetType().name.toLower()) {
      "xmlelement" {$RetValue = $NodeValue.get_ChildNodes().Item($Instance).VMName}
      "string" {$RetValue = $NodeValue}      
      default {$RetValue=$null}
   }
   if ($RetValue -eq "" -or $RetValue -eq $null -or $RetValue.GetType().Name.ToLower() -ne "string"){$RetValue = $null}
   Return $RetValue
}

##GP 6/10/2014
Function local:SetMultipleNames()
{
param($ConfigPath, $VMInstance)
if ((EmptyCheck $ConfigPath) -or (EmptyCheck $VMInstance)){return}
#   foreach ($vmRole in $config.Azure.AzureVMGroups.VMRole) {
   foreach ($vmRole in $VMInstance) {
      $VMInstanceIndex = 0
      foreach($VM in $VmRole.AzureVM){
         $VMName = (GetValueByRef -ConfigPath $ConfigPath -Node $vmRole.Name -Instance $VMInstanceIndex)
         if ($VMName -ne $null){$VM.name = $VMName}
         $VMInstanceIndex = $VMInstanceIndex + 1
      }
   }
   Return
}

##GP 6/10/2014
Function local:SetSingleName()
{
param($ConfigPath, $VMInstance, $RefNode=$null, $VMRefValue=$null)

   if ((EmptyCheck $ConfigPath) -or (EmptyCheck $VMInstance)){return}
   if ($VMRefValue -ne $null -and ($VMInstance.GetAttribute($RefNode) -ne ""  )){
      $VMName = GetValueByRef -Node $VMRefValue -ConfigPath $configPath
      if ($VMName -ne $null){$VMInstance.($RefNode) = $vmName}
   }
   return
}

##GP 6/11/2014
##GP 6/13/2014 - Updated to use Index value, defaults to 0
function local:SetSingleNamebyNodeValue()
{
param([string]$ConfigPath, $VMInstance, [string]$RefNode, [string]$LookupNode, [string]$LookupValue,[int]$Index=0,[string]$ConfigFile="RefNames.xml")

   if ((EmptyCheck $ConfigPath) -or (EmptyCheck $VMInstance)-or (EmptyCheck $RefNode)){return}
   $RefFilePath = (Split-Path $ConfigPath) + "\$($ConfigFile)"
   if (!(Test-Path $RefFilePath)){return $null}
   [XML] $RefFile = Get-Content $RefFilePath -ErrorAction SilentlyContinue

   if ($RefFile.Values.($LookupNode).($LookupValue).count -eq $null){
      $VMName = $RefFile.Values.($LookupNode).($LookupValue).vmname }
   else {
      ## Get the first Instance of the node
      $VMName = $RefFile.Values.($LookupNode).($LookupValue)[$Index].vmname}
   
   ## Save the Value
   if ($VMName -ne $null){$VMInstance.($RefNode) = $vmName}
}

##GP 6/10/2014
Function local:BoolCheck()
{
param($inValue)

   if ($inValue -eq $null){return $false}
   [bool]$RetValue = $false
   switch ($inValue.ToLower()){
      (""){$RetValue = $false}
      ("true"){$RetValue = $true}
      ("t"){$RetValue = $true}
      ("1"){$RetValue = $true}
      default {$RetValue = $false}
   }
   return $RetValue
}

##GP 6/10/2014
Function local:CheckRegKey()
{
param($RegKey)

 if (!(Test-Path $RegKey)) {
    Write-Host "   Making Key "
    md $RegKey | Out-Null
 }else {Write-Host "   Key exists"}
}

##GP 6/10/2014
Function local:FillKey()
{
param($RegKey, $RegValue)

   Write-Host "   Adding $($RegValue)"
   $i = 1 ; $RegValue |% { New-ItemProperty -Path $RegKey -Name $i -Value $_ -PropertyType String -Force | Out-Null ; $i++ }
}

##GP 6/10/2014
Function local:UpdateReg()
{
param($PrimaryKey, $RegKey, $RegValue)

   Write-Host "Building $($RegKey)"
   $SubKey = Join-Path $PrimaryKey $RegKey
   Write-Host "   Writing Item Property" 
   New-ItemProperty -Path $PrimaryKey -Name $RegKey -Value 1 -PropertyType Dword -Force | Out-Null

   ##Write Key
   CheckRegKey -RegKey $SubKey
   FillKey -RegKey $SubKey -RegValue $RegValue
}

Function IsAdmin
{
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()` 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
    
    return $IsAdmin
}

Function WaitForBoot()
{
    param($serviceName, $vmName)
    do
    {
        $vm = get-azurevm -ServiceName $serviceName -Name $vmName
        if($vm -eq $null)
        {
            Write-Host "WaitForBoot - could not connect to $serviceName - $vmName"
            return
        }
        if(($vm.InstanceStatus -eq "FailedStartingVM") -or ($vm.InstanceStatus -eq "ProvisioningFailed") -or ($vm.InstanceStatus -eq "ProvisioningTimeout"))
        {
            Write-Host "Provisioning of $vmName failed."
            return 
        }
        if($vm.InstanceStatus -eq "ReadyRole")
        {
            break
        }
        wait -msg "Waiting for $($vmName) to boot" -InSeconds 30 
    
    }while($true)
}

Function Use-RunAs 
{    
    # Check if script is running as Adminstrator and if not use RunAs 
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()` 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    if ($Check) { return $IsAdmin }     
 
    if ($MyInvocation.ScriptName -ne "") 
    {  
        if (-not $IsAdmin)  
        {  
            try 
            {  
                $arg = "-file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script with runas"  
                break               
            } 
            exit # Quit this session of powershell 
        }  
    }  
    else  
    {  
        Write-Warning "Error - Script must be saved as a .ps1 file first"  
        break  
    }  
} 

Function GetPasswordKeyByUserName()
{
	param([string]$userName, $serviceAccountList)
	[bool]$found = $false
	foreach($serviceAccount in $serviceAccountList)
	{
		if($serviceAccount.UserName -eq $userName)
		{
			$serviceAccount.PasswordKey
			$found = $true
		}
	}
	if(-not $found)
	{
		Write ("User name {0} not found in service account list" -f $userName)
	}
}

Function GetPasswordByUserName()
{
	param([string]$userName, $serviceAccountList)
	[bool]$found = $false
	foreach($serviceAccount in $serviceAccountList)
	{
		if($serviceAccount.UserName -eq $userName)
		{
			$serviceAccount.Password
			$found = $true
			break
		}
	}
	if(-not $found)
	{
		Write ("User name {0} not found in service account list" -f $userName)
	}
}

Function GetPasswordFromList()
{
	param([string]$passwordKey, $passwordList)
	[bool]$found = $false
	foreach($listedPassword in $passwordList)
	{
		if($listedPassword.Key -eq $passwordKey)
		{
			$listedPassword.Value
			$found = $true
		}
	}
	if(-not $found)
	{
		Write ("Password key {0} is not found in password list" -f $passwordKey)
	}
}

##GP 6/12/2014 moved from AutoConfigure.ps1
function randomString ($length = 6)
{

    $digits = 48..57
    $letters = 65..90 + 97..122
    $rstring = get-random -count $length `
            -input ($digits + $letters) |
                    % -begin { $aa = $null } `
                    -process {$aa += [char]$_} `
                    -end {$aa}
    return $rstring.ToString().ToLower()
}

##GP 6/12/2014 moved from AutoConfigure.ps1
function GetLatestImage
{
   param($imageFamily)
   $images = Get-AzureVMImage | where { $_.ImageFamily -eq $imageFamily } | Sort-Object -Descending -Property PublishedDate
   return $images[0].ImageName
}

##GP 06/12/2014 
## Copied MergeXMLChildren from CreateVNet.ps1
function local:MergeXmlChildren() 
{Param([System.Xml.XmlElement] $elem1, [System.Xml.XmlElement] $elem2, [string] $keyAttributeName)
	$elemCombined = $elem1

	# Get key values from $elem1
	$childNodeHash = @{}
	foreach($childNode in $elem1.ChildNodes)
	{
		$childNodeHash.Add($childNode.$keyAttributeName, $childNode)
	}
	
	foreach($childNode in $elem2.ChildNodes)
	{
		if(-not ($childNodeHash.Keys -contains $childNode.$keyAttributeName))
		{
			# Append children from $elem2 if there is no key conflict
			$importedNode = $elemCombined.AppendChild($elemCombined.OwnerDocument.ImportNode($childNode, $true))
		}
		elseif(-not $childNodeHash.Item($childNode.$keyAttributeName).OuterXml.Equals($childNode.OuterXml))
		{
			# Otherwise throw Exception
			Throw Write-Error ("Failed to merge XML element {0} because non-identical child elements with the same {1} are found." -f $elem1.Name, $keyAttributeName)
		}
	}
	
	$elemCombined
}

#Function to Create VNet
##GP 06/12/2014 
## Updated function, cleaned up verbosity
## Localized function
function local:CreateVNet() 
{Param([string]$scriptFolder)
   #Get the NetworkConfig.xml path
   $vnetConfigPath = (Join-Path -Path $scriptFolder -ChildPath "Config\AD-VNET\NetworkConfig.xml")
   $vnetConfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($vnetConfigPath)

##GP 6/12/2014 
#	Write-Output $vnetConfigPath
	(Get-AzureSubscription -Current).SubscriptionName
   Write-Host "Creating VNet COnfiguration file"
   Write-Host "   Reading $($vnetConfigPath)" -NoNewline
   $outputVNetConfigPath = "$env:temp\spvnet.xml"
   $inputVNetConfig = [xml] (Get-Content $vnetConfigPath)
   Write-Host -ForegroundColor Green "... Completed"

   Write-Host "   Reading Current Azure VNet configuration" -NoNewline
   #Get current VNet Configuration
   $currentVNetConfig = [xml] (Get-AzureVNetConfig).XMLConfiguration
   Write-Host -ForegroundColor Green "... Completed"
	
   Write-Host "   Merging VNet Configurations" -NoNewline
	#If no configuration found just use the new configuration
   if($currentVNetConfig.NetworkConfiguration -eq $null)
	{
		$combinedVNetConfig = $inputVNetConfig
	}
   else
	{
		# If VNet already exists and identical do nothing
		$inputVNetSite = $inputVNetConfig.SelectSingleNode("/*/*/*[name()='VirtualNetworkSites']/*[name()='VirtualNetworkSite']")
		$existingVNetSite = $currentVNetConfig.SelectSingleNode("/*/*/*[name()='VirtualNetworkSites']/*[name()='VirtualNetworkSite'][@name='" + $inputVNetSite.name + "']")
		if($existingVNetSite -ne $null -and $existingVNetSite.AddressSpace.OuterXml.Equals($inputVNetSite.AddressSpace.OuterXml) `
			-and $existingVNetSite.Subnets.OuterXml.Equals($inputVNetSite.Subnets.OuterXml))
		{
			write-host;Write-Host -ForegroundColor Red ("A VNet with name {0} and identical configuration already exists." -f $inputVNetSite.name)
			return
		}
		
		$combinedVNetConfig = $currentVNetConfig
		
		#Combine DNS Servers
		$dnsNode = $combinedVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns
		if($dnsNode -ne $null)
		{
			$inputDnsServers = $inputVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers
			$newDnsServers = MergeXmlChildren $dnsNode.DnsServers $inputDnsServers "name"
			$dnsNode.ReplaceChild($newDnsServers, $dnsNode.DnsServers)
		}
		elseif($currentVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns -ne $null)
		{
			$combinedVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.InsertBefore($currentVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns,
				$combinedVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites)
		}
		
		#Combine VNets
        $virtualNetworkConfigurationNode = $combinedVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration
        
        # If VNET Config exists but there are no currently defined sites
        if($virtualNetworkConfigurationNode.VirtualNetworkSites -ne $null)
        {        
            $inputVirtualNetworkSites = $inputVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites    
            $virtualNetworkConfigurationNode.ReplaceChild((MergeXmlChildren $virtualNetworkConfigurationNode.VirtualNetworkSites $inputVirtualNetworkSites "name"), $virtualNetworkConfigurationNode.VirtualNetworkSites)
        }
        else
        {
            $inputVirtualNetworkSites = $inputVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites
            $vns = $combinedVNetConfig.CreateElement("VirtualNetworkSites", $combinedVNetConfig.DocumentElement.NamespaceURI)
            $vns.InnerXML = $inputVirtualNetworkSites.InnerXml
            $combinedVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.AppendChild($vns)
        }
	}
   Write-Host -ForegroundColor Green "... Completed"

   Write-Host "   Saving VNet file to $($outputVNetConfigPath)" -NoNewline
   #Call the Set-AzureVNetConfig cmdlet with required parameters
   $combinedVNetConfig.Save($outputVNetConfigPath)
   Write-Host -ForegroundColor Green "... Completed"

   #Set-AzureVNetConfig -ConfigurationPath $outputVNetConfigPath
   #Added OutVariable for later status checking
   Write-Host "   Setting VNet configuration" -NoNewline
   Set-AzureVNetConfig -ConfigurationPath $outputVNetConfigPath -WarningAction SilentlyContinue | Out-Null
   Write-Host -ForegroundColor Green "... Completed"
   Write-Host "VNet Configuration file creation completed.";Write-Host

}

#Function to Create Affinity Group
function CreateAffinityGroup()
{	
   param([string]$vmLocation,[string]$affinityGroupName)
   #Call the New-AzureAffinityGroup cmdlet with required parameters
   $affinityGroupExists = $false
   Get-AzureAffinityGroup | ForEach-Object {if($_.Name -eq $affinityGroupName) {$affinityGroupExists = $true } }
   if(-not $affinityGroupExists)
   {
   #New-AzureAffinityGroup -Name $affinityGroupName -Location $vmLocation -verbose
   New-AzureAffinityGroup -Name $affinityGroupName -Location $vmLocation | Out-Null
   #Write-Host $Result
   }
   else
   {
   Write-Host "Affinity group already exists."
   }
}

function local:AddEndPoints()
{
   param($vmConfig,$endPoints)

   if ($endPoints -ne $null)
   {
      Write-Host "   Adding Endpoint(s)"
      foreach($ep in $endPoints) 
      {
         if($ep.LBSetName -ne "") 
         {
            Write-Host "      Adding Load Balanced Endpoint <$($ep.Name) - $($ep.PublicPort)>"
            Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort -LBSetName $ep.LBSetName -ProbeProtocol $ep.ProbeProtocol -ProbePath $ep.ProbePath -ProbePort $ep.ProbePort | Out-Null
         }
         else 
         {
            Write-Host "      Adding Endpoint <$($ep.Name) - $($ep.PublicPort)>"
            Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort | Out-Null
         }
      }
      Write-Host "   Endpoint Processing Completed"
   }
   else
   {
      Write-Host "   No Endpoint(s) added"
   }
}

function local:AddDisks() 
{
   param($vmConfig, $dataDisks)
   
   if ($dataDisks -ne $null)
   {
      Write-Host "   Adding Data disk(s)"
      for($i=0; $i -lt $dataDisks.Count; $i++)
      {
         $fields = $dataDisks[$i].Split(':')
         $dataDiskLabel = [string] $fields[0]
         $dataDiskSize = [string] $fields[1]
         Write-Host ("      {0} size {1}" -f $dataDiskLabel, $dataDiskSize)	

         #Add Data Disk to the newly created VM
         $vmConfig | Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiskSize -DiskLabel $dataDiskSize -LUN $i | Out-Null
      }
         Write-Host "   Disk Processing Completed"
   }
   else
   {
      Write-Host "   No Data disk(s) added"
   }

}

Function CreateDomainJoinedAzureVmIfNotExists()
{
	param([string]$serviceName, [string]$vmName, [string] $size, [string]$imageName, [string]$availabilitySetName, [string[]] $dataDisks,
	[string]$vnetName, [string]$subnetNames,[string]$affinityGroup, [string]$adminUsername, [string]$adminPassword, 
	[string] $domainDnsName, [string] $domainInstallerUsername, [string] $domainInstallerPassword, $endPoints)

	# Create VM if one with the specified name doesn't exist
	$existingVm = Get-AzureVM -ServiceName $serviceName -Name $vmName
	if($existingVm -eq $null)
	{
	  Write-Host "Setting VM Configuration..." -NoNewline ; Write-Host -ForegroundColor Green " <$($vmName)>"
	  $domainInstallerInfo = $domainInstallerUsername.Split('\')
	  $domainName = $domainInstallerInfo[0]
	  $domainUsername = $domainInstallerInfo[1]
     
	  $vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize $size -ImageName $imageName -AvailabilitySetName $availabilitySetName | `
	  Add-AzureProvisioningConfig -WindowsDomain -Password $adminPassword -AdminUsername $adminUserName -JoinDomain $domainDnsName `
	  -Domain $domainName -DomainUserName $domainUsername -DomainPassword $domainInstallerPassword | Set-AzureSubnet -SubnetNames $subnetNames

     ## Localized Disks
     AddDisks -dataDisks $dataDisks -vmConfig $vmConfig
     
##	  for($i=0; $i -lt $dataDisks.Count; $i++)
##	  {
##	  	$fields = $dataDisks[$i].Split(':')
##		$dataDiskLabel = [string] $fields[0]
##	  	$dataDiskSize = [string] $fields[1]
##	  	Write-Host ("Adding disk {0} with size {1}" -f $dataDiskLabel, $dataDiskSize)	
##		
##		#Add Data Disk to the newly created VM
##		$vmConfig | Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiskSize -DiskLabel $dataDiskSize -LUN $i | Out-Null
##	  }

     ## Localized EndPoints
     AddEndPoints -Endpoints $Endpoints -vmConfig $vmConfig
     
##	  foreach($ep in $Endpoints)
##      {
##        if($ep -ne $null)
##        {
##            if($ep.LBSetName -ne "")
##            {
##                Write-Host "Adding Load Balanced Endpoint"
##                Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort -LBSetName $ep.LBSetName -ProbeProtocol $ep.ProbeProtocol -ProbePath $ep.ProbePath -ProbePort $ep.ProbePort | out-Null
##	        }
##            else
##            {
##                Write-Host "Adding Endpoint"
##                Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort | Out-Null
##            }
##        }
##      }		  
      
      Write-Host "VM Configuration complete"

      Write-Host "Deploying VM..." -NoNewline ; Write-Host -ForegroundColor Green " <$($vmName)>"
      $existingService = Get-AzureService -ServiceName $serviceName -ErrorAction SilentlyContinue
      if($existingService -eq $null) 
	  {
		  $vmConfig | New-AzureVM -ServiceName $serviceName -AffinityGroup $affinityGroup -VNetName $vnetName -WaitForBoot -Verbose
	  }
	  else
	  {
		  $vmConfig | New-AzureVM -ServiceName $serviceName -WaitForBoot -Verbose	  	
	  }

     Write-Host "VM Deployment complete"
      
      InstallWinRMCertificateForVM $serviceName $vmName
      wait -msg "Pausing for services to start" -InSeconds 300 
	}
	else
	{
	  Write-Host ("VM with Service Name {0} and Name {1} already exists." -f $serviceName, $vmName)
	}
}

##GP 06/12/2014 
## Updated function, cleaned up verbosity, Added DCMode defaults to NONE
## Localized function
Function CreateAzureVmIfNotExists()
{
	param([string]$serviceName, [string]$vmName, [string] $size, [string]$imageName, [string]$availabilitySetName, [string[]] $dataDisks,
	[string]$vnetName, [string]$subnetNames,[string]$affinityGroup, [string]$adminUsername, [string]$adminPassword, [string] $location, 
   [string] $dcInstallMode="StandAlone", [string] $dnsDomain, [string]$netBiosDomainName, [string]$scriptFolder, $endPoints)
	
#[string] $domainDnsName, [string] $domainInstallerUsername, [string] $domainInstallerPassword

	 #Create Affinity Group 
    CreateAffinityGroup -vmLocation $location -affinityGroupName $affinityGroup
    
    #Create a Point to Site VNet
    CreateVNet -scriptFolder $scriptFolder

	 Write-Host "Setting VM Configuration..." -NoNewline ; Write-Host -ForegroundColor Green " <$($vmName)>"
    # Create VM if one with the specified name doesn't exist
	$existingVm = Get-AzureVM -ServiceName $serviceName -Name $vmName -WarningAction SilentlyContinue
	if($existingVm -eq $null)
	  {
      $vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize $size -ImageName $imageName -AvailabilitySetName $availabilitySetName | `
      Add-AzureProvisioningConfig -Windows -Password $adminPassword -AdminUsername $adminUserName  | Set-AzureSubnet -SubnetNames $subnetNames 

      ## Localized Disks
      AddDisks -dataDisks $dataDisks -vmConfig $vmConfig

##	    for($i=0; $i -lt $dataDisks.Count; $i++)
##	      {
##	  	    $fields = $dataDisks[$i].Split(':')
##		    $dataDiskLabel = [string] $fields[0]
##	  	    $dataDiskSize = [string] $fields[1]
##	  	    Write-Host ("   Adding disk {0} with size {1}" -f $dataDiskLabel, $dataDiskSize)	
##		
##		    #Add Data Disk to the newly created VM
##		    $vmConfig | Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiskSize -DiskLabel $dataDiskSize -LUN $i -OutVariable $Result | Out-Null
##	      }

      ## Localized EndPoints
      AddEndPoints -Endpoints $Endpoints -vmConfig $vmConfig
      
##	    foreach($ep in $endPoints)
##          {
##            if($ep -ne $null)
##            {
##                if($ep.LBSetName -ne "")
##                {
##                    Write-Host "Adding Load Balanced Endpoint"
##                    Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort -LBSetName $ep.LBSetName -ProbeProtocol $ep.ProbeProtocol -ProbePath $ep.ProbePath -ProbePort $ep.ProbePort 
##                }
##                else
##                {
##                   Write-Host "Adding Endpoint"
##                   Add-AzureEndpoint -VM $vmConfig -Name $ep.Name -Protocol $ep.Protocol -LocalPort $ep.LocalPort -PublicPort $ep.PublicPort 
##                }
##            }
##          }

      Write-Host "VM Configuration complete"

      Write-Host "Deploying VM..." -NoNewline ; Write-Host -ForegroundColor Green " <$($vmName)>"
      $existingService = Get-AzureService -ServiceName $serviceName -ErrorAction SilentlyContinue
      if($existingService -eq $null) 
      {
       $vmConfig | New-AzureVM -ServiceName $serviceName -AffinityGroup $affinityGroup -VNetName $vnetName -WaitForBoot -Verbose
      }
      else
      {
      Wait -msg "Install Mode $($dcInstallMode)" -InSeconds 5
         switch ($dcInstallMode)
         {
         "NewForest" {
         	#Create the Remote PS enabled Primary DC VM	
             $vmConfig | Add-AzureProvisioningConfig -Windows -Password $adminPassword -AdminUserName $adminUserName 
             New-AzureVM -ServiceName $serviceName -AffinityGroup $affinityGroup -VNetName $vnetName -VMs $vmConfig -WaitForBoot -Verbose
         }
         "Replica" {
         	$vmConfig | Add-AzureProvisioningConfig -WindowsDomain -Password $adminPassword -AdminUserName $adminUserName -JoinDomain $dnsDomain -Domain $netBiosDomainName -DomainPassword $adminPassword -DomainUserName $adminUserName 
             New-AzureVM -ServiceName $serviceName -VMs $vmConfig -WaitForBoot -Verbose
         }
         default {
             $vmConfig | New-AzureVM -ServiceName $serviceName -WaitForBoot -Verbose 
         }
         }
      }

      Write-Host "VM Deployment complete"
      InstallWinRMCertificateForVM $serviceName $vmName
      wait -msg "Pausing for services to start" -InSeconds 300 
	}
	else
	{
	  Write-Host ("VM with Service Name {0} and Name {1} already exists." -f $serviceName, $vmName)
	}
}

Function EnableCredSSPServerIfNotEnabledBackwardCompatible()
{
param([string] $serviceName, [string] $vmName, [string] $adminUser, [string] $adminPassword)
	$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName
	$adminCredential = new-object pscredential($adminUser, (ConvertTo-SecureString $adminPassword -AsPlainText -Force))
    $maxRetry = 5
    For($retry = 0; $retry -le $maxRetry; $retry++)
    {
        Try
        {
	        Invoke-Command -ComputerName $uris[0].DnsSafeHost -Credential $adminCredential -Port $uris[0].Port -UseSSL `
		        -ArgumentList $adminUser, $adminPassword -ScriptBlock {
		        param([string] $adminUser, [string] $adminPassword)
		        Set-ExecutionPolicy Unrestricted -Force
		        $is2012 = [Environment]::OSVersion.Version -ge (new-object 'Version' 6,2,9200,0)
		        if($is2012)
		        {
			        $line = winrm g winrm/config/service/auth | Where-Object {$_.Contains('CredSSP = true')}
			        $isCredSSPServerEnabled = -not [string]::IsNullOrEmpty($line)
			        if(-not $isCredSSPServerEnabled)
			        {
			            Write-Host "Enabling CredSSP Server..."
				        winrm s winrm/config/service/auth '@{CredSSP="true"}'
				        Write-Host "CredSSP Server is enabled."
			        }
			        else
			        {
				        Write-Host "CredSSP Server is already enabled."
			        }
		        }
		        else
		        {
			        schtasks /CREATE /TN "EnableCredSSP" /SC ONCE /SD 01/01/2020 /ST 00:00:00 /RL HIGHEST /RU $adminUser /RP $adminPassword /TR "winrm set winrm/config/service/auth @{CredSSP=\""True\""}" /F
			        schtasks /RUN /I /TN "EnableCredSSP"
		        }
	        }
            break
        }
	    Catch [System.Exception]
	    {
		  wait -msg "Error - retrying..." -InSeconds 30
	    }
    }
    wait -msg "Pausing to Allow CredSSP Scheduled Task to Execute on $($vmName)" -InSeconds 30
}

Function EnableCredSSPServerIfNotEnabled()
{
param([string] $serviceName, [string] $vmName, [Management.Automation.PSCredential] $adminCredential)
	$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName
    $maxRetry = 5
    For($retry = 0; $retry -le $maxRetry; $retry++)
    {
        Try
        {
	        Invoke-Command -ComputerName $uris[0].DnsSafeHost -Credential $adminCredential -Port $uris[0].Port -UseSSL `
		        -ScriptBlock {
		        Set-ExecutionPolicy Unrestricted -Force
              Write-Host "Checking CredSSP status on $($using:vmName)..." -NoNewline

		        $line = winrm g winrm/config/service/auth | Where-Object {$_.Contains('CredSSP = true')}
		        $isCredSSPServerEnabled = -not [string]::IsNullOrEmpty($line)
		        if(-not $isCredSSPServerEnabled)
		        {
               Write-Host "Enabling..." -NoNewline
               winrm s winrm/config/service/auth '@{CredSSP="true"}'  | Out-Null
               Write-Host "... Completed" -ForegroundColor Green
		        }
		        else
		        {
			        Write-Host "Skipping already enabled" -ForegroundColor Yellow
		        }
	        }
            break
        }
	    Catch [System.Exception]
	    {
          wait -msg "Error - retrying..." -InSeconds 30
        }
    }
    wait -msg "Pausing to allow CredSSP to be enabled $($vmName)" -InSeconds 30
}

Function InstallWinRMCertificateForVM()
{
param([string] $serviceName, [string] $vmName)
##GP 06/08/2014
   Write-Host "Installing WinRM Certificate for remote access: <$($serviceName)> <$($vmName)> " -NoNewline
	$WinRMCert = (Get-AzureVM -ServiceName $serviceName -Name $vmName | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
	$AzureX509cert = Get-AzureCertificate -ServiceName $serviceName -Thumbprint $WinRMCert -ThumbprintAlgorithm sha1

	$certTempFile = [IO.Path]::GetTempFileName()
	$AzureX509cert.Data | Out-File $certTempFile

	# Target The Cert That Needs To Be Imported
	$CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile

	$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
	$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
	$store.Add($CertToImport)
	$store.Close()
	
	Remove-Item $certTempFile
##GP 06/08/2014
   Write-Host -ForegroundColor Green "... Completed"
}

Function local:FormatDisk()
{
#	Param([string]$serviceName,[string]$vmName,[string]$adminUserName,[string]$password)
	Param([System.Uri]$uris, [System.Management.Automation.PSCredential]$credential)

   Write-Host "Formatting data disks..." -NoNewline

#   $uris = Get-AzureWinRMUri -ServiceName $ServiceName -Name $vmName
#   $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
#   $credential = New-Object System.Management.Automation.PSCredential($adminUserName, $secPassword)

    $maxRetry = 5
    For($retry = 0; $retry -le $maxRetry; $retry++)
    {
        Try
        {
	      #Create a new remote ps session and pass in the scrip block to be executed

          Invoke-Command -ConnectionUri $URIS.ToString() -Credential $Credential -OutVariable $Result -ScriptBlock { 		
		        Set-ExecutionPolicy Unrestricted -Force

		        $drives = gwmi Win32_diskdrive
		        $scriptDisk = $Null
		        $script = $Null
		
		        #Iterate through all drives to find the uninitialized disk
		        foreach ($disk in $drives){
	    	        if ($disk.Partitions -eq "0"){
	                $driveNumber = $disk.DeviceID -replace '[\\\\\.\\physicaldrive]',''     
                   Write-Host " $($driveNumber)" -NoNewline
$script = @"
select disk $driveNumber
online disk noerr
attributes disk clear readonly noerr
create partition primary noerr
format quick
"@
			        }
			        $driveNumber = $Null
			        $scriptDisk += $script + "`n"
                    $script = $Null
		        }
		        #output diskpart script
		        $scriptDisk | Out-File -Encoding ASCII -FilePath "c:\Diskpart.txt" 
		        #execute diskpart.exe with the diskpart script as input
		        diskpart.exe /s c:\Diskpart.txt >> C:\DiskPartOutput.txt

		        #assign letters and labels to initilized physical drives
		        $volumes = gwmi Win32_volume | where {$_.BootVolume -ne $True -and $_.SystemVolume -ne $True -and $_.DriveType -eq "3"}
		        $letters = 68..89 | ForEach-Object { ([char]$_)+":" }
		        $freeletters = $letters | Where-Object { 
	  		        (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
		            }
		        foreach ($volume in $volumes){
	    	        if ($volume.DriveLetter -eq $Null){
	        	        mountvol $freeletters[0] $volume.DeviceID
	    	        }
		        $freeletters = $letters | Where-Object { 
	    	        (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
		            }
		        }
	        }
            break
        }
        Catch [System.Exception]
	    {
          wait -msg "Error - retrying..." -InSeconds 30
	    }
    }
    Write-Host -ForegroundColor Green " ... Formatting complete"
	################## Function execution end #############
}

Function EnsureSPDatabasesInAvailabilityGroup()
{param(
[string] $spServerServiceName,
[string] $spServerName,
[string] $spInstallerDatabaseUsername,
[string] $spFarmDomainUsername,
[string] $sqlClusterServiceName,
[string] $sqlServerPrimary,
[string] $sqlServerSecondary,
[string] $installerDomainUsername,
[string] $installerDomainPassword,
[string] $availabilityGroup
)
	#Get the hosted service WinRM Uri
	$spuris = Get-AzureWinRMUri -ServiceName $spServerServiceName -Name $spServerName
	$uris = Get-AzureWinRMUri -ServiceName $sqlClusterServiceName -Name $sqlServerPrimary
	$uris2 = Get-AzureWinRMUri -ServiceName $SqlClusterServiceName -Name $sqlServerSecondary

	$secPassword = ConvertTo-SecureString $installerDomainPassword -AsPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential($installerDomainUsername, $secPassword)

	$configdb, $cadb, $databases = Invoke-Command -ComputerName $spuris[0].DnsSafeHost -Authentication Credssp -Credential $credential -Port $spuris[0].Port -UseSSL `
	-ArgumentList $sqlServerSecondary -ScriptBlock {
	param([string]$failoverInstance)
		Add-PSSnapin Microsoft.SharePoint.PowerShell
		$configdb = (Get-SPFarm).Name
		$configdb
		$cawebapp=Get-SPWebApplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
		$cadb = $cawebapp.ContentDatabases.Name
		$cadb
		Get-SPDatabase | ForEach-Object {
			$_.AddFailoverServiceInstance($failoverInstance) 
			$_.Update()
			Write-Host ("Updated database {0} with failover instance." -f $_.Name) 
			$_.Name
		}
	}
	
	#Back up SharePoint databases to backup share and add them to availability group if not already added
	Invoke-Command -ComputerName $uris[0].DnsSafeHost -Credential $credential -Authentication Credssp -Port $uris[0].Port -UseSSL `
	-ArgumentList $sqlServerPrimary, $sqlServerSecondary, $availabilityGroup, $spInstallerDatabaseUsername, $spFarmDomainUsername, $configdb, $cadb, $databases -ScriptBlock {
		param
		(
		[String]$serverPrimary, 
		[String]$serverSecondary, 
		[String]$ag,
		[String]$spdbaccess,
		[String]$spfarm,
		[String]$configdb,
		[String]$cadb,
		[String[]] $databases,
		[String]$backupShare = "\\$serverPrimary\backup"
		)
		$timeout = New-Object System.TimeSpan -ArgumentList 0, 0, $timeoutsec

		Set-ExecutionPolicy RemoteSigned -Force
		Import-Module "sqlps" -DisableNameChecking

		Invoke-Sqlcmd -Query "ALTER DATABASE UPA1_PROFILE SET RECOVERY FULL"
		Invoke-Sqlcmd -Query "ALTER DATABASE UPA1_SOCIAL SET RECOVERY FULL"
		Invoke-Sqlcmd -Query "ALTER DATABASE UPA1_SYNC SET RECOVERY FULL"
		Invoke-Sqlcmd -Query "ALTER DATABASE Search15_AdminDB SET RECOVERY FULL"
        Invoke-Sqlcmd -Query "ALTER DATABASE Search15_AdminDB_AnalyticsReportingStore SET RECOVERY FULL"
        Invoke-Sqlcmd -Query "ALTER DATABASE Search15_AdminDB_CrawlStore SET RECOVERY FULL"
        Invoke-Sqlcmd -Query "ALTER DATABASE Search15_AdminDB_LinksStore SET RECOVERY FULL"
        Invoke-Sqlcmd -Query "ALTER DATABASE WSS_UsageApplication SET RECOVERY FULL"

		$dbsInAvailabilityGroup = dir "SQLSERVER:\SQL\$serverPrimary\Default\AvailabilityGroups\$ag\AvailabilityDatabases" | ForEach-Object {$_.Name}
		foreach($db in $databases)
		{
			Backup-SqlDatabase -Database $db -BackupFile "$backupShare\$db.bak" -ServerInstance $serverPrimary `
			-Initialize
			Backup-SqlDatabase -Database $db -BackupFile "$backupShare\$db.log" -ServerInstance $serverPrimary `
			-BackupAction Log -Initialize
			Write-Host ("Database {0} backed up to {1}." -f $db, $backupShare)
			
			if(($dbsInAvailabilityGroup | Where-Object {$_ -eq $db}) -eq $null)
			{
				Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$serverPrimary\Default\AvailabilityGroups\$ag" -Database $db
				Write-Host ("Database {0} added to Availability Group {1}." -f $db, $ag)
			}
		}
	}
	
	#Restore SharePoint each database from backup folder if it doesn't already exist in availability group
	#Add db access account to db_owner role of SharePoint config db and CA content db
	#Add spfarm to all other content dbs
	Invoke-Command -ComputerName $uris2[0].DnsSafeHost -Authentication Credssp -Credential $credential -Port $uris2[0].Port -UseSSL `
	-ArgumentList  $sqlServerPrimary, $sqlServerSecondary, $availabilityGroup, $spInstallerDatabaseUsername, $spFarmDomainUsername, $configdb, $cadb, $databases {
		param
		(
		[String]$serverPrimary, 
		[String]$serverSecondary, 
		[String]$ag,
		[String]$spdbaccess,
		[String]$spfarm,
		[String]$configdb,
		[String]$cadb,
		[String[]]$databases, 
		[String]$backupShare = "\\$serverPrimary\backup"
		)

		Set-ExecutionPolicy RemoteSigned -Force
		Import-Module "sqlps" -DisableNameChecking

		$dbsInAvailabilityGroup = dir "SQLSERVER:\SQL\$serverSecondary\Default\AvailabilityGroups\$ag\AvailabilityDatabases" `
		| Where-Object {$_.IsJoined} | ForEach-Object {$_.Name}
		foreach($db in $databases)
		{
			if(($dbsInAvailabilityGroup | Where-Object {$_ -eq $db}) -eq $null)
			{
				Restore-SqlDatabase -Database $db -BackupFile "$backupShare\$db.bak" -ServerInstance $serverSecondary `
				-NoRecovery -ReplaceDatabase
				Restore-SqlDatabase -Database $db -BackupFile "$backupShare\$db.log" -ServerInstance $serverSecondary `
				-RestoreAction Log -NoRecovery
				Write-Host ("Database {0} restored from {1}." -f $db, $backupShare)
				
				Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$serverSecondary\Default\AvailabilityGroups\$ag" -Database $db
				Write-Host ("Database {0} added to Availability Group {1}." -f $db, $ag)
			}
		}
		
		Start-Sleep -Seconds 120
		Switch-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$serverSecondary\Default\AvailabilityGroups\$ag"
		Write-Host ("Failed over availability group {0} to instance {1}." -f $ag, $serverSecondary)

		foreach($db in $databases)
		{
			Invoke-SqlCmd ("use {0}; create user [{1}] from login [{1}]; alter role db_owner add member [{1}]" -f $db, $spdbaccess)
			Write-Host ("{0} added to db_owner role for database {1}." -f $spdbaccess, $db)
		}

		Start-Sleep -Seconds 120
        wait -msg "Configuring SQL Databases" -InSeconds 120
		Switch-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$serverPrimary\Default\AvailabilityGroups\$ag"
		Write-Host ("Failed over availability group {0} to instance {1}." -f $ag, $serverPrimary)
	}
}

function local:AddServiceAccount() 
{
Param(
	[System.Uri]$uris, 
   [System.Management.Automation.PSCredential]$credential,
   [string]$ouName,
   [string]$adUserName,
   [string]$samAccountName,
   [string]$displayName,
   [string]$accountPassword
)

 Invoke-Command -ConnectionUri $uris.ToString() -Credential $credential -Scriptblock {
   Param(
      [string]$ouName,
      [string]$adUserName,
      [string]$samAccountName,
      [string]$displayName,
      [string]$accountPassword
   )

   Set-ExecutionPolicy Unrestricted -Force

   # Get the logged-on user's domain in DN form 
   $myDom = (get-addomain).distinguishedname 
 
   # Build the full DN of the target OU 
   $ouDn = "OU=$ouName,$myDom" 
 
   # Check if the target OU exists. If not, create it. 
   $ou = get-adorganizationalunit -Filter { name -eq $ouName } 
   if($ou -eq $null){
      Write-Host "Creaing OU $($ouName)" -NoNewline
      New-ADOrganizationalUnit -Name $ouName -Path $myDom | Out-Null
      Write-Host -ForegroundColor Green " ... Completed"}
   else  
      {write-host "The OU " $ou " already exists."} 
 
   Write-Host "Checking user $($adUserName) " -NoNewline
   $user = Get-ADUser -Filter { Name -eq $adUserName }
   if($user -eq $null){
      Write-Host "...Creating" -NoNewline
      New-ADUser –Name $adUserName –SamAccountName $samAccountName –DisplayName $displayName -Path $ouDn –Enabled $true `
      –ChangePasswordAtLogon $false -AccountPassword (ConvertTo-SecureString $accountPassword -AsPlainText -force) -PassThru | Out-Null
      Write-Host -ForegroundColor Green " ... Completed" 
   } 
   else {      Write-Host "... already exists skipping"}
   
 } -ArgumentList $ouName, $adUserName, $samAccountName, $displayName, $accountPassword

}

function local:SetCredential () 
{
param (
[parameter(Mandatory=$true)][string]$UserName,
[parameter(Mandatory=$true)][string]$Password
)

$oPassword = ConvertTo-SecureString $password -AsPlainText -Force
return (New-Object System.Management.Automation.PSCredential($UserName, $oPassword))

}