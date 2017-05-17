param(
  [string]
  [ValidatePattern("^[a-z0-9]*$")]
  $environment = "DEV",

  [string]
  $subscriptionName = "<put your subscription name here>",

  [string]
  [ValidateSet("West Europe")]
  $location = "West Europe"
)

### script setup
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2
try { Set-Location (Split-Path -parent $PSCommandPath) } catch {}

### import common module with usefull functions
Remove-Module Common -ErrorAction SilentlyContinue
Import-Module .\common.psm1

### variables and config
$environment = $environment.ToUpper()
$templateContainer = "arm-templates"
$resourceGroupName = "ArmWebExample-" + $environment
$keyVaultName = "ArmWebExample" + $environment
$resourceGroupNameKeyVault = ($resourceGroupName + "-keyvault")

### login
try
{
    Get-AzureRmContext | Out-Null
}
catch
{
    Login-AzureRmAccount | Out-Null
}

$subscription = Select-AzureRmSubscription -SubscriptionName $subscriptionName
Write-Host ("Using subscription '{0}'" -f $subscription.Subscription.SubscriptionName)

### create resourcegroups
$resourceGroup = New-AzureRmResourceGroup `
                    -Name $resourceGroupName `
                    -Location $location `
                    -Force

Write-Host ("Created resourcegroup '{0}'" -f $resourceGroup.ResourceGroupName)

$resourceGroupKeyVault = New-AzureRmResourceGroup `
                            -Name $resourceGroupNameKeyVault `
                            -Location $location `
                            -Force

Write-Host ("Created resourcegroup '{0}'" -f $resourceGroupKeyVault.ResourceGroupName)

## setting up password in vault to avoid to have the password of the vmAdmin in clear text comitted to git
if ((Get-AzureRmKeyVault -ResourceGroupName $resourceGroupNameKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue) -eq $null)
{
    New-AzureRmKeyVault `
        -VaultName $keyVaultName `
        -ResourceGroupName $resourceGroupNameKeyVault `
        -Location $location `
        -EnabledForTemplateDeployment
}

# Due to a delay on azure we must wait until keyvault has been actually created
for($i=1; $i -le 100; $i++)
{
    try
    {
        $testSecret = "TestSecret"

        Set-AzureKeyVaultSecret `
            -VaultName $keyVaultName `
            -Name $testSecret `
            -SecretValue ("SecretValue" | ConvertTo-SecureString -AsPlainText -Force) | Out-Null
        
        Remove-AzureKeyVaultSecret `
            -VaultName $keyVaultName `
            -Name $testSecret -Force -Confirm:$false | Out-Null
            
        break
    }
    catch
    {
        Write-Host "#$i Waiting vault '$keyVaultName' to be ready"
        Start-Sleep -Seconds 10
    }
}

### create the vm admin secret in the azure vault
New-Secret -secretName "vmAdminPassword" -vaultName $keyVaultName

### put the arm templates in a storage account in order to invoke the arm template. It is secured with sas token to project the sources
$automationStorageAccountName =  ($resourceGroupName + "auto").replace("-", "").ToLower()

New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $automationStorageAccountName `
    -SkuName Standard_LRS `
    -Kind BlobStorage `
    -AccessTier Hot `
    -Location $location `
    -ErrorAction SilentlyContinue

#get the sas token
$key = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $automationStorageAccountName
$context = New-AzureStorageContext -StorageAccountName $automationStorageAccountName -StorageAccountKey $key[0].Value
$token = New-AzureStorageContainerSASToken -Name $templateContainer -Permission r -ExpiryTime (Get-Date).AddMinutes(90.0) -Context $context
$securedSasToken = ConvertTo-SecureString -String $token -AsPlainText -Force

#put the token in the vault for future reference
$secret = Set-AzureKeyVaultSecret `
                -VaultName $keyVaultName `
                -Name 'sasToken' `
                -SecretValue $securedSasToken

Write-Host ("Created secret '{0}'" -f $secret.Name)

#create a container to hold all the scripts
New-AzureStorageContainer -Name $templateContainer -Permission Off -Context $context -ErrorAction SilentlyContinue | Out-Null

#delete all the old scripts
$oldScripts = Get-AzureStorageBlob -Container $templateContainer -Context $context
$oldScripts | Remove-AzureStorageBlob -Force

#upload all the arm templates
foreach ($file in (Get-ChildItem -Path . -Filter "*.json"))
{  
    $blob = Set-AzureStorageBlobContent -Container $templateContainer -File $file -Context $context -Force
    Write-Host ("Uploaded '{0}'" -f $blob.Name)
}

#upload the dsc package to the blob storage as well
$configurationName = "vmBootstrap"
$dscArchivePath = ".\$configurationName.zip"
Compress-Archive -Path ".\$configurationName\*" -DestinationPath $dscArchivePath -Force
$blob = Set-AzureStorageBlobContent -Container $templateContainer -File $dscArchivePath -Context $context -Force
Write-Host ("Uploaded '{0}'" -f $blob.Name)
Remove-Item -Path $dscArchivePath -Force -ErrorAction SilentlyContinue

### deployment of arm resources
$templateParameterObject = @{ 
    vmAdminPassword = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'vmAdminPassword').SecretValueText 
    sasToken = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'sasToken').SecretValueText
    templateLinkBaseurl = ("https://{0}.blob.core.windows.net/{1}/" -f $automationStorageAccountName, $templateContainer)
    environment = $environment.ToLower()
    networkPrefix = "10.0.0.0/22"
    appsNetworkSubnetPrefix = "10.0.0.0/24"
}

$result = New-AzureRmResourceGroupDeployment `
            -Name "master" `
            -ResourceGroupName $resourceGroupName `
            -TemplateUri ($templateParameterObject.templateLinkBaseurl + "deploy.json" + $token) `
            -TemplateParameterObject $templateParameterObject `
            -Verbose -Force

Write-Host ("Deployment has finished with status '{0}'" -f $result.ProvisioningState)

if ($result.ProvisioningState -eq "Failed")
{
    $result
    throw "Deployment has failed"
}