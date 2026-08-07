[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'scripts\smoke-live-connect.helpers.ps1')

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ([string]$Actual -ne [string]$Expected) {
        throw "$Message Beklenen='$Expected'; Gercek='$Actual'."
    }
}

$webTargetIds = @(
    'discord',
    'wattpad',
    'bigo-live'
)
$applicationTargetIds = @(
    'discord',
    'imvu'
)
$selectedTargetIds = @(
    'discord',
    'wattpad',
    'unknown'
)

$webSelection = @(
    Get-AstralSmokeTargetSubset `
        -SelectedTargetIds $selectedTargetIds `
        -EligibleTargetIds $webTargetIds
)
Assert-Equal `
    -Actual ($webSelection -join ',') `
    -Expected 'discord,wattpad' `
    -Message 'Smoke web kaniti secili hedef kimliklerini exact korumalidir.'
Write-Host 'GEÇTİ Smoke web kaniti secili hedef kimliklerini exact korur'

$extraWebProof = Test-AstralSmokeDelimitedTargetSetEquals `
    -Actual 'discord,wattpad,bigo-live' `
    -Expected @('discord', 'wattpad')
Assert-Equal `
    -Actual $extraWebProof `
    -Expected $false `
    -Message 'Smoke web kaniti secilmeyen ekstra hedefi reddetmelidir.'
Write-Host 'GEÇTİ Smoke web kaniti ekstra hedef kimligini reddeder'

$applicationSelection = @(
    Get-AstralSmokeTargetSubset `
        -SelectedTargetIds $selectedTargetIds `
        -EligibleTargetIds $applicationTargetIds
)
Assert-Equal `
    -Actual ($applicationSelection -join ',') `
    -Expected 'discord' `
    -Message 'Smoke app kaniti secili hedef kimliklerini exact korumalidir.'
Write-Host 'GEÇTİ Smoke app kaniti secili hedef kimliklerini exact korur'

$exactAppProof = Test-AstralSmokeDelimitedTargetSetEquals `
    -Actual 'discord' `
    -Expected @('discord')
Assert-Equal `
    -Actual $exactAppProof `
    -Expected $true `
    -Message 'Smoke app kaniti exact hedef setini kabul etmelidir.'
$extraAppProof = Test-AstralSmokeDelimitedTargetSetEquals `
    -Actual 'discord,imvu' `
    -Expected @('discord')
Assert-Equal `
    -Actual $extraAppProof `
    -Expected $false `
    -Message 'Smoke app kaniti secilmeyen ekstra hedefi reddetmelidir.'
Write-Host 'GEÇTİ Smoke app kaniti ekstra hedef kimligini reddeder'

$settings = [pscustomobject]@{
    AcceptedCloudflareWarpTerms = $true
    AcceptedWireSockVersion = '1.4.7.1'
    DebugDiagnosticsEnabled = $true
    RunInBackgroundOnClose = $true
    StartWithWindows = $true
    TargetSelection = [pscustomobject]@{
        SelectedTargetIds = @('discord')
    }
}

$prepared = Set-AstralSmokeSettingsForRun `
    -Settings $settings `
    -SelectedTargetIds @('wattpad')

Assert-Equal `
    -Actual $prepared.RunInBackgroundOnClose `
    -Expected $false `
    -Message 'Smoke normal pencere kapanisinda uygulamayi arka planda birakmamalidir.'
Assert-Equal `
    -Actual $prepared.DebugDiagnosticsEnabled `
    -Expected $true `
    -Message 'Smoke kullanicinin debug tanilama tercihini korumalidir.'
Assert-Equal `
    -Actual ($prepared.TargetSelection.SelectedTargetIds -join ',') `
    -Expected 'wattpad' `
    -Message 'Smoke gecici hedef secimini exact yazmalidir.'
Assert-Equal `
    -Actual $prepared.StartWithWindows `
    -Expected $true `
    -Message 'Smoke ilgisiz baslangic tercihini degistirmemelidir.'
Write-Host 'GEÇTİ Smoke gecici ayari cleanup guvenli hazirlar'

$settingsPath = Join-Path ([IO.Path]::GetTempPath()) (
    'astral-smoke-settings-' + [guid]::NewGuid().ToString('N') + '.json')
$originalBytes = [Text.UTF8Encoding]::new($false).GetBytes(
    "{`n  `"DebugDiagnosticsEnabled`": true`n}`n")
try {
    [IO.File]::WriteAllText($settingsPath, '{"temporary":true}')
    $restoreSucceeded = Restore-AstralSmokeSettings `
        -SettingsPath $settingsPath `
        -OriginalBytes $originalBytes
    Assert-Equal `
        -Actual $restoreSucceeded `
        -Expected $true `
        -Message 'Smoke ayar geri yuklemesi basarili oldugunu raporlamalidir.'
    $restoredBytes = [IO.File]::ReadAllBytes($settingsPath)
    Assert-Equal `
        -Actual ([BitConverter]::ToString($restoredBytes)) `
        -Expected ([BitConverter]::ToString($originalBytes)) `
        -Message 'Smoke ayarlari uygulama kapandiktan sonra byte-for-byte geri yuklenmelidir.'
}
finally {
    if (Test-Path -LiteralPath $settingsPath) {
        Remove-Item -LiteralPath $settingsPath -Force
    }
}
Write-Host 'GEÇTİ Smoke ayarlari byte-for-byte geri yuklenir'

$missingSettingsPath = Join-Path ([IO.Path]::GetTempPath()) (
    'astral-smoke-missing-settings-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    [IO.File]::WriteAllText($missingSettingsPath, '{"generated":true}')
    $missingStateRestored = Restore-AstralSmokeSettingsState `
        -SettingsPath $missingSettingsPath `
        -OriginalBytes $null `
        -OriginalExisted $false
    Assert-Equal `
        -Actual $missingStateRestored `
        -Expected $true `
        -Message 'Smoke temiz profilde sonradan uretilen settings dosyasini silmelidir.'
    Assert-Equal `
        -Actual (Test-Path -LiteralPath $missingSettingsPath) `
        -Expected $false `
        -Message 'Smoke ilk calisma settings dosyasini kullaniciya birakmamalidir.'
}
finally {
    if (Test-Path -LiteralPath $missingSettingsPath) {
        Remove-Item -LiteralPath $missingSettingsPath -Force
    }
}
Write-Host 'GEÇTİ Smoke temiz profil settings yoklugunu final cleanup sonrasinda korur'

$cleanupPassed = Test-AstralSmokeCleanupState `
    -OriginalAutoConfigState ([pscustomobject]@{
        Exists = $true
        Kind = 'String'
        Value = 'https://corp.example/Proxy.pac'
    }) `
    -CurrentAutoConfigState ([pscustomobject]@{
        Exists = $true
        Kind = 'String'
        Value = 'https://corp.example/Proxy.pac'
    }) `
    -PacFileExists $false `
    -PacStateFileExists $false `
    -HostsLockPresent $true `
    -FirewallRuleEnabled $true
Assert-Equal `
    -Actual $cleanupPassed `
    -Expected $true `
    -Message 'Smoke cleanup onceki PAC ve disconnected kilitlerini geri getirmelidir.'

$cleanupRejected = Test-AstralSmokeCleanupState `
    -OriginalAutoConfigState ([pscustomobject]@{
        Exists = $false
        Kind = ''
        Value = ''
    }) `
    -CurrentAutoConfigState ([pscustomobject]@{
        Exists = $true
        Kind = 'String'
        Value = 'file:///stale/astral-scoped.pac'
    }) `
    -PacFileExists $true `
    -PacStateFileExists $true `
    -HostsLockPresent $true `
    -FirewallRuleEnabled $true
Assert-Equal `
    -Actual $cleanupRejected `
    -Expected $false `
    -Message 'Smoke cleanup stale Astral PAC durumunu basarili saymamalidir.'
Write-Host 'GEÇTİ Smoke cleanup onceki PAC ve disconnected kilitlerini zorunlu tutar'

$caseChanged = Test-AstralSmokeAutoConfigStateEquals `
    -Original ([pscustomobject]@{
        Exists = $true
        Kind = 'String'
        Value = 'https://corp.example/Proxy.pac'
    }) `
    -Current ([pscustomobject]@{
        Exists = $true
        Kind = 'String'
        Value = 'https://corp.example/proxy.pac'
    })
Assert-Equal `
    -Actual $caseChanged `
    -Expected $false `
    -Message 'Smoke PAC degerindeki case degisikligini drift saymalidir.'

$missingBecameEmpty = Test-AstralSmokeAutoConfigStateEquals `
    -Original ([pscustomobject]@{ Exists = $false; Kind = ''; Value = '' }) `
    -Current ([pscustomobject]@{ Exists = $true; Kind = 'String'; Value = '' })
Assert-Equal `
    -Actual $missingBecameEmpty `
    -Expected $false `
    -Message 'Smoke eksik PAC degeri ile bos PAC degerini ayirmalidir.'
Write-Host 'GEÇTİ Smoke PAC state varlik, tur ve deger driftini exact reddeder'

$discordHostsLock = @'
127.0.0.1 localhost
# BEGIN Astral hedef kilidi
0.0.0.0 discord.com
::1 discord.com
0.0.0.0 discord.gg
::1 discord.gg
# END Astral hedef kilidi
'@
Assert-Equal `
    -Actual (Test-AstralSmokeHostsLockContent `
        -Content $discordHostsLock `
        -ExpectedDomains @('discord.com', 'discord.gg')) `
    -Expected $true `
    -Message 'Smoke hosts kilidi geri yuklenen hedeflerin exact setini kabul etmelidir.'
$staleWattpadHostsLock = $discordHostsLock.Replace(
    '# END Astral hedef kilidi',
    "0.0.0.0 wattpad.com`n::1 wattpad.com`n# END Astral hedef kilidi")
Assert-Equal `
    -Actual (Test-AstralSmokeHostsLockContent `
        -Content $staleWattpadHostsLock `
        -ExpectedDomains @('discord.com', 'discord.gg')) `
    -Expected $false `
    -Message 'Smoke hosts kilidi gecici hedeften kalan ekstra domaini reddetmelidir.'
Write-Host 'GEÇTİ Smoke hosts kilidi geri yuklenen hedef setini exact dogrular'

$discordLockDomains = @(Get-AstralSmokeExpectedLockDomains `
    -SelectedTargetIds @('discord'))
Assert-Equal `
    -Actual $discordLockDomains.Count `
    -Expected 13 `
    -Message 'Smoke Discord kilidi TargetRegistry tam domain setini kullanmalidir.'
Assert-Equal `
    -Actual ($discordLockDomains -contains 'media.discordapp.net') `
    -Expected $true `
    -Message 'Smoke Discord kilidi son routing domainlerini eksik birakmamalidir.'
$wattpadLockDomains = @(Get-AstralSmokeExpectedLockDomains `
    -SelectedTargetIds @('wattpad'))
Assert-Equal `
    -Actual ($wattpadLockDomains -join ',') `
    -Expected 'wattpad.com,www.wattpad.com,api.wattpad.com,img.wattpad.com,static.wattpad.com' `
    -Message 'Smoke Wattpad kilidi TargetRegistry tam domain setini kullanmalidir.'
Write-Host 'GEÇTİ Smoke kilit kataloğu TargetRegistry tam domain setlerini kullanır'

$settingsWithDiscord = [Text.UTF8Encoding]::new($false).GetBytes(
    '{"TargetSelection":{"SelectedTargetIds":["discord"]}}')
Assert-Equal `
    -Actual ((Get-AstralSmokeSelectedTargetIdsFromSettingsBytes `
        -SettingsBytes $settingsWithDiscord) -join ',') `
    -Expected 'discord' `
    -Message 'Smoke cleanup ozgun hedef secimini ayar byte dizisinden okumalıdır.'
Write-Host 'GEÇTİ Smoke cleanup ozgun hedef secimini settings yedeginden okur'

$cleanupRanAfterStopFailure = $false
try {
    Invoke-AstralSmokeFinalCleanup `
        -StopAction { throw 'stop failed' } `
        -CleanupAction { $script:cleanupRanAfterStopFailure = $true }
    throw 'Stop hatasi yeniden firlatilmadi.'
}
catch {
    Assert-Equal `
        -Actual $cleanupRanAfterStopFailure `
        -Expected $true `
        -Message 'Smoke stop hatasinda da settings ve sistem cleanup calistirmalidir.'
}
Write-Host 'GEÇTİ Smoke stop hatasinda da final cleanup calisir'

$runningInstanceDetected = Test-AstralSmokeHasRunningInstance `
    -Processes @([pscustomobject]@{ Id = 42; ProcessName = 'Astral' })
Assert-Equal `
    -Actual $runningInstanceDetected `
    -Expected $true `
    -Message 'Smoke mevcut Astral ornegini settings mutasyonundan once algilamalidir.'
Assert-Equal `
    -Actual (Test-AstralSmokeHasRunningInstance -Processes @()) `
    -Expected $false `
    -Message 'Smoke bos process listesinde mevcut Astral raporlamamalidir.'
Write-Host 'GEÇTİ Smoke mevcut Astral ornegini mutasyondan once reddeder'

$restoreStartupReady = Test-AstralSmokeRestoreStartupReady `
    -WindowFound $false `
    -TargetLockRestored $true
Assert-Equal `
    -Actual $restoreStartupReady `
    -Expected $false `
    -Message 'Smoke mevcut hedef kilidini restore penceresi oluşmadan startup hazırlığı saymamalıdır.'
$restoreStartupReady = Test-AstralSmokeRestoreStartupReady `
    -WindowFound $true `
    -TargetLockRestored $true
Assert-Equal `
    -Actual $restoreStartupReady `
    -Expected $true `
    -Message 'Smoke restore sürecini pencere ve hedef kilidi birlikte hazırken kapatmalıdır.'
Write-Host 'GEÇTİ Smoke restore sürecinin kendi startup kanıtını bekler'

Write-Host '15 smoke helper testi geçti.'
