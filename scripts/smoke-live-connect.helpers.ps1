function Get-AstralSmokeTargetSubset {
    param(
        [string[]]$SelectedTargetIds,
        [string[]]$EligibleTargetIds
    )

    $eligible = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($targetId in $EligibleTargetIds) {
        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
            [void]$eligible.Add($targetId.Trim())
        }
    }

    return @(
        $SelectedTargetIds |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and
                $eligible.Contains($_.Trim())
            } |
            ForEach-Object { $_.Trim().ToLowerInvariant() } |
            Select-Object -Unique
    )
}

function Get-AstralSmokeExpectedLockDomains {
    param([string[]]$SelectedTargetIds)

    $domainsByTarget = @{
        'discord' = @('discord.com', 'discordapp.com', 'discordapp.net', 'discord.gg', 'discord.gift', 'discord.media', 'discordstatus.com', 'discordcdn.com', 'cdn.discordapp.com', 'dl.discordapp.net', 'updates.discord.com', 'gateway.discord.gg', 'media.discordapp.net')
        'wattpad' = @('wattpad.com', 'www.wattpad.com', 'api.wattpad.com', 'img.wattpad.com', 'static.wattpad.com')
        'azar' = @('azarlive.com', 'www.azarlive.com', 'api.azarlive.com', 'azarlive.io', 'api.azarlive.io')
        'bigo-live' = @('bigo.tv', 'www.bigo.tv', 'mobile.bigo.tv', 'bigolive.tv', 'www.bigolive.tv')
        'imvu' = @('imvu.com', 'www.imvu.com', 'secure.imvu.com', 'api.imvu.com', 'userimages-akm.imvu.com')
        'livu' = @('livuapp.com', 'www.livuapp.com', 'livu.me', 'www.livu.me', 'api.livu.me')
        'tango' = @('tango.me', 'www.tango.me', 'api.tango.me')
        'blogspot' = @('blogspot.com', 'blogger.com', 'www.blogger.com', 'blogger.googleusercontent.com')
        'radio-garden' = @('radio.garden', 'www.radio.garden')
        'deutsche-welle' = @('dw.com', 'www.dw.com', 'amp.dw.com', 'static.dw.com')
        'voice-of-america' = @('voanews.com', 'www.voanews.com', 'learningenglish.voanews.com', 'gdb.voanews.com')
        'eksi-sozluk' = @('eksisozluk.com', 'www.eksisozluk.com', 'eksisozluk1923.com', 'www.eksisozluk1923.com')
        'grok' = @('grok.com', 'www.grok.com', 'x.ai', 'www.x.ai')
        'imgur' = @('imgur.com', 'www.imgur.com', 'i.imgur.com', 'api.imgur.com', 's.imgur.com')
        'pastebin' = @('pastebin.com', 'www.pastebin.com', 'pastebin.pl', 'www.pastebin.pl')
    }

    $domains = [Collections.Generic.List[string]]::new()
    foreach ($targetId in $SelectedTargetIds) {
        if ([string]::IsNullOrWhiteSpace($targetId)) {
            continue
        }

        $normalizedTargetId = $targetId.Trim().ToLowerInvariant()
        if (-not $domainsByTarget.ContainsKey($normalizedTargetId)) {
            continue
        }

        foreach ($domain in $domainsByTarget[$normalizedTargetId]) {
            [void]$domains.Add($domain)
        }
    }

    return @($domains | Select-Object -Unique)
}

function Set-AstralSmokeSettingsForRun {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedTargetIds
    )

    $targetSelection = [pscustomobject]@{
        SelectedTargetIds = @($SelectedTargetIds)
    }

    $Settings | Add-Member `
        -Force `
        -NotePropertyName BrowserAccessEnabled `
        -NotePropertyValue $false
    $Settings | Add-Member `
        -Force `
        -NotePropertyName BrowserAccessPreferenceVersion `
        -NotePropertyValue 1
    $Settings | Add-Member `
        -Force `
        -NotePropertyName TargetSelectionPreferenceVersion `
        -NotePropertyValue 2
    $Settings | Add-Member `
        -Force `
        -NotePropertyName TargetSelection `
        -NotePropertyValue $targetSelection
    $Settings | Add-Member `
        -Force `
        -NotePropertyName RunInBackgroundOnClose `
        -NotePropertyValue $false

    return $Settings
}

function Test-AstralSmokeDelimitedTargetSetEquals {
    param(
        [AllowEmptyString()]
        [string]$Actual,
        [string[]]$Expected
    )

    $actualSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($targetId in @($Actual -split ',')) {
        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
            [void]$actualSet.Add($targetId.Trim())
        }
    }

    $expectedSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($targetId in $Expected) {
        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
            [void]$expectedSet.Add($targetId.Trim())
        }
    }

    return $actualSet.SetEquals($expectedSet)
}

function Restore-AstralSmokeSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,
        [Parameter(Mandatory = $true)]
        [byte[]]$OriginalBytes
    )

    [IO.File]::WriteAllBytes($SettingsPath, $OriginalBytes)
    $restoredBytes = [IO.File]::ReadAllBytes($SettingsPath)
    return [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals(
        $OriginalBytes,
        $restoredBytes)
}

function Restore-AstralSmokeSettingsState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,
        [AllowNull()]
        [byte[]]$OriginalBytes,
        [Parameter(Mandatory = $true)]
        [bool]$OriginalExisted
    )

    if ($OriginalExisted) {
        if ($null -eq $OriginalBytes) {
            throw 'Ozgun settings dosyasi vardi ancak yedek baytlari yok.'
        }

        return Restore-AstralSmokeSettings `
            -SettingsPath $SettingsPath `
            -OriginalBytes $OriginalBytes
    }

    if (Test-Path -LiteralPath $SettingsPath) {
        Remove-Item -LiteralPath $SettingsPath -Force
    }

    return -not (Test-Path -LiteralPath $SettingsPath)
}

function Test-AstralSmokeRestoreStartupReady {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$WindowFound,
        [Parameter(Mandatory = $true)]
        [bool]$TargetLockRestored
    )

    return $WindowFound -and $TargetLockRestored
}

function Get-AstralSmokeSelectedTargetIdsFromSettingsBytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$SettingsBytes
    )

    $json = [Text.UTF8Encoding]::new(
        $false,
        $true).GetString($SettingsBytes)
    $settings = $json | ConvertFrom-Json
    $selectedTargetIds = @(
        $settings.TargetSelection.SelectedTargetIds |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } |
            Select-Object -Unique
    )
    if ($selectedTargetIds.Count -eq 0) {
        return @('discord')
    }

    return $selectedTargetIds
}

function Test-AstralSmokeHostsLockContent {
    param(
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedDomains
    )

    $beginMarker = '# BEGIN Astral hedef kilidi'
    $endMarker = '# END Astral hedef kilidi'
    $lines = @($Content -split "`r?`n")
    $beginIndexes = @(
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ([string]::Equals(
                $lines[$index].Trim(),
                $beginMarker,
                [StringComparison]::Ordinal)) {
                $index
            }
        }
    )
    $endIndexes = @(
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ([string]::Equals(
                $lines[$index].Trim(),
                $endMarker,
                [StringComparison]::Ordinal)) {
                $index
            }
        }
    )
    if ($beginIndexes.Count -ne 1 -or
        $endIndexes.Count -ne 1 -or
        $endIndexes[0] -le $beginIndexes[0]) {
        return $false
    }

    $ipv4Domains = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    $ipv6Domains = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    for ($index = $beginIndexes[0] + 1; $index -lt $endIndexes[0]; $index++) {
        $line = $lines[$index].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $match = [regex]::Match(
            $line,
            '^(0\.0\.0\.0|::1)\s+([^\s#]+)$',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant)
        if (-not $match.Success) {
            return $false
        }

        $address = $match.Groups[1].Value
        $domain = $match.Groups[2].Value
        if ($address -eq '0.0.0.0') {
            [void]$ipv4Domains.Add($domain)
        }
        else {
            [void]$ipv6Domains.Add($domain)
        }
    }

    $expected = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($domain in $ExpectedDomains) {
        if (-not [string]::IsNullOrWhiteSpace($domain)) {
            [void]$expected.Add($domain.Trim())
        }
    }

    return $ipv4Domains.SetEquals($expected) -and
        $ipv6Domains.SetEquals($expected)
}

function Test-AstralSmokeCleanupState {
    param(
        [Parameter(Mandatory = $true)]
        [object]$OriginalAutoConfigState,
        [Parameter(Mandatory = $true)]
        [object]$CurrentAutoConfigState,
        [bool]$PacFileExists,
        [bool]$PacStateFileExists,
        [bool]$HostsLockPresent,
        [bool]$FirewallRuleEnabled
    )

    return (Test-AstralSmokeAutoConfigStateEquals `
            -Original $OriginalAutoConfigState `
            -Current $CurrentAutoConfigState) -and
        (-not $PacFileExists) -and
        (-not $PacStateFileExists) -and
        $HostsLockPresent -and
        $FirewallRuleEnabled
}

function Test-AstralSmokeAutoConfigStateEquals {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Original,
        [Parameter(Mandatory = $true)]
        [object]$Current
    )

    return [bool]$Original.Exists -eq [bool]$Current.Exists -and
        [string]::Equals(
            [string]$Original.Kind,
            [string]$Current.Kind,
            [StringComparison]::Ordinal) -and
        [string]::Equals(
            [string]$Original.Value,
            [string]$Current.Value,
            [StringComparison]::Ordinal)
}

function Get-AstralSmokeAutoConfigState {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        'Software\Microsoft\Windows\CurrentVersion\Internet Settings')
    try {
        if ($null -eq $key) {
            return [pscustomobject]@{ Exists = $false; Kind = ''; Value = '' }
        }

        $exists = @($key.GetValueNames()) -contains 'AutoConfigURL'
        if (-not $exists) {
            return [pscustomobject]@{ Exists = $false; Kind = ''; Value = '' }
        }

        return [pscustomobject]@{
            Exists = $true
            Kind = [string]$key.GetValueKind('AutoConfigURL')
            Value = [string]$key.GetValue(
                'AutoConfigURL',
                $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    }
    finally {
        if ($null -ne $key) {
            $key.Dispose()
        }
    }
}

function Invoke-AstralSmokeFinalCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$StopAction,
        [Parameter(Mandatory = $true)]
        [scriptblock]$CleanupAction
    )

    $failures = [Collections.Generic.List[Exception]]::new()
    try {
        & $StopAction
    }
    catch {
        $failures.Add($_.Exception)
    }

    try {
        & $CleanupAction
    }
    catch {
        $failures.Add($_.Exception)
    }

    if ($failures.Count -eq 1) {
        throw $failures[0]
    }

    if ($failures.Count -gt 1) {
        throw [AggregateException]::new(
            'Astral smoke final cleanup birden fazla hatayla tamamlanamadi.',
            $failures)
    }
}

function Test-AstralSmokeHasRunningInstance {
    param([object[]]$Processes)

    return @($Processes).Count -gt 0
}
