$url = "https://raw.githubusercontent.com/NuGet/NuGetGallery/master/src/VerifyMicrosoftPackage/verify.ps1"
Invoke-WebRequest $url -OutFile verify.ps1
.\verify.ps1 .\unsigned\*.nupkg