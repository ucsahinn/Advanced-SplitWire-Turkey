[CmdletBinding()]
param(
    [string]$Runtime = 'win-x64',
    [string]$CodeSigningCertificatePath,
    [string]$CodeSigningCertificatePassword,
    [string]$TimestampUrl = 'http://timestamp.digicert.com',
    [switch]$RequireCodeSigning,
    [switch]$RequireGitleaks
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root "artifacts\publish\$Runtime"
$projectPath = Join-Path $root 'src\Astral.App\Astral.App.csproj'
$project = [xml](Get-Content -Raw -LiteralPath $projectPath)
$version = $project.Project.PropertyGroup.Version
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Astral surumu proje dosyasindan okunamadi"
}
if ([string]::IsNullOrWhiteSpace($CodeSigningCertificatePassword) -and
    -not [string]::IsNullOrWhiteSpace($env:ASTRAL_CODESIGN_PFX_PASSWORD)) {
    $CodeSigningCertificatePassword = $env:ASTRAL_CODESIGN_PFX_PASSWORD
}

$archive = Join-Path $root "artifacts\Astral-$version-$Runtime.zip"
$shaPath = Join-Path $root "artifacts\Astral-$version-$Runtime.sha256.txt"
$stableArchive = Join-Path $root "artifacts\Astral-$Runtime.zip"
$stableShaPath = Join-Path $root "artifacts\Astral-$Runtime.sha256.txt"
$signingStatusPath = Join-Path $root 'artifacts\signing-status.txt'
$wireSockInstallerName = 'wiresock-vpn-client-x64-1.4.7.1.msi'
$wireSockInstallerHash = 'FA3F483DA7EA1AE6C234F95BECB0AA6A18E7EB18B944D3FFB4518D40F4292F40'
$wireSockInstallerSource = Join-Path $root "vendor\wiresock\$wireSockInstallerName"
$buildArtifactsPath = Join-Path ([IO.Path]::GetTempPath()) (
    'astral-release-' + [guid]::NewGuid().ToString('N'))
$officialRelease = if ($RequireCodeSigning) { 'true' } else { 'false' }

function New-UpdateManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDirectory,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$ManifestFileName
    )

    $manifestPath = Join-Path $RootDirectory $ManifestFileName
    if (Test-Path -LiteralPath $manifestPath) {
        Remove-Item -LiteralPath $manifestPath -Force
    }

    $manifestRoot = [IO.Path]::GetFullPath($RootDirectory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $manifestFiles = Get-ChildItem -LiteralPath $RootDirectory -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = [IO.Path]::GetFullPath($_.FullName).Substring($manifestRoot.Length).TrimStart('\', '/')
            $relativePath = $relativePath -replace '\\', '/'
            $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
            [pscustomobject]@{
                path = $relativePath
                length = $_.Length
                sha256 = $fileHash
            }
        }

    [pscustomobject]@{
        version = $Version
        files = $manifestFiles
    } |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

function New-ReleaseArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$ShaPath
    )

    if (Test-Path -LiteralPath $ArchivePath) {
        Remove-Item -LiteralPath $ArchivePath -Force
    }

    Compress-Archive -Path (Join-Path $SourceDirectory '*') -DestinationPath $ArchivePath
    $archiveHash = Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath
    Set-Content `
        -LiteralPath $ShaPath `
        -Value "$($archiveHash.Hash)  $(Split-Path -Leaf $ArchivePath)" `
        -Encoding ASCII

    return $archiveHash
}

Push-Location $root

try {
    & "$PSScriptRoot\verify.ps1" `
        -ArtifactsPath (Join-Path $buildArtifactsPath 'verify') `
        -RequireGitleaks:$RequireGitleaks

    if (Test-Path -LiteralPath $output) {
        Remove-Item -LiteralPath $output -Recurse -Force
    }

    dotnet publish src\Astral.App\Astral.App.csproj `
        --configuration Release `
        --runtime $Runtime `
        --self-contained true `
        --output $output `
        --artifacts-path (Join-Path $buildArtifactsPath 'publish') `
        --disable-build-servers `
        -p:AstralOfficialRelease=$officialRelease `
        -p:DebugType=None `
        -p:DebugSymbols=false
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish hata kodu $LASTEXITCODE ile basarisiz oldu"
    }

    $webProxyExecutable = Join-Path $output 'Astral.WebProxy.exe'
    if (-not (Test-Path -LiteralPath $webProxyExecutable)) {
        throw "Single-file Astral.WebProxy executable bulunamadi: $webProxyExecutable"
    }

    $unexpectedWebProxyFiles = @(
        'Astral.WebProxy.dll',
        'Astral.WebProxy.deps.json',
        'Astral.WebProxy.runtimeconfig.json'
    ) | Where-Object { Test-Path -LiteralPath (Join-Path $output $_) }
    if ($unexpectedWebProxyFiles.Count -gt 0) {
        throw "Release WebProxy single-file olmali; beklenmeyen dosyalar: $($unexpectedWebProxyFiles -join ', ')"
    }

    if (Test-Path -LiteralPath $wireSockInstallerSource) {
        $wireSockInstallerActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $wireSockInstallerSource).Hash
        if (-not [string]::Equals(
                $wireSockInstallerActualHash,
                $wireSockInstallerHash,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "WireSock kurucu SHA-256 dogrulamasi basarisiz oldu: $wireSockInstallerSource"
        }

        $wireSockInstallerOutput = Join-Path $output 'installers'
        New-Item -ItemType Directory -Path $wireSockInstallerOutput -Force | Out-Null
        Copy-Item `
            -LiteralPath $wireSockInstallerSource `
            -Destination (Join-Path $wireSockInstallerOutput $wireSockInstallerName) `
            -Force
    }

    $signed = $false
    if (-not [string]::IsNullOrWhiteSpace($CodeSigningCertificatePath) -or $RequireCodeSigning) {
        & "$PSScriptRoot\sign-release.ps1" `
            -PublishDirectory $output `
            -CertificatePath $CodeSigningCertificatePath `
            -CertificatePassword $CodeSigningCertificatePassword `
            -TimestampUrl $TimestampUrl
        $signed = $true
    }
    else {
        Write-Host 'Kod imzalama atlandi: sertifika yapilandirilmadi.'
    }

    if ($signed) {
        Set-Content -LiteralPath $signingStatusPath -Value 'signed' -Encoding ASCII
    }
    else {
        Set-Content -LiteralPath $signingStatusPath -Value 'unsigned' -Encoding ASCII
    }

    New-UpdateManifest `
        -RootDirectory $output `
        -Version $version `
        -ManifestFileName 'astral.update-manifest.json'

    if ($RequireGitleaks) {
        $gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
        if ($null -eq $gitleaks) {
            throw 'gitleaks bulunamadi; release paketi secret scan calistirilamadi.'
        }

        & $gitleaks.Source dir $output --redact --no-banner --exit-code 1
        if ($LASTEXITCODE -ne 0) {
            throw "Release paketi gitleaks taramasi hata kodu $LASTEXITCODE ile basarisiz oldu"
        }
    }

    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    if (Test-Path -LiteralPath $stableArchive) {
        Remove-Item -LiteralPath $stableArchive -Force
    }

    $hash = New-ReleaseArchive `
        -SourceDirectory $output `
        -ArchivePath $archive `
        -ShaPath $shaPath
    & "$PSScriptRoot\verify-portable-package.ps1" `
        -ArchivePath $archive `
        -ChecksumPath $shaPath `
        -ExpectedVersion $version
    if ($LASTEXITCODE -ne 0) {
        throw "Portable paket dogrulamasi hata kodu $LASTEXITCODE ile basarisiz oldu"
    }
    Copy-Item -LiteralPath $archive -Destination $stableArchive -Force
    Set-Content `
        -LiteralPath $stableShaPath `
        -Value "$($hash.Hash)  $(Split-Path -Leaf $stableArchive)" `
        -Encoding ASCII

    $hash
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $buildArtifactsPath) {
        Remove-Item -LiteralPath $buildArtifactsPath -Recurse -Force
    }
}
