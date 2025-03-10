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
[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)][string]$choice,
    [parameter(Mandatory=$true)][string]$Location,
    [parameter(Mandatory=$true)][string]$ScriptFolder,
    [parameter(Mandatory=$false)][string]$subscriptionName="",
    [parameter(Mandatory=$false)][string]$serviceName="",
    [parameter(Mandatory=$false)][string]$storageAccountName="",
    [parameter(Mandatory=$false)][string]$adminAccount="spadmin",
    [parameter(Mandatory=$false)][string]$adminPassword="",
    [parameter(Mandatory=$false)][string]$appPoolAccount="spfarm",
    [parameter(Mandatory=$false)][string]$appPoolPassword="",
    [parameter(Mandatory=$false)][string]$Domain="corp",
    [parameter(Mandatory=$false)][string]$DnsDomain="corp.contoso.com",
    [parameter(Mandatory=$false)][bool]$configOnly=$false,
    [parameter(Mandatory=$false)][bool]$doNotShowCreds=$false,
    [parameter(Mandatory=$false)][bool]$UsePrevDeployment=$false
)

#Region Functions
function SetADConfiguration
{
    param($configPath,$serviceName,$storageAccount,$subscription, $adminAccount, $password, $domain, $dnsDomain)

    $w2k12img = (GetLatestImage "Windows Server 2012 R2 Datacenter")
    $configPathAutoGen = $configPath.Replace(".xml", "-AutoGen.xml")

    [xml] $config = gc $configPath
    $config.Azure.SubscriptionName = $subscription
    $config.Azure.ServiceName = $serviceName
    $config.Azure.StorageAccount = $storageAccount
    $config.Azure.Location = $location
    $config.Azure.AzureVMGroups.VMRole.StartingImageName = $w2k12img
    $config.Azure.AzureVMGroups.VMRole.ServiceAccountName = $adminAccount
    $config.Azure.ActiveDirectory.Domain = $domain
    $config.Azure.ActiveDirectory.DnsDomain = $dnsDomain

    ## Get User Defined server name
    SetMultipleNames -ConfigPath $ConfigPath -VMInstance $config.Azure.AzureVMGroups.VMRole 

    foreach($serviceAccount in $config.Azure.ServiceAccounts.ServiceAccount)
    {
        $serviceAccount.UserName = $adminAccount
        $serviceAccount.Password = $password
    }
    $config.Save($configPathAutoGen)
    return $configPathAutoGen
}

function SetVSConfiguration
{
    param($configPath,$serviceName,$storageAccount,$subscription, $adminAccount, $password, $domain, $dnsDomain)

    $w81img = (GetLatestImage "Visual Studio Ultimate 2013 on Windows 8.1 Enterprise (x64)")
    $configPathAutoGen = $configPath.Replace(".xml", "-AutoGen.xml")

    [xml] $config = gc $configPath
    $config.Azure.SubscriptionName = $subscription
    $config.Azure.ServiceName = $serviceName
    $config.Azure.StorageAccount = $storageAccount
    $config.Azure.Location = $location
    $config.Azure.Connections.ActiveDirectory.ServiceName = $serviceName
    $config.Azure.Connections.ActiveDirectory.Domain = $domain
    $config.Azure.Connections.ActiveDirectory.DnsDomain = $dnsDomain
    $config.Azure.Connections.ActiveDirectory.ServiceAccountName = "$domain\$adminAccount"
    $config.Azure.AzureVMGroups.VMRole.StartingImageName = $w81img
    $config.Azure.AzureVMGroups.VMRole.AdminUsername = $adminAccount

    foreach($serviceAccount in $config.Azure.ServiceAccounts.ServiceAccount)
    {
        if(($serviceAccount.Type -eq "WindowsLocal") -or ($serviceAccount.Type -eq "SQL"))
        {
           $serviceAccount.UserName = $adminAccount
        }
        else #domain account
        {
          $serviceAccount.UserName = "$domain\$adminAccount"
        }
        $serviceAccount.Password = $password
    }
    $config.Save($configPathAutoGen)
    return $configPathAutoGen
}

function SetIISConfiguration
{
    param($configPath,$serviceName,$storageAccount,$subscription, $adminAccount, $password, $domain, $dnsDomain)

    $w2k12img = (GetLatestImage "Windows Server 2012 R2 Datacenter")
    $configPathAutoGen = $configPath.Replace(".xml", "-AutoGen.xml")

    [xml] $config = gc $configPath
    $config.Azure.SubscriptionName = $subscription
    $config.Azure.ServiceName = $serviceName
    $config.Azure.StorageAccount = $storageAccount
    $config.Azure.Location = $location
    $config.Azure.Connections.ActiveDirectory.ServiceName = $serviceName
    $config.Azure.Connections.ActiveDirectory.Domain = $domain
    $config.Azure.Connections.ActiveDirectory.DnsDomain = $dnsDomain
    $config.Azure.Connections.ActiveDirectory.ServiceAccountName = "$domain\$adminAccount"
    $config.Azure.AzureVMGroups.VMRole.StartingImageName = $w2k12img
    $config.Azure.AzureVMGroups.VMRole.AdminUsername = $adminAccount

    ## Get User Defined server name
    SetMultipleNames -ConfigPath $ConfigPath -VMInstance $config.Azure.AzureVMGroups.VMRole

    foreach($serviceAccount in $config.Azure.ServiceAccounts.ServiceAccount)
    {
        if(($serviceAccount.Type -eq "WindowsLocal") -or ($serviceAccount.Type -eq "SQL"))
        {
           $serviceAccount.UserName = $adminAccount
        }
        else #domain account
        {
          $serviceAccount.UserName = "$domain\$adminAccount"
        }
        $serviceAccount.Password = $password
    }
    $config.Save($configPathAutoGen)
    return $configPathAutoGen
}

function SetSQLConfiguration
{
    param($configPath,$serviceName,$storageAccount,$subscription, $adminAccount, $password, $domain, $dnsDomain)
    $sql2k12img = (GetLatestImage "SQL Server 2012 SP2 Enterprise on Windows Server 2012")
    $configPathAutoGen = $configPath.Replace(".xml", "-AutoGen.xml")
    [xml] $config = gc $configPath
    $config.Azure.SubscriptionName = $subscription
    $config.Azure.ServiceName = $serviceName
    $config.Azure.StorageAccount = $storageAccount
    $config.Azure.Location = $location
    $config.Azure.Connections.ActiveDirectory.ServiceName = $serviceName
    $config.Azure.Connections.ActiveDirectory.Domain = $domain
    $config.Azure.Connections.ActiveDirectory.DnsDomain = $dnsDomain
    $config.Azure.Connections.ActiveDirectory.ServiceAccountName = "$domain\$adminAccount"
    $config.Azure.AzureVMGroups.VMRole.ServiceAccountName = "$adminAccount"
    $config.Azure.AzureVMGroups.VMRole.StartingImageName = $sql2k12img

    ## Get User Defined server name
    SetMultipleNames -ConfigPath $ConfigPath -VMInstance $config.Azure.AzureVMGroups.VMRole 
    ## SQL Server specfic value settings
    SetSingleName -ConfigPath $ConfigPath -VMInstance $config.Azure.SQLCluster -RefNode "SQLAvailabilityGroup" -VMRefValue "SQLAvailabilityGroup"
    
    SetSingleNamebyNodeValue -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.ActiveDirectory -RefNode "DomainControllerVM" -LookupNode "DomainControllers" -LookupValue "DC"

    if($config.Azure.AzureVMGroups.VMRole.QuorumStartingImageName -ne $null)
    {
        $config.Azure.AzureVMGroups.VMRole.QuorumStartingImageName = (GetLatestImage "Windows Server 2012 R2 Datacenter")
    }
    foreach($serviceAccount in $config.Azure.ServiceAccounts.ServiceAccount)
    {
        if(($serviceAccount.Type -eq "WindowsLocal") -or ($serviceAccount.Type -eq "SQL"))
        {
           $serviceAccount.UserName = $adminAccount
        }
        else #domain account
        {
           $serviceAccount.UserName = "$domain\$adminAccount"
        }
        $serviceAccount.Password = $password
    }

    $config.Azure.SQLCluster.InstallerDomainUsername = "$domain\$adminAccount"
    $config.Azure.SQLCluster.InstallerDatabaseUserName = $adminAccount

    if($config.Azure.AzureVMGroups.VMRole.HighAvailabilityType -ne $null)
    {
        $config.Azure.SQLCluster.PrimaryServiceAccountName = "$domain\$adminAccount"
        $config.Azure.SQLCluster.SecondaryServiceAccountName = "$domain\$adminAccount"
    }
    $config.Save($configPathAutoGen)
    return $configPathAutoGen
}

function SetSharePointConfiguration
{
    param($configPath,$serviceName,$storageAccount,$subscription, $adminAccount, $password, $domain, $dnsDomain, $appPoolAccount, $appPoolPassword)
    $sp2013img = (GetLatestImage "SharePoint Server 2013 Trial")
    $configPathAutoGen = $configPath.Replace(".xml", "-AutoGen.xml")
    [xml] $config = gc $configPath
    $config.Azure.SubscriptionName = $subscription
    $config.Azure.ServiceName = $serviceName
    $config.Azure.StorageAccount = $storageAccount
    $config.Azure.Connections.ActiveDirectory.ServiceName = $serviceName
    $config.Azure.Connections.ActiveDirectory.Domain = $domain
    $config.Azure.Connections.ActiveDirectory.DnsDomain = $dnsdomain
    $config.Azure.Connections.ActiveDirectory.ServiceAccountName = "$domain\$adminAccount"
    $config.Azure.Connections.SQLServer.ServiceName = $serviceName
    $config.Azure.Connections.SQLServer.UserName = $adminAccount
    $config.Azure.SharePointFarm.FarmAdminUsername = "$domain\$adminAccount"
    $config.Azure.SharePointFarm.InstallerDomainUsername = "$domain\$adminAccount"
    $config.Azure.SharePointFarm.InstallerDatabaseUsername = $adminAccount
    $config.Azure.SharePointFarm.ApplicationPoolAccount = "$domain\$appPoolAccount"

    ## Get User Defined server name
    SetMultipleNames -ConfigPath $ConfigPath -VMInstance $config.Azure.AzureVMGroups.VMRole 
    ### SharePoint Specifc value setting
    SetSingleNamebyNodeValue -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.SQLServer -RefNode "Instance" -LookupNode "SQLServers" -LookupValue "SQL"
    #    SetSingleName -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.SqlServer -RefNode "Instance" -VMRefValue "SharePointSQLServerInstance"
    #    SetSingleName -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.SqlServer -RefNode "FailOverInstance" -VMRefValue "SharePointSQLServerFailOver"
    #    SetSingleName -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.SqlServer -RefNode "AvailabilityGroup" -VMRefValue "SQLAvailabilityGroup"
    SetSingleName -ConfigPath $ConfigPath -VMInstance $config.Azure.SharePointFarm -RefNode "Name" -VMRefValue "SPFarmName"
    SetSingleNamebyNodeValue -ConfigPath $ConfigPath -VMInstance $config.Azure.Connections.ActiveDirectory -RefNode "DomainControllerVM" -LookupNode "DomainControllers" -LookupValue "DC"


    foreach($vmRole in $config.Azure.AzureVMGroups.VMRole)
    {
        $vmRole.StartingImageName = $sp2013Img
        $vmRole.AdminUserName = $adminAccount
    }
    foreach($serviceAccount in $config.Azure.ServiceAccounts.ServiceAccount)
    {
        if(($serviceAccount.Type -eq "WindowsLocal") -or ($serviceAccount.Type -eq "SQL"))
        {
           $serviceAccount.UserName = $adminAccount
           $serviceAccount.Password = $password
        }
        else #domain account
        {
           if($serviceAccount.Usage -ne $null -and $serviceAccount.Usage -eq "SPAppPool")
           {
              $serviceAccount.UserName = "$domain\$appPoolAccount"
              $serviceAccount.Password = $appPoolPassword
           }
           else
           {
              $serviceAccount.UserName = "$domain\$adminAccount"
              $serviceAccount.Password = $password
           }
        }
    }
    foreach($webApp in $config.Azure.SharePointFarm.WebApplications.WebApplication)
    {
        $webApp.Url = "http://$serviceName.cloudapp.net"
        $webApp.TopLevelSiteOwner = "$domain\$adminAccount"
    }
    $config.Save($configPathAutoGen)
    return $configPathAutoGen
}

#endregion

    if($subscriptionName -ne "")
    {
        $subscription = Get-AzureSubscription -SubscriptionName $subscriptionName
    }
    else
    {
        $subscription = Get-AzureSubscription -Current
    }

    if($subscription -eq $null)
    {
        Write-Host "Windows Azure Subscription is not configured or the specified subscription name is invalid."
        Write-Host "Use Get-AzurePublishSettingsFile and Import-AzurePublishSettingsFile first"
        return
    }
    
##Start overall stop watch
$oa_stopWatch = New-Object System.Diagnostics.Stopwatch;$oa_stopWatch.Start()
    
##Load the functions
Import-Module $scriptFolder\SharedComponents\SharedFunctions.psm1 -AsCustomObject -Force -DisableNameChecking -Verbose:$false

Select-AzureSubscription $subscription.SubscriptionName

$ad = "$scriptFolder\AD\ProvisionAD.ps1"
$sql = "$scriptFolder\SQL\ProvisionSQL.ps1"
$sp = "$scriptFolder\SharePoint\ProvisionSharePoint.ps1"
$vs = "$scriptFolder\VS\ProvisionVisualStudio.ps1"
$iis = "$scriptFolder\IIS\ProvisionIIS.ps1"

$adConfig = "$scriptFolder\Config\AD-Sample.xml"
$sqlConfig = "$scriptFolder\Config\SQL-Sample.xml"
$spConfig = "$scriptFolder\Config\SharePoint-Sample.xml"
$vsConfig = "$scriptFolder\Config\VS-Sample.xml"
$iisConfig = "$scriptFolder\Config\IIS-Sample.xml"

$autoSqlConfig = "$scriptFolder\Config\SQL-Sample-AutoGen.xml"
$autoSPConfig = "$scriptFolder\Config\SharePoint-Sample-AutoGen.xml"
$autoVSConfig = "$scriptFolder\Config\VS-Sample-AutoGen.xml"
$autoIISConfig = "$scriptFolder\Config\IIS-Sample-AutoGen.xml"

## Set Global Constents
set-variable -name deployStandaloneSQLIIS -value 1 -option constant -Visibility Public
set-variable -name deployDomainSQLIIS -value 2 -option constant -Visibility Public
set-variable -name deploySharePoint -value 3 -option constant -Visibility Public

if ($UsePrevDeployment){
   ##Force some seetings from the AD-AutoGen XML File
   $configPathAutoGen = $adConfig.Replace(".xml", "-AutoGen.xml")
   if (!(Test-Path $configPathAutoGen))
   {
      $UsePrevDeployment = $false
      Write-Host "Expected AD configuration file not found.  Resetting to full Install`n`n"
      Write-Host "Generating information"
   }
   else {
      Write-Host "Reading configuration"
      [xml] $config = gc $configPathAutoGen
      $serviceName = $config.Azure.ServiceName
      $storageAccountName = $config.Azure.StorageAccount
      $adminPassword = $config.Azure.ServiceAccounts.ServiceAccount.Password
      $appPoolPassword = $adminPassword
   }
}
else
{
   Write-Host "Generating information"
}

 ##Set Required Values
if($adminPassword -eq "")
{
  $adminPassword = (randomString -length 10) + "0!"
}
Write-Host "   Admin password $($adminPassword)"
 
if($appPoolPassword -eq "")
{
   # if not specified use the same as the admin password
   $appPoolPassword = $adminPassword
}
Write-Host "   App Pool password $($appPoolPassword)"

if($serviceName -eq "")
{
  while($true)
  {
      $serviceName = "sp-" + (randomString)
      if((Test-AzureName -Service $serviceName) -eq $true)
      {
#             Write-Host "Dynamically generated $serviceName already exists. Looking for another."
      }
      else
      { break }
  }
}
Write-Host "   Cloud Service Name $serviceName"

if($storageAccountName -eq "")
{
  while($true)
  {
      $storageAccountName = "spstorage" + (randomString)
      if((Test-AzureName -Storage $storageAccountName) -eq $true)
      {
             Write-Host "Dynamically generated $storageAccountName is in use. Looking for another."
      }
      else
      {
         if($configOnly) {
            Write-Host "   Using Storage Account $($storageAccountName)"
            break
         }
         else{
            Write-Host "   Creating new storage account $storageAccountName in $location" -NoNewline
            try
            {
               New-AzureStorageAccount -StorageAccountName $storageAccountName -Location $location -OutVariable $Result | Out-Null
               Write-host -ForegroundColor Green "... Completed"
            }
            catch
            {
               return
            }
            break
         }
      }
  }
}

Write-Host "Complete`n"

Write-Host "Setting configuration(s)"
if (($choice -eq $deployDomainSQLIIS) -or ($choice -eq $deploySharePoint))
{
  Write-Host "   AD Configuration File"
  $autoAdConfig = SetADConfiguration -configPath $adConfig -serviceName $serviceName -storageAccount $storageAccountName -subscription $subscription.SubscriptionName -adminAccount $adminAccount -password $adminPassword -domain $domain -dnsDomain $dnsDomain
}

Write-Host "   SQL Configuration File"
$autoSqlConfig = SetSqlConfiguration -configPath $sqlConfig -serviceName $serviceName -storageAccount $storageAccountName -subscription $subscription.SubscriptionName -adminAccount $adminAccount -password $adminPassword -domain $domain -dnsDomain $dnsDomain

if (($choice -eq $deployStandaloneSQLIIS) -or ($choice -eq $deployDomainSQLIIS))
{
  Write-Host "   IIS Configuration File"
  $autoIISconfig = SetIISConfiguration -configPath $iisConfig -serviceName $serviceName -storageAccount $storageAccountName -subscription $subscription.SubscriptionName -adminAccount $adminAccount -password $adminPassword -domain $domain -dnsDomain $dnsDomain
}

if ($choice -eq $deploySharePoint)
{
  Write-Host "   SharePoint Configuration File"
  $autoSPConfig = SetSharePointConfiguration -configPath $spConfig -serviceName $serviceName -storageAccount $storageAccountName -subscription $subscription.SubscriptionName -adminAccount $adminAccount -password $adminPassword -domain $domain -dnsDomain $dnsDomain -appPoolAccount $appPoolAccount -appPoolPassword $appPoolPassword 
}

    #Write-Host "Setting Visual Studio Configuration File"
    #$autoVSconfig = SetVSConfiguration -configPath $vsConfig -serviceName $serviceName -storageAccount $storageAccountName -subscription $subscription.SubscriptionName -adminAccount $adminAccount -password $adminPassword -domain $domain -dnsDomain $dnsDomain

Write-Host "Complete";Write-Host

if(-not $configOnly)
{

   if (($choice -eq $deployDomainSQLIIS) -or ($choice -eq $deploySharePoint))
   {
      Write-Host -ForegroundColor Yellow "`nDeploying Server 2012 R2 Domain Controller using Configuration Template:`n   $autoAdConfig`n"
      if (!$UsePrevDeployment){ 
      $stopWatch = New-Object System.Diagnostics.Stopwatch;$stopWatch.Start()            
      & $ad -configFilePath $autoAdConfig -scriptFolder $scriptFolder
      $stopWatch.Stop();$ts = $stopWatch.Elapsed
      Write-Host -ForegroundColor Yellow "Active Directory Deployment completed"
      write-host ("   in {0} hours {1} minutes, {2} seconds`n" -f $ts.Hours, $ts.Minutes, $ts.Seconds)
      }
      else {Write-Host -ForegroundColor Green "Skipping";Write-Host
      }
   }

   Write-Host -ForegroundColor Yellow "`nDeploying SQL Server 2012 using Configuration Template:`n  $autoSqlConfig`n"
   [xml]$SQLConFig = gc $autoSqlConfig
   $SQLVM = $SQLConFig.Azure.AzureVMGroups.VMRole.AzureVM.Name
   if ($SQLVM -eq $null){Write-Host -ForegroundColor Red "Something went wrong.. exiting";return}
   if ( (Get-AzureVM -Name $SQLVM -ServiceName $serviceName).name -eq $null){
      $stopWatch = New-Object System.Diagnostics.Stopwatch;$stopWatch.Start()            
      & $sql -configFilePath $autoSqlConfig -Choice $choice -scriptFolder $scriptFolder
      $stopWatch.Stop();$ts = $stopWatch.Elapsed
      Write-Host -ForegroundColor Yellow "SQL Server 2012 Deployment completed"
      write-host ("   in {0} hours {1} minutes, {2} seconds`n" -f $ts.Hours, $ts.Minutes, $ts.Seconds)
   }
   else {Write-Host -ForegroundColor Yellow "Skipping Deployment... Already exists";Write-Host}
  
   if ($choice -eq $deploySharePoint)
   {
      Write-Host -ForegroundColor Yellow "`nDeploying SharePoint Server 2013 using Configuration Template:`n   $autoSPconfig`n"

      $stopWatch = New-Object System.Diagnostics.Stopwatch;$stopWatch.Start()            
      & $sp -configFilePath $autoSPconfig -scriptFolder $scriptFolder
      $stopWatch.Stop();$ts = $stopWatch.Elapsed
      Write-Host -ForegroundColor Yellow "SharePoint Deployment completed"
      write-host ("   in {0} hours {1} minutes, {2} seconds`n" -f $ts.Hours, $ts.Minutes, $ts.Seconds)
   }

   if (($choice -eq $deployStandaloneSQLIIS) -or ($choice -eq $deployDomainSQLIIS))
   {
      Write-Host -ForegroundColor Yellow "`nDeploying Windows 2012 R2 with IIS using Configuration Template:`n   $autoIISconfig`n"
      $stopWatch = New-Object System.Diagnostics.Stopwatch;$stopWatch.Start()            
      & $iis -configFilePath $autoIISconfig -Choice $choice -scriptFolder $scriptFolder
      $stopWatch.Stop();$ts = $stopWatch.Elapsed
      Write-Host -ForegroundColor Yellow "IIS Deployment completed"
      write-host ("   in {0} hours {1} minutes, {2} seconds`n" -f $ts.Hours, $ts.Minutes, $ts.Seconds)
   }

  #Write-Host "Installing Visual Studio 2013"
  #& $vs -configFilePath $autoVSconfig

   Write-host;Write-Host -ForegroundColor Yellow "Script Execution Complete. Verify no errors during execution."; Write-Host

   #Call function to display final admin settings
   ShowFinalCreds -Choice $choice -Domain $domain -AdminAccount $adminAccount -AdminPassword $adminPassword -ServiceName $serviceName
}
else
{
  Write-Host "Generated Configuration files in $scriptFolder\Config"
}

$oa_stopWatch.Stop();$ts = $oa_stopWatch.Elapsed
write-host ("`nTotal deployment completed in {0} hours {1} minutes, {2} seconds`n" -f $ts.Hours, $ts.Minutes, $ts.Seconds)
 
## End script

