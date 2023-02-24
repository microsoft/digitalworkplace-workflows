function Get-Secret {
    param (
        [Parameter(Mandatory=$true)] [string]$secretName,
        [Parameter(Mandatory=$true)] [string]$outputName
    )
    $secret = az keyvault secret show `
                --subscription $env:AZURE_SUBSCRIPTION_ID `
                --vault-name $env:KEY_VAULT_NAME `
                --name $secretName `
                | ConvertFrom-Json

    # Mask the secret in logs
    Write-Output "::add-mask::$($secret.value)"

    # Output the secret for use in later steps
    Write-Output "$outputName=$($secret.value)" >> $env:GITHUB_OUTPUT
}
