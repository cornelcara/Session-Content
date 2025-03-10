#Requires -Version 2.0

# Copyright (C) Microsoft Corporation. All rights reserved.
#
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
# KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE.

function Get-MSIComponentState
{
# .ExternalHelp Microsoft.Tools.WindowsInstaller.PowerShell.dll-Help.xml

    [CmdletBinding(DefaultParameterSetName = "Product")]
    param
    (
        [Parameter(ParameterSetName = "Product", Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.Deployment.WindowsInstaller.ProductInstallation[]] $Product,

        [Parameter(ParameterSetName = "ProductCode", Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $ProductCode,

        [Parameter(ParameterSetName = "ProductCode", ValueFromPipelineByPropertyName = $true)]
        [Alias("Context", "InstallContext")]
        [Microsoft.Deployment.WindowsInstaller.UserContexts] $UserContext = "All",

        [Parameter(ParameterSetName = "ProductCode", ValueFromPipelineByPropertyName = $true)]
        [Microsoft.Tools.WindowsInstaller.PowerShell.Sid()]
        [string] $UserSid
    )

    process
    {
        if ($PSCmdlet.ParameterSetName -eq "ProductCode")
        {
            $Product = @(,(get-msiproductinfo @PSBoundParameters))
        }

        $Product | foreach-object {

            [string] $productCode = $_.ProductCode

            # Get the state of every authored component in the product and applied patches.
            $_ | get-msitable -table Component | foreach-object {

                # Attach authored information from the product package to the output object.
                $_ | get-msicomponentinfo -productcode $productCode `
                   | foreach-object { $_.PSTypeNames.Insert(0, $_.PSTypeNames[0] + "#State"); $_ } `
                   | add-member -type NoteProperty -name Component -value $_.Component -passthru
            }
        }
    }
}

function Get-MSISharedComponentInfo
{
# .ExternalHelp Microsoft.Tools.WindowsInstaller.PowerShell.dll-Help.xml

    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Tools.WindowsInstaller.PowerShell.ValidateGuid()]
        [string[]] $ComponentCode,
        
        [Parameter(Position = 1)]
        [ValidateRange(2, 2147483647)]
        [int] $Count = 2
    )
    
    end
    {
        $getcomponents = { get-msicomponentinfo }
        if ($ComponentCode)
        {
            $getcomponents = { get-msicomponentinfo -componentcode $ComponentCode }
        }
        & $getcomponents | group-object -property ComponentCode | where-object { $_.Count -ge $Count } `
            | select-object -expand Group
    }
}

# Update the usage information for this module if installed.
[Microsoft.Tools.WindowsInstaller.PowerShell.Module]::Use()
