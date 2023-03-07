param(
    [Parameter(Mandatory=$true)] [string]$esrpSigningAadClientId,
    [Parameter(Mandatory=$true)] [string]$workspace,
    [Parameter(Mandatory=$true)] [string]$subscriptionId,
    [Parameter(Mandatory=$true)] [string]$aadTenantId,
    [Parameter(Mandatory=$true)] [string]$storageAccountName,
    [Parameter(Mandatory=$true)] [string]$containerName,
    [Parameter(Mandatory=$true)] [string]$keyVaultName,
    [Parameter(Mandatory=$true)] [string]$esrpAadAuthCertSecretName,
    [Parameter(Mandatory=$true)] [string]$esrpSigningCertSecretName,
    [Parameter(Mandatory=$true)] [string]$esrpSigningCertFingerprint,
    [Parameter(Mandatory=$true)] [string]$esrpClientBlobName,
    [Parameter(Mandatory=$false)] [switch]$userLogin
)

if ($workspace -notmatch '\\\\')
{
    Write-Host "The 'workspace' parameter is not properly escaped. Don't worry, we'll clean it up."
    $workspace = [regex]::Escape($workspace)
}

$fileName = (Get-ChildItem -Recurse -Path unsigned -Filter *.nupkg | Select-Object -Property Name -First 1).Name
if ($fileName -match ' ') {
    # This accounts for cases where it finds the same package and we end up with $fileName = "proj.1.1.0.nupkg proj.1.1.0.nupkg"
    $fileName = $fileName.split()[0]
}

if ([string]::IsNullOrWhiteSpace($fileName)) {
    throw "Unable to find unsigned nupkg for signing. Ensure the 'dotnet pack' command has been run and that it's output to a directory called 'unsigned'."
}

Write-Host "Found unsigned nupkg: $fileName"
if ($userLogin) {
    Write-Host 'Logging into Azure.'
    az login --output none
    az account set --subscription $subscriptionId
}

if (Test-Path 'signed') {
    Write-Host "'signed' directory already exists."
} else {
    mkdir signed
    Write-Host "'signed' directory created successfully."
}

Write-Host "Generating 'auth.json' and 'input.json' files for ESRP Client."
$authJson = @"
{
    "Version": "1.0.0",
    "AuthenticationType": "AAD_CERT",
    "TenantId": "$aadTenantId",
    "ClientId": "$esrpSigningAadClientId",
    "AuthCert": {
        "SubjectName": "CN=$esrpSigningAadClientId.microsoft.com",
        "StoreLocation": "LocalMachine",
        "StoreName": "My",
        "SendX5c": "true"
    },
    "RequestSigningCert": {
        "SubjectName": "CN=$esrpSigningAadClientId",
        "StoreLocation": "LocalMachine",
        "StoreName": "My"
    }
}
"@
$inputJson = @"
{
    "Version": "1.0.0",
    "SignBatches": [
        {
            "SourceLocationType": "UNC",
            "SourceRootDirectory": "$workspace\\unsigned",
            "DestinationLocationType": "UNC",
            "DestinationRootDirectory": "$workspace\\signed",
            "SignRequestFiles": [
                {
                    "SourceLocation": "$fileName",
                    "DestinationLocation": "$fileName"
                }
            ],
            "SigningInfo": {
                "Operations": [
                    {
                        "KeyCode": "CP-401405",
                        "OperationCode": "NuGetSign",
                        "ToolName": "sign",
                        "ToolVersion": "1.0"
                    },
                    {
                        "KeyCode": "CP-401405",
                        "OperationCode": "NuGetVerify",
                        "ToolName": "sign",
                        "ToolVersion": "1.0"
                    }
                ]
            }
        }
    ]
}
"@
Out-File -FilePath .\auth.json -InputObject $authJson
Out-File -FilePath .\input.json -InputObject $inputJson
Write-Host 'Done.'
try {
    Write-Host 'Downloading ESRP Client.'
    az storage blob download --auth-mode login --subscription  $subscriptionId --account-name $storageAccountName -c $containerName -n $esrpClientBlobName -f esrp.zip
    if (Test-Path 'esrp.zip') {
        Write-Host 'Done.'
    } else {
        throw 'Download did not complete successfully. This is likely due to an access issue.'
    }

    Write-Host 'Unzipping ESRP Client.'
    Expand-Archive -Path 'esrp.zip' -DestinationPath './esrp' -Force
    Write-Host 'Done.'
    Write-Host 'Downloading & Installing Certifictes.'
    Remove-Item cert.pfx -ErrorAction SilentlyContinue
    az keyvault secret download --subscription $subscriptionId --vault-name $keyVaultName --name $esrpAadAuthCertSecretName -f cert.pfx
    certutil -silent -f -importpfx cert.pfx
    Remove-Item cert.pfx
    az keyvault secret download --subscription $subscriptionId --vault-name $keyVaultName --name $esrpSigningCertSecretName -f cert.pfx
    certutil -silent -f -importpfx cert.pfx
    Remove-Item cert.pfx
    Write-Host 'Done.'
    Write-Host 'Executing ESRP Client.'
    ./esrp/tools/EsrpClient.exe sign -a ./auth.json -p ./esrp/tools/Policy.json -c ./esrp/tools/Config.json -i ./input.json -o ./Output.json -l Verbose -f STDOUT
    $signedFileName = (Get-ChildItem -Recurse -Path signed -Filter *.nupkg | Select-Object -Property Name -First 1).Name
    if ($signedFileName -match ' ') {
        # This accounts for cases where it finds the same package and we end up with $signedFileName = "proj.1.1.0.nupkg proj.1.1.0.nupkg"
        $signedFileName = $signedFileName.split()[0]
    }

    if ([string]::IsNullOrWhiteSpace($signedFileName)) {
        throw "Unable to find signed nupkg. Check ESRP Client output for errors."
    }

    Write-Host 'Done. Signing Complete.'
    Write-Host 'Verifying signatures with NuGet.'
    $result = nuget verify -Signatures signed/$signedFileName -CertificateFingerprint $esrpSigningCertFingerprint
    Write-Host $result
    $validationFailString = $result | Where-Object { $_ -match 'Package signature validation failed.'}
    $noPackageFailString = $result | Where-Object { $_ -match 'File does not exist'}
    if (![string]::IsNullOrWhiteSpace($validationFailString)) {
        throw 'Package signature validation failed.'
    } elseif (![string]::IsNullOrWhiteSpace($noPackageFailString)) {
        throw 'The ESRP Client did not produce a signed package for verification.'
    } else {
        Write-Host 'Done. Signatures verified.'
        Write-Host 'Package ready for upload.'
    }
} catch {
    throw
} finally {
    if ($userLogin) {
        az logout
    }
}