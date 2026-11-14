<#
.SYNOPSIS
    kotofetch for Windows - shows a random Japanese quote in your terminal.

.DESCRIPTION
    Quotes are downloaded from the .toml files in
    https://github.com/hxpe-dev/kotofetch/tree/main/quotes
    and cached in %APPDATA%\kotofetch\cache. Your own .toml files in
    %APPDATA%\kotofetch\quotes are merged in as well.

    Quote format (same as the original kotofetch):
        [[quote]]
        japanese = "KANJI(reading) text with inline furigana"
        translation = "People live by their hearts."
        romaji = "Hito wa kokoro de ikiru nda"
        source = "Your Name"

.EXAMPLE
    .\kotofetch.ps1
    .\kotofetch.ps1 -Translation furigana,english
    .\kotofetch.ps1 -Modes anime,proverb -FuriganaPosition above
    .\kotofetch.ps1 -ListModes
    .\kotofetch.ps1 -Refresh
#>
[CmdletBinding()]
param(
    [string[]]$Modes,                                   # quote files to use (names without .toml)
    [string[]]$Translation = @('english'),              # none, english, romaji, furigana (combine with commas)
    [ValidateSet('above', 'below')]
    [string]$FuriganaPosition = 'below',
    [int]$HorizontalPadding = 2,
    [int]$VerticalPadding = 0,
    [int]$Width = 0,                                    # max text width, 0 = automatic
    [string]$QuoteColor = 'cyan',                       # name (red, yellow, dim, ...) or hex (#ffcc00)
    [string]$TranslationColor = 'dim',
    [string]$BorderColor = 'dim',
    [switch]$NoBorder,
    [switch]$Square,                                    # square instead of rounded corners
    [switch]$NoSource,
    [switch]$NoBold,
    [switch]$Left,                                      # don't center the text
    [int]$Seed = 0,                                     # 0 = random
    [switch]$Refresh,                                   # re-download quotes from GitHub
    [switch]$Offline,                                   # never touch the network
    [switch]$ListModes,
    [string]$Repo = 'hxpe-dev/kotofetch',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# ---------- enable ANSI colors on older Windows consoles ----------
try {
    if (-not ('KotoVt' -as [type])) {
        Add-Type -Namespace '' -Name 'KotoVt' -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out int m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, int m);
'@
    }
    $h = [KotoVt]::GetStdHandle(-11); $m = 0
    if ([KotoVt]::GetConsoleMode($h, [ref]$m)) { [void][KotoVt]::SetConsoleMode($h, $m -bor 4) }
} catch {}

$ESC = [char]27

# ---------- paths ----------
$appData  = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
$baseDir  = Join-Path $appData 'kotofetch'
$cacheDir = Join-Path $baseDir 'cache'
$userDir  = Join-Path $baseDir 'quotes'
foreach ($d in @($cacheDir, $userDir)) { if (-not (Test-Path $d)) { [void](New-Item -ItemType Directory -Path $d -Force) } }

# ---------- downloading quotes ----------
function Update-QuoteCache {
    $api = "https://api.github.com/repos/$Repo/contents/quotes?ref=$Branch"
    $headers = @{ 'User-Agent' = 'kotofetch-windows'; 'Accept' = 'application/vnd.github+json' }
    $items = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing
    $names = @()
    foreach ($it in $items) {
        if ($it.type -eq 'file' -and $it.name -like '*.toml') {
            $dest = Join-Path $cacheDir $it.name
            Invoke-WebRequest -Uri $it.download_url -OutFile $dest -Headers @{ 'User-Agent' = 'kotofetch-windows' } -UseBasicParsing
            $names += $it.name
        }
    }
    # drop cached files that no longer exist upstream
    Get-ChildItem $cacheDir -Filter *.toml | Where-Object { $names -notcontains $_.Name } | Remove-Item -Force
    Set-Content -Path (Join-Path $cacheDir '.stamp') -Value (Get-Date).ToString('o')
}

function Test-CacheStale {
    $stamp = Join-Path $cacheDir '.stamp'
    if (-not (Test-Path $stamp)) { return $true }
    if (-not (Get-ChildItem $cacheDir -Filter *.toml)) { return $true }
    return ((Get-Date) - (Get-Item $stamp).LastWriteTime).TotalDays -gt 7
}

if (-not $Offline -and ($Refresh -or (Test-CacheStale))) {
    try { Update-QuoteCache }
    catch {
        if (-not (Get-ChildItem $cacheDir -Filter *.toml)) {
            Write-Error "Could not download quotes from GitHub and no cache exists: $($_.Exception.Message)"
            exit 1
        }
        Write-Warning "Could not refresh quotes ($($_.Exception.Message)); using cached copy."
    }
}

# ---------- tiny TOML reader for [[quote]] tables ----------
function ConvertFrom-TomlString([string]$s) {
    [regex]::Replace($s, '\\(u([0-9a-fA-F]{4})|.)', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        if ($m.Groups[2].Success) { return [string][char][Convert]::ToInt32($m.Groups[2].Value, 16) }
        switch ($m.Groups[1].Value) {
            'n' { "`n" } 't' { "`t" } 'r' { "`r" } '"' { '"' } '\' { '\' } default { $m.Groups[1].Value }
        }
    })
}

function Read-QuoteFile([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $list = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($raw in ($text -split "\r?\n")) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[\[\s*quote\s*\]\]') {
            if ($cur -and $cur.japanese) { $list.Add($cur) }
            $cur = @{}
            continue
        }
        if ($null -eq $cur) { continue }
        if ($line -match '^(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"') {
            $cur[$Matches[1]] = ConvertFrom-TomlString $Matches[2]
        } elseif ($line -match "^(\w+)\s*=\s*'([^']*)'") {
            $cur[$Matches[1]] = $Matches[2]
        }
    }
    if ($cur -and $cur.japanese) { $list.Add($cur) }
    return $list.ToArray()
}

# ---------- collect quote files ----------
$files = @()
$files += Get-ChildItem $cacheDir -Filter *.toml -ErrorAction SilentlyContinue
$files += Get-ChildItem $userDir  -Filter *.toml -ErrorAction SilentlyContinue

if ($ListModes) {
    $files | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } | Sort-Object -Unique
    exit 0
}

if ($Modes -and $Modes.Count -gt 0) {
    $wanted = $Modes | ForEach-Object { $_.ToLower().Trim() }
    $files = @($files | Where-Object { $wanted -contains [IO.Path]::GetFileNameWithoutExtension($_.Name).ToLower() })
    if ($files.Count -eq 0) {
        Write-Error "No quote files match -Modes. Use -ListModes to see what is available."
        exit 1
    }
}

$quotes = @()
foreach ($f in $files) {
    try { $quotes += Read-QuoteFile $f.FullName }
    catch { Write-Warning "Skipping $($f.Name): $($_.Exception.Message)" }
}
if ($quotes.Count -eq 0) { Write-Error 'No quotes found.'; exit 1 }

$rng = if ($Seed -ne 0) { New-Object System.Random $Seed } else { New-Object System.Random }
$q = $quotes[$rng.Next($quotes.Count)]

# ---------- text measuring ----------
function Get-CharWidth([int]$cp) {
    if (($cp -ge 0x1100 -and $cp -le 0x115F) -or ($cp -ge 0x2E80 -and $cp -le 0xA4CF) -or
        ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
        ($cp -ge 0xFE30 -and $cp -le 0xFE6F) -or ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or
        ($cp -ge 0xFFE0 -and $cp -le 0xFFE6)) { return 2 }
    return 1
}
function Get-DispWidth([string]$s) {
    $w = 0
    foreach ($ch in $s.ToCharArray()) { $w += Get-CharWidth ([int]$ch) }
    return $w
}

# ---------- colors ----------
function Get-AnsiCode([string]$c) {
    if (-not $c) { return '' }
    $c = $c.Trim().ToLower()
    if ($c -match '^#?([0-9a-f]{6})$') {
        $hex = $Matches[1]
        $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        return "38;2;$r;$g;$b"
    }
    $map = @{ black = 30; red = 31; green = 32; yellow = 33; blue = 34; magenta = 35; cyan = 36; white = 37
              gray = 90; grey = 90; dim = 2; none = '' }
    if ($map.ContainsKey($c)) { return [string]$map[$c] }
    return ''
}
function Format-Paint([string]$text, [string]$code, [bool]$bold = $false) {
    $codes = @()
    if ($bold) { $codes += '1' }
    if ($code) { $codes += $code }
    if ($codes.Count -eq 0 -or $text -eq '') { return $text }
    return "$ESC[$($codes -join ';')m$text$ESC[0m"
}
$qCode = Get-AnsiCode $QuoteColor
$tCode = Get-AnsiCode $TranslationColor
$bCode = Get-AnsiCode $BorderColor

# ---------- build content ----------
$consoleWidth = 80
try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {}
if (-not $consoleWidth -or $consoleWidth -lt 20) { $consoleWidth = 80 }

$maxInner = if ($Width -gt 0) { $Width } else { [Math]::Max(10, [Math]::Min(60, $consoleWidth - 2 - 2 * $HorizontalPadding - 2)) }

$modesSet = @($Translation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
$kanjiRx  = [regex]'([\u3400-\u4DBF\u4E00-\u9FFF\u3005\u3006\u30F6]+)\(([^)]*)\)'
$japanese = [string]$q.japanese

# Cells: one per char, or one per annotated kanji run when furigana is shown
$cells = New-Object System.Collections.Generic.List[object]
function Add-PlainCells([string]$s) {
    foreach ($ch in $s.ToCharArray()) {
        $cells.Add(@{ b = [string]$ch; r = ''; w = (Get-DispWidth ([string]$ch)) })
    }
}
$showFurigana = $modesSet -contains 'furigana'
if ($showFurigana) {
    $pos = 0
    foreach ($m in $kanjiRx.Matches($japanese)) {
        if ($m.Index -gt $pos) { Add-PlainCells $japanese.Substring($pos, $m.Index - $pos) }
        $b = $m.Groups[1].Value; $r = $m.Groups[2].Value
        $cells.Add(@{ b = $b; r = $r; w = [Math]::Max((Get-DispWidth $b), (Get-DispWidth $r)) })
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $japanese.Length) { Add-PlainCells $japanese.Substring($pos) }
} else {
    $plain = [regex]::Replace($japanese, '(?<=[\u3400-\u4DBF\u4E00-\u9FFF\u3005\u3006\u30F6])\([^)]*\)', '')
    Add-PlainCells $plain
}

function Format-CellCenter([string]$s, [int]$w) {
    $d = Get-DispWidth $s
    $left = [int][Math]::Floor(($w - $d) / 2)
    return (' ' * $left) + $s + (' ' * ($w - $d - $left))
}

# $lines: @{ t = text; w = display width; c = ansi code; b = bold }
$lines = New-Object System.Collections.Generic.List[object]

# wrap cells into rows
$rows = New-Object System.Collections.Generic.List[object]
$cur = New-Object System.Collections.Generic.List[object]; $curW = 0
foreach ($c in $cells) {
    if ($cur.Count -gt 0 -and ($curW + $c.w) -gt $maxInner) {
        $rows.Add($cur.ToArray()); $cur = New-Object System.Collections.Generic.List[object]; $curW = 0
    }
    $cur.Add($c); $curW += $c.w
}
if ($cur.Count -gt 0) { $rows.Add($cur.ToArray()) }

foreach ($row in $rows) {
    $base = ($row | ForEach-Object { Format-CellCenter $_.b $_.w }) -join ''
    $hasReading = [bool]($row | Where-Object { $_.r })
    $reading = if ($hasReading) { ($row | ForEach-Object { Format-CellCenter $_.r $_.w }) -join '' } else { '' }
    $bw = Get-DispWidth $base
    $rowLines = @()
    if ($hasReading -and $FuriganaPosition -eq 'above') {
        $lines.Add(@{ t = $reading; w = $bw; c = $tCode; b = $false })
    }
    $lines.Add(@{ t = $base; w = $bw; c = $qCode; b = (-not $NoBold) })
    if ($hasReading -and $FuriganaPosition -eq 'below') {
        $lines.Add(@{ t = $reading; w = $bw; c = $tCode; b = $false })
    }
}

function Split-WordWrap([string]$text, [int]$max) {
    $out = New-Object System.Collections.Generic.List[string]
    $line = ''
    foreach ($word in ($text -split '\s+' | Where-Object { $_ })) {
        $candidate = if ($line) { "$line $word" } else { $word }
        if ($line -and (Get-DispWidth $candidate) -gt $max) { $out.Add($line); $line = $word }
        else { $line = $candidate }
    }
    if ($line) { $out.Add($line) }
    return $out.ToArray()
}

$extra = @()
foreach ($mode in $modesSet) {
    if ($mode -eq 'english' -and $q.translation) { $extra += ,@($q.translation) }
    elseif ($mode -eq 'romaji' -and $q.romaji)   { $extra += ,@($q.romaji) }
}
foreach ($e in $extra) {
    $lines.Add(@{ t = ''; w = 0; c = ''; b = $false })
    foreach ($l in (Split-WordWrap $e[0] $maxInner)) {
        $lines.Add(@{ t = $l; w = (Get-DispWidth $l); c = $tCode; b = $false })
    }
}
if (-not $NoSource -and $q.source) {
    $src = '- ' + $q.source
    $lines.Add(@{ t = ''; w = 0; c = ''; b = $false })
    $lines.Add(@{ t = $src; w = (Get-DispWidth $src); c = $tCode; b = $false })
}

# ---------- render ----------
$inner = 0
foreach ($l in $lines) { if ($l.w -gt $inner) { $inner = $l.w } }
$boxW = $inner + 2 * $HorizontalPadding
$hp = ' ' * $HorizontalPadding

$hz = [string][char]0x2500
if ($Square) { $tl = [string][char]0x250C; $tr = [string][char]0x2510; $bl = [string][char]0x2514; $br = [string][char]0x2518 }
else { $tl = [string][char]0x256D; $tr = [string][char]0x256E; $bl = [string][char]0x2570; $br = [string][char]0x256F }
$vbar = Format-Paint ([string][char]0x2502) $bCode
$out = New-Object System.Collections.Generic.List[string]

function Add-Framed([string]$content) {
    if ($NoBorder) { $out.Add($content) } else { $out.Add("$vbar$content$vbar") }
}

if (-not $NoBorder) { $out.Add((Format-Paint ($tl + ($hz * $boxW) + $tr) $bCode)) }
for ($i = 0; $i -lt $VerticalPadding; $i++) { Add-Framed (' ' * $boxW) }
foreach ($l in $lines) {
    $padLeft = if ($Left) { 0 } else { [int][Math]::Floor(($inner - $l.w) / 2) }
    $padRight = $inner - $l.w - $padLeft
    $body = (' ' * $padLeft) + (Format-Paint $l.t $l.c $l.b) + (' ' * $padRight)
    Add-Framed ($hp + $body + $hp)
}
for ($i = 0; $i -lt $VerticalPadding; $i++) { Add-Framed (' ' * $boxW) }
if (-not $NoBorder) { $out.Add((Format-Paint ($bl + ($hz * $boxW) + $br) $bCode)) }

foreach ($o in $out) { [Console]::Out.WriteLine($o) }
