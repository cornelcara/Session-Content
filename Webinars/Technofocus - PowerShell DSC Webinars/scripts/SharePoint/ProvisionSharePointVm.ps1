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

#Command line arguments
param(
$subscriptionName,
$storageAccount,
$serviceName,
$vmName,
$vmSize,
$imageName,
$availabilitySetName,
$dataDisks,
$adminUsername,
$adminPassword,
$appPoolAccount,
$appPoolPassword,
$subnetNames,
$domainDnsName,
$domainInstallerUsername,
$domainInstallerPassword,
$databaseInstallerUsername,
$databaseInstallerPassword,
$spFarmUsername,
$spFarmPassword,
$createFarm,
$affinityGroup,
$sqlServer,
$configDbName,
$adminContentDbName,
$spFarmParaphrase,
$spServicesToStart,
$endPoints
)


# Create credential object
$secPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $secPassword)

#$domainSecPassword = ConvertTo-SecureString $installerDomainPassword -AsPlainText -Force
#$installerDomainCredential = New-Object System.Management.Automation.PSCredential($installerDomainUsername, $domainSecPassword)

## Ensure correct subscription and storage account is selected
#Select-AzureSubscription -SubscriptionName $subscriptionName
Set-AzureSubscription $subscriptionName -CurrentStorageAccount $storageAccount


CreateDomainJoinedAzureVmIfNotExists `
   -serviceName $serviceName  `
   -vmName $vmName  `
   -size $vmSize  `
   -imageName $imageName  `
   -availabilitySetName $availabilitySetName  `
   -dataDisks $dataDisks `
   -vnetName $vnetName  `
   -subnetNames $subnetNames  `
   -affinityGroup $affinityGroup `
   -adminUsername $adminUserName `
   -adminPassword $adminPassword `
   -domainDnsName $domainDnsName `
   -domainInstallerUsername $domainInstallerUsername `
   -domainInstallerPassword $domainInstallerPassword `
   -endPoints $endPoints


Write-Host
#Get the hosted service WinRM Uri
[System.Uri]$uris = (GetVMConnection -ServiceName $serviceName -vmName $vmName)
if ($uris -eq $null){return}

$Credential = (SetCredential -Username $domainInstallerUsername -Password $domainInstallerPassword)
FormatDisk `
   -uris $uris `
   -Credential $Credential

## Perform installation
#$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName
#Invoke-Command -ComputerName $uris[0].DnsSafeHost -Credential $installerDomainCredential -Authentication Credssp -Port $uris[0].Port -UseSSL `

##Invoke-Command -ConnectionUri $URIS.ToString() -Credential $Credential -OutVariable $Result `

EnableCredSSPServerIfNotEnabled $serviceName $vmName $Credential

Invoke-Command -ComputerName $uris[0].DnsSafeHost -Credential $Credential -Authentication Credssp -Port $uris[0].Port -UseSSL `
   -ArgumentList $createFarm, $sqlServer, $configDbName, $adminContentDbName, $databaseInstallerUsername, $databaseInstallerPassword, `
   $spFarmUsername, $spFarmPassword, $spFarmParaphrase, $spServicesToStart, $serviceName, $vmName, $appPoolAccount, $appPoolPassword -ScriptBlock {
   param($createFarm, $sqlServer, $configDbName, $adminContentDbName, $databaseInstallerUsername, $databaseInstallerPassword, `
   $spFarmUsername, $spFarmPassword, $spFarmParaphrase, $spServicesToStart, $serviceName, $vmName, $appPoolAccount, $appPoolPassword, $timeoutsec = 30)
	
   ## Local Function(s) within the Invoke block
   function local:CommonInstall(){
      # Install help collections
		Write-Host "Install help collections..." -NoNewline
		Install-SPHelpCollection -All | Out-Null
      Write-Host -ForegroundColor Green "... Completed"
			
		# Secure the SharePoint resources
		Write-Host "Securing SharePoint resources..." -NoNewline
		Initialize-SPResourceSecurity | Out-Null
      Write-Host -ForegroundColor Green "... Completed"
				
		# Install services
		Write-Host "Installing services..." -NoNewline
		Install-SPService | Out-Null
      Write-Host -ForegroundColor Green "... Completed"
				
		# Install application content files
		Write-Host "Installing application content files..." -NoNewline
		Install-SPApplicationContent | Out-Null
      Write-Host -ForegroundColor Green "... Completed"

		# Register SharePoint features
		Write-Host "Registering SharePoint features..." -NoNewline
		Install-SPFeature -AllExistingFeatures -Force | Out-Null
      Write-Host -ForegroundColor Green "... Completed"   
   
   }
   function local:RestartSP4Timer(){
      Write-Host -NoNewline "Checking SPTimerV4 service"
		$timersvc = Get-Service -Name 'SPTimerV4'
		if($timersvc.Status -ne 'Running')
		{
         Start-Service $timersvc
         $timersvc.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,$timeout)
#         Write-Host ("{0} started." -f $timersvc.DisplayName)
         Write-Host -ForegroundColor Green "...Started"
		}
      else {Write-Host -ForegroundColor Green "...Running"}
   }
   function local:EnableFirewall(){
      Write-Host "Enabling ICMP for PING" -NoNewline
      & netsh advfirewall firewall set rule name="File and Printer Sharing (Echo Request - ICMPv4-In)" new enable=yes | Out-Null
      Write-host -ForegroundColor Green "... Completed" 
   }
   ## End local function(s)
   
   $timeout = New-Object System.TimeSpan -ArgumentList 0, 0, $timeoutsec

   $ProgressPreference = "SilentlyContinue"
   Add-PSSnapin Microsoft.SharePoint.PowerShell -WarningAction SilentlyContinue

   # disable loopback to fix 401s from SP Webs Service calls
   New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name “DisableLoopbackCheck” -value "1" -PropertyType dword
   
   #Enable Firewall
   EnableFirewall
   
   Write-Host -ForegroundColor Yellow "`nProvisioning SharePoint on server <$($using:vmName)>"
   $spfarm = $null 
   try
   { $spfarm = Get-SPFarm -ErrorAction SilentlyContinue }
   catch
   { Write-Host "This server is not in a SharePoint farm." }
 
   if($spfarm -eq $null) {

      # Create or connect to database and farm
   	$databaseSecPassword = ConvertTo-SecureString $databaseInstallerPassword -AsPlainText -Force
   	$databaseCredential = New-Object System.Management.Automation.PSCredential $databaseInstallerUsername, $databaseSecPassword
   	$farmSecPassword = ConvertTo-SecureString $spFarmPassword -AsPlainText -Force
   	$farmCredential = New-Object System.Management.Automation.PSCredential $spFarmUsername, $farmSecPassword
 

      if($createFarm)
   	{

         Write-Host "`nCreating farm..." -NoNewline
         New-SPConfigurationDatabase -DatabaseName $configDbName -DatabaseServer $sqlServer -AdministrationContentDatabaseName $adminContentDbName `
         -Passphrase (ConvertTo-SecureString $spFarmParaphrase -AsPlainText -Force) -DatabaseCredential $databaseCredential -FarmCredentials $farmCredential
         Write-Host -ForegroundColor Green "... Created." 

         # ensure SharePoint Timer Service is started
         RestartSP4Timer
         
         ##Execute common install
         CommonInstall

   		# Provision SharePoint Central Admin web application
   		Write-Host "Provisioning Central Admin web app..." -NoNewline
   		New-SPCentralAdministration -Port 20000 -WindowsAuthProvider "NTLM" | Out-Null
         Write-Host -ForegroundColor Green "... Completed"

         Write-Host "Adding Alternative Access Mapping for Central Admin Web App..." -NoNewline
         New-SPAlternateUrl -WebApplication ("http://" + $vmName + ":20000") -Url ("http://" + $serviceName + ".cloudapp.net:20000") -Zone Internet | Out-Null
         New-SPAlternateUrl -WebApplication ("http://" + $vmName + ":20000") -Url ("http://" + $serviceName + ":20000") -Zone Intranet | Out-Null
         Write-Host -ForegroundColor Green "... Completed"
         
         Write-Host "Configuring User Profile service"
         # Start the user profile service before creating the service application
         $service = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Service"}
         if ($service.Status -ne "Online") {
             Write-Host "   Starting User Profile Service instance" -NoNewline
             $service | Start-SPServiceInstance | Out-Null
             while ($true) {
                 Write-Host "." -NoNewline ; sleep 10
                 $svc = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Service"}
                 if ($svc.Status -eq "Online") { break }
             }
             Write-Host -ForegroundColor Green "... Started"
         }
            
       	$saAppPool = Get-SPServiceApplicationPool "SharePoint Web Services System" 
        	New-SPProfileServiceApplication -Name "User Profile Service Application" -ApplicationPool $saAppPool -ProfileDBName "UPA1_Profile" -SocialDBName "UPA1_Social" -ProfileSyncDBName "UPA1_Sync" | Out-Null

         $svc = Get-SPServiceInstance | where {$_.TypeName -eq "User Profile Synchronization Service"}
         $app = Get-SPServiceApplication -Name "User Profile Service Application"

         if ($svc.Status -ne "Online") {
            Write-Host "   Starting the User Profile Service Synchronization instance..." -NoNewline
            $svc.Status = "Provisioning"
            $svc.IsProvisioned = $false
            $svc.UserProfileApplicationGuid = $app.Id
            $svc.Update()
            Write-Host -ForegroundColor Green "... Started"
            
            Write-Host "   Setting Synchronization Server to <$($vmName)>" -NoNewline
            $app.SetSynchronizationMachine($vmName, $svc.Id, $spFarmUsername, $spFarmPassword)
       
            $svc | Start-SPServiceInstance | Out-Null
            Write-Host -ForegroundColor Green "... Completed"
         }
         Write-Host "User Profile configuration complete"
         
         $accountName = $spFarmUsername

         $claimType = "http://schemas.microsoft.com/sharepoint/2009/08/claims/userlogonname"
         $claimValue = $accountName
         $claim = New-Object Microsoft.SharePoint.Administration.Claims.SPClaim($claimType, $claimValue, "http://www.w3.org/2001/XMLSchema#string", [Microsoft.SharePoint.Administration.Claims.SPOriginalIssuers]::Format("Windows"))
         write-host "Claims user $($claim.ToEncodedString())"
         Write-Host "Updating user permissions..." -NoNewline 
         $permission = [Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights]"FullControl"

         $SPAclAccessRule = [Type]"Microsoft.SharePoint.Administration.AccessControl.SPAclAccessRule``1"
         $specificSPAclAccessRule = $SPAclAccessRule.MakeGenericType([Type]"Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights")
         $ctor = $SpecificSPAclAccessRule.GetConstructor(@([Type]"Microsoft.SharePoint.Administration.Claims.SPClaim",[Type]"Microsoft.SharePoint.Administration.AccessControl.SPIisWebServiceApplicationRights"))
         $accessRule = $ctor.Invoke(@([Microsoft.SharePoint.Administration.Claims.SPClaim]$claim, $permission))

         $ups = Get-SPServiceApplication | ? { $_.TypeName -eq 'User Profile Service Application' }
         $accessControl = $ups.GetAccessControl()
         $accessControl.AddAccessRule($accessRule)
         $ups.SetAccessControl($accessControl)
         $ups.Update()
         Write-Host -ForegroundColor Green "... Completed"

         Write-Host "Configuring Search Application"
         Write-Host "   Checking if Search Managed Account exists" -NoNewline

         $managedAcct = Get-SPManagedAccount -Identity $appPoolAccount -ErrorAction SilentlyContinue
         if($managedAcct -eq $null)
         {
             Write-Host "... Creating $($appPoolAccount)" -NoNewline
             $appPoolCreds = New-Object System.Management.Automation.PSCredential($appPoolAccount, (ConvertTo-SecureString $appPoolPassword -AsPlainText -Force))
             New-SPManagedAccount -Credential $appPoolCreds | Out-Null
             Write-Host -ForegroundColor Green "... Completed"
         }else {Write-Host "... Skipping"}

         $IndexLocation = "F:\Data\Search15Index” 
         $SearchAppPoolName = "Search App Pool" 
         $SearchAppPoolAccountName = $appPoolAccount
         $SearchServerName = (Get-ChildItem env:computername).value 
         $SearchServiceName = "Search15" 
         $SearchServiceProxyName = "Search15 Proxy" 
         $DatabaseName = "Search15_ADminDB" 
            
         Write-Host "   Checking if Search Application Pool exists" -NoNewline
         $SPAppPool = Get-SPServiceApplicationPool -Identity $SearchAppPoolName -ErrorAction SilentlyContinue
         if (!$SPAppPool) 
         { 
             Write-Host "... Creating" -NoNewline
             $spAppPool = New-SPServiceApplicationPool -Name $SearchAppPoolName -Account $SearchAppPoolAccountName 
             Write-Host -ForegroundColor Green "... Completed"
         }else {Write-Host "... Skipping"}

         # Start Services search service instance 
         Write-host "   Start Search Service instances...." -NoNewline
         Start-SPEnterpriseSearchServiceInstance $SearchServerName -ErrorAction SilentlyContinue | Out-Null
         Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $SearchServerName -ErrorAction SilentlyContinue | Out-Null
         Write-Host -ForegroundColor Green "... Started"

         Write-Host "   Checking if Search Service Application exists" -NoNewline
         $ServiceApplication = Get-SPEnterpriseSearchServiceApplication -Identity $SearchServiceName -ErrorAction SilentlyContinue

         if (!$ServiceApplication) 
         { 
             Write-Host "... Creating" -NoNewline
             $ServiceApplication = New-SPEnterpriseSearchServiceApplication -Partitioned -Name $SearchServiceName -ApplicationPool $spAppPool.Name -DatabaseName $DatabaseName 
             Write-Host -ForegroundColor Green "... Completed"
         }else {Write-Host "... Skipping"}
         
         Write-Host "   Checking if Search Service Application Proxy exists"  -NoNewline
         $Proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $SearchServiceProxyName -ErrorAction SilentlyContinue 
         if (!$Proxy) 
         { 
             Write-Host "... Creating" -NoNewline
             New-SPEnterpriseSearchServiceApplicationProxy -Partitioned -Name $SearchServiceProxyName -SearchApplication $ServiceApplication | Out-Null
             Write-Host -ForegroundColor Green "... Completed"
         }else {Write-Host "... Skipping"}


         Write-host "Search configuration completed" 

         # Clone the default Topology (which is empty) and create a new one and then activate it 
         Write-Host "Configuring Search Component Topology" -NoNewline
         $clone = $ServiceApplication.ActiveTopology.Clone() 
         $SSI = Get-SPEnterpriseSearchServiceInstance -local 
         New-SPEnterpriseSearchAdminComponent –SearchTopology $clone -SearchServiceInstance $SSI  | Out-Null
         New-SPEnterpriseSearchContentProcessingComponent –SearchTopology $clone -SearchServiceInstance $SSI  | Out-Null
         New-SPEnterpriseSearchAnalyticsProcessingComponent –SearchTopology $clone -SearchServiceInstance $SSI  | Out-Null
         New-SPEnterpriseSearchCrawlComponent –SearchTopology $clone -SearchServiceInstance $SSI  | Out-Null

         Remove-Item -Recurse -Force -LiteralPath $IndexLocation -ErrorAction SilentlyContinue | Out-Null
         mkdir -Path $IndexLocation -Force | Out-Null

         New-SPEnterpriseSearchIndexComponent –SearchTopology $clone -SearchServiceInstance $SSI -RootDirectory $IndexLocation  | Out-Null
         New-SPEnterpriseSearchQueryProcessingComponent –SearchTopology $clone -SearchServiceInstance $SSI  | Out-Null
         $clone.Activate()

         Write-host -ForegroundColor Green "... Completed" 
   	}
   	else
   	{

   		Write-Host "Joining farm..." -NoNewline 
   		Connect-SPConfigurationDatabase -DatabaseName $configDbName -DatabaseServer $sqlServer -DatabaseCredential $databaseCredential -Passphrase (ConvertTo-SecureString $spFarmParaphrase -AsPlainText -Force) 
   		Write-Host -ForegroundColor Green "... Joined farm."

         # ensure SharePoint Timer Service is started
         RestartSP4Timer

         ##Execute common install
         CommonInstall
  	
   	}
   }
   else
   {
   	Write-Host "This server is already in a SharePoint farm." 
   }

   Write-Host "Starting Service Application(s)"
   Get-SPServiceInstance | 
   Where-Object {
       $_.Server.Address -eq $env:COMPUTERNAME -and
       $_.Status -ne 'Online' -and $_.TypeName -in $spServicesToStart} |
       ForEach-Object {
           Write-Host -NoNewline ("   Service Application {0}..." -f $_.TypeName) 
           Start-SPServiceInstance $_.Id | Out-Null
           Write-Host -ForegroundColor Green "... Started" 
       }
   Write-Host "Service Application(s) startup completed"
   Write-Host -ForegroundColor Yellow "`nProvisioning SharePoint on server <$($using:vmName)>" -NoNewline;Write-Host -ForegroundColor Green "... Complete`n`n"
 
 } 
    
## End Script