function ExecWithCode
{
	[CmdletBinding(
	SupportsShouldProcess=$False,
	SupportsTransactions=$False,
	ConfirmImpact="None",
	DefaultParameterSetName="")]

  param(
	[Parameter(Mandatory = $true)][scriptblock]$cmd,
	[Parameter(Mandatory = $false)][string]$errorMessage = "Error executing command: " + $cmd,
	[Parameter(Mandatory = $false)][string]$maxExitCode = 0
  )
	& $cmd
	
	if ($lastexitcode -lt 0)
	{
		throw $errorMessage
	}
	
	if($lastexitcode -gt $maxExitCode)
	{
		throw $errorMessage
	}
}

function New-Secret
{
    param(
    [Parameter(Mandatory = $true)][string]$secretName,
    [Parameter(Mandatory = $true)][string]$vaultName,
    [bool]$environmentVariable = $false
    )

    if ((Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName -ErrorAction SilentlyContinue) -ne $null)
    {
        return
    }

    if ($environmentVariable)
    {
        $envVariable = [Environment]::GetEnvironmentVariable($secretName, [EnvironmentVariableTarget]::Process)
        if ([string]::IsNullOrWhiteSpace($envVariable)) 
        { 
            throw "Cannot set environment variable '$secretName' because no environment variable provides a value" 
        }
        $secretValue = ($envVariable | ConvertTo-SecureString -AsPlainText -Force)
    }
    else
    {
        $secretValue = (Read-Host -Prompt "Enter a value for '$secretName'" -AsSecureString)
    }

    Set-AzureKeyVaultSecret `
        -VaultName $vaultName `
        -Name $secretName `
        -SecretValue $secretValue
}