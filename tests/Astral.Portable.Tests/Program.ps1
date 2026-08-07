[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$verifier = Join-Path $root 'scripts\verify-portable-package.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'Astral Taşınabilir Şüphe ' + [guid]::NewGuid().ToString('N'))

function New-MinimalX64PeFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [byte[]]::new(512)
    $bytes[0] = 0x4D
    $bytes[1] = 0x5A
    [BitConverter]::GetBytes([int]0x80).CopyTo($bytes, 0x3C)
    $bytes[0x80] = 0x50
    $bytes[0x81] = 0x45
    [BitConverter]::GetBytes([uint16]0x8664).CopyTo($bytes, 0x84)
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function New-PortableFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$UseX86MainExecutable
    )

    $source = Join-Path $testRoot "$Name kaynak"
    $archive = Join-Path $testRoot "$Name paket.zip"
    New-Item -ItemType Directory -Path (Join-Path $source 'Assets') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $source 'installers') -Force | Out-Null

    foreach ($executable in 'Astral.exe', 'Astral.Updater.exe', 'Astral.WebProxy.exe') {
        New-MinimalX64PeFile -Path (Join-Path $source $executable)
    }
    if ($UseX86MainExecutable) {
        $mainExecutable = Join-Path $source 'Astral.exe'
        $bytes = [IO.File]::ReadAllBytes($mainExecutable)
        [BitConverter]::GetBytes([uint16]0x014C).CopyTo($bytes, 0x84)
        [IO.File]::WriteAllBytes($mainExecutable, $bytes)
    }

    [IO.File]::WriteAllText((Join-Path $source 'coreclr.dll'), 'runtime')
    [IO.File]::WriteAllText((Join-Path $source 'hostfxr.dll'), 'runtime')
    [IO.File]::WriteAllText((Join-Path $source 'clrjit.dll'), 'runtime')
    [IO.File]::WriteAllText((Join-Path $source 'Assets\background.mp4'), 'video')
    [IO.File]::WriteAllText(
        (Join-Path $source 'installers\wiresock-vpn-client-x64-1.4.7.1.msi'),
        'installer')

    $files = @(
        Get-ChildItem -LiteralPath $source -File -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                [pscustomobject]@{
                    path = $_.FullName.Substring($source.Length).TrimStart('\') -replace '\\', '/'
                    length = $_.Length
                    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
                }
            }
    )
    [pscustomobject]@{ version = '9.8.7'; files = $files } |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $source 'astral.update-manifest.json') -Encoding UTF8

    Compress-Archive -Path (Join-Path $source '*') -DestinationPath $archive
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
    Set-Content -LiteralPath "$archive.sha256.txt" -Value "$hash  $([IO.Path]::GetFileName($archive))" -Encoding UTF8
    return $archive
}

function Invoke-FixtureVerification {
    param([Parameter(Mandatory = $true)][string]$ArchivePath)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $verifier `
            -ArchivePath $ArchivePath `
            -ChecksumPath "$ArchivePath.sha256.txt" `
            -ExpectedVersion '9.8.7' `
            -SkipLaunch 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            $output | Out-Host
        }
        return $exitCode
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $verifier)) {
        throw "Portable paket doğrulayıcısı bulunamadı: $verifier"
    }

    $validArchive = New-PortableFixture -Name 'geçerli'
    $validExitCode = Invoke-FixtureVerification -ArchivePath $validArchive
    if ($validExitCode -ne 0) {
        throw "Geçerli portable paket reddedildi. exit=$validExitCode"
    }
    Write-Host 'GEÇTİ Portable paket boşluk ve Unicode içeren yolda doğrulanır'

    $tamperedArchive = New-PortableFixture -Name 'bozuk'
    $tamperedSource = Join-Path $testRoot 'bozuk açılmış'
    Expand-Archive -LiteralPath $tamperedArchive -DestinationPath $tamperedSource
    [IO.File]::AppendAllText((Join-Path $tamperedSource 'coreclr.dll'), 'tampered')
    Remove-Item -LiteralPath $tamperedArchive -Force
    Compress-Archive -Path (Join-Path $tamperedSource '*') -DestinationPath $tamperedArchive
    $tamperedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tamperedArchive).Hash
    Set-Content -LiteralPath "$tamperedArchive.sha256.txt" -Value "$tamperedHash  $([IO.Path]::GetFileName($tamperedArchive))" -Encoding UTF8
    $tamperedExitCode = Invoke-FixtureVerification -ArchivePath $tamperedArchive
    if ($tamperedExitCode -eq 0) {
        throw 'Manifest sonrasında değiştirilen dosya kabul edildi.'
    }
    Write-Host 'GEÇTİ Portable paket manifest sonrasındaki dosya değişikliğini reddeder'

    $x86Archive = New-PortableFixture -Name 'yanlış mimari' -UseX86MainExecutable
    $x86ExitCode = Invoke-FixtureVerification -ArchivePath $x86Archive
    if ($x86ExitCode -eq 0) {
        throw 'x86 ana executable win-x64 paketinde kabul edildi.'
    }
    Write-Host 'GEÇTİ Portable paket yanlış executable mimarisini reddeder'

    Write-Host '3 portable paket testi geçti.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
