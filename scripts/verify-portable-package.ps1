[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [Parameter(Mandatory = $true)]
    [string]$ChecksumPath,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,
    [switch]$SkipLaunch
)

$ErrorActionPreference = 'Stop'
$requiredRelativePaths = @(
    'Astral.exe',
    'Astral.Updater.exe',
    'Astral.WebProxy.exe',
    'coreclr.dll',
    'hostfxr.dll',
    'clrjit.dll',
    'Assets/background.mp4',
    'astral.update-manifest.json'
)
$executableRelativePaths = @(
    'Astral.exe',
    'Astral.Updater.exe',
    'Astral.WebProxy.exe'
)
$verificationRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'Astral Taşınabilir Doğrulama ' + [guid]::NewGuid().ToString('N'))
$extractRoot = Join-Path $verificationRoot 'paket içeriği'

function Get-NormalizedRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Replace('\', '/').TrimStart('/')
}

function Assert-X64PortableExecutable {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = [IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw "PE DOS imzası geçersiz: $Path"
        }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 0x40 -or $peOffset -gt ($stream.Length - 6)) {
            throw "PE başlık konumu geçersiz: $Path"
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "PE imzası geçersiz: $Path"
        }
        $machine = $reader.ReadUInt16()
        if ($machine -ne 0x8664) {
            throw ('win-x64 paketinde x64 olmayan executable bulundu: {0} machine=0x{1:X4}' -f $Path, $machine)
        }
    }
    finally {
        $stream.Dispose()
    }
}

try {
    $resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
    $resolvedChecksum = (Resolve-Path -LiteralPath $ChecksumPath).Path
    $checksumText = (Get-Content -Raw -LiteralPath $resolvedChecksum).Trim()
    if ($checksumText -notmatch '^([A-Fa-f0-9]{64})\s+(.+)$') {
        throw "SHA-256 yan dosyası biçimi geçersiz: $resolvedChecksum"
    }
    $expectedHash = $Matches[1]
    $checksumFileName = $Matches[2].Trim()
    if ($checksumFileName -ne [IO.Path]::GetFileName($resolvedArchive)) {
        throw "SHA-256 yan dosyasındaki arşiv adı eşleşmiyor: $checksumFileName"
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedArchive).Hash
    if ($actualHash -ne $expectedHash) {
        throw "Portable paket SHA-256 doğrulaması başarısız oldu: $resolvedArchive"
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($resolvedArchive)
    try {
        $canonicalExtractRoot = [IO.Path]::GetFullPath($extractRoot).TrimEnd('\') + '\'
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.FullName)) {
                continue
            }
            $entryPath = [IO.Path]::GetFullPath((Join-Path $extractRoot $entry.FullName))
            if (-not $entryPath.StartsWith($canonicalExtractRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "ZIP kökünün dışına çıkan paket girdisi reddedildi: $($entry.FullName)"
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $resolvedArchive -DestinationPath $extractRoot

    foreach ($relativePath in $requiredRelativePaths) {
        $fullPath = Join-Path $extractRoot ($relativePath.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Portable pakette zorunlu dosya eksik: $relativePath"
        }
        if ((Get-Item -LiteralPath $fullPath).Length -le 0) {
            throw "Portable pakette zorunlu dosya boş: $relativePath"
        }
    }

    $manifestPath = Join-Path $extractRoot 'astral.update-manifest.json'
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ([string]$manifest.version -ne $ExpectedVersion) {
        throw "Update manifest sürümü eşleşmiyor: $($manifest.version) != $ExpectedVersion"
    }

    $manifestEntries = @{}
    foreach ($entry in @($manifest.files)) {
        $relativePath = Get-NormalizedRelativePath -Path ([string]$entry.path)
        if ([string]::IsNullOrWhiteSpace($relativePath) -or $manifestEntries.ContainsKey($relativePath)) {
            throw "Update manifest yolu boş veya yinelenmiş: $relativePath"
        }
        $manifestEntries[$relativePath] = $entry
    }

    $packageFiles = @(
        Get-ChildItem -LiteralPath $extractRoot -File -Recurse |
            ForEach-Object {
                Get-NormalizedRelativePath -Path $_.FullName.Substring($extractRoot.Length).TrimStart('\')
            }
    )
    $expectedPackageFiles = @($manifestEntries.Keys) + 'astral.update-manifest.json'
    $unexpectedFiles = @($packageFiles | Where-Object { $_ -notin $expectedPackageFiles })
    $missingFiles = @($expectedPackageFiles | Where-Object { $_ -notin $packageFiles })
    if ($unexpectedFiles.Count -gt 0 -or $missingFiles.Count -gt 0) {
        throw "Update manifest dosya kümesi paketle eşleşmiyor. eksik=$($missingFiles -join ',') fazla=$($unexpectedFiles -join ',')"
    }

    foreach ($relativePath in $manifestEntries.Keys) {
        $entry = $manifestEntries[$relativePath]
        $fullPath = Join-Path $extractRoot ($relativePath.Replace('/', '\'))
        $file = Get-Item -LiteralPath $fullPath
        if ($file.Length -ne [long]$entry.length) {
            throw "Update manifest dosya boyutu eşleşmiyor: $relativePath"
        }
        $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash
        if ($fileHash -ne [string]$entry.sha256) {
            throw "Update manifest dosya özeti eşleşmiyor: $relativePath"
        }
    }

    foreach ($relativePath in $executableRelativePaths) {
        Assert-X64PortableExecutable -Path (Join-Path $extractRoot $relativePath)
    }

    if (-not $SkipLaunch) {
        $mainExecutable = Join-Path $extractRoot 'Astral.exe'
        $process = Start-Process `
            -FilePath $mainExecutable `
            -ArgumentList '--portable-package-self-test' `
            -WorkingDirectory $extractRoot `
            -PassThru
        if (-not $process.WaitForExit(20000)) {
            throw "Portable Astral başlangıç testi 20 saniyede tamamlanmadı. pid=$($process.Id)"
        }
        if ($process.ExitCode -ne 0) {
            throw "Portable Astral başlangıç testi başarısız oldu. exit=$($process.ExitCode)"
        }
    }

    Write-Host "Portable paket doğrulandı. version=$ExpectedVersion sha256=$actualHash path='$extractRoot' launch=$(-not $SkipLaunch)"
}
finally {
    if (Test-Path -LiteralPath $verificationRoot) {
        Remove-Item -LiteralPath $verificationRoot -Recurse -Force
    }
}
