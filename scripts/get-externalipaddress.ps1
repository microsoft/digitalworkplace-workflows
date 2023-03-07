function Get-ExternalIPAddress {
    param (
        [Parameter(Mandatory=$true)] [string]$outputName
    )
    $ipAddress = (Invoke-WebRequest -Uri 'https://api.ipify.org').Content

    Write-Output "::add-mask::$ipAddress"
    Write-Output "$outputName=$ipAddress" >> $env:GITHUB_OUTPUT

    $redacted = $ipAddress -replace "(?!\d+\.\d+\.)\d", "*"
    Write-Output "GitHub Action runner's external IP address: $redacted"
}
