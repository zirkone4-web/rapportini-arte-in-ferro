$ErrorActionPreference = 'Stop'

$packageRoot = $PSScriptRoot
$repoRoot = $packageRoot
if (-not (Test-Path (Join-Path $repoRoot 'apps\mobile\pubspec.yaml'))) {
    $parent = Split-Path -Parent $packageRoot
    if (Test-Path (Join-Path $parent 'apps\mobile\pubspec.yaml')) {
        $repoRoot = $parent
    } else {
        throw 'Put this correction folder inside rapportini-arte-in-ferro and run it again.'
    }
}

$targets = @(
    'apps\mobile\pubspec.yaml',
    'apps\mobile\lib\core\config\app_config.dart',
    'apps\mobile\lib\core\updates\app_update_service.dart',
    'apps\mobile\lib\features\rapportini\data\repositories\offline_rapportini_repository.dart',
    'apps\mobile\test\core\config\app_config_test.dart',
    'apps\pwa\app.js',
    'apps\pwa\sw.js',
    'apps\windows\ArteInFerro.Rapportini.Desktop\App.xaml.cs',
    'apps\windows\ArteInFerro.Rapportini.Desktop\ArteInFerro.Rapportini.Desktop.csproj',
    'apps\windows\ArteInFerro.Rapportini.Desktop\Models\AppSession.cs',
    'apps\windows\ArteInFerro.Rapportini.Desktop\Services\SupabaseAuthService.cs',
    'apps\windows\ArteInFerro.Rapportini.Desktop\Services\SupabaseSessionHandler.cs',
    '.github\workflows\build-installers-corretto.yml',
    'RELEASE_0_6_1.txt'
)

$cp1252Reverse = @{
    0x20AC = 0x80; 0x201A = 0x82; 0x0192 = 0x83; 0x201E = 0x84;
    0x2026 = 0x85; 0x2020 = 0x86; 0x2021 = 0x87; 0x02C6 = 0x88;
    0x2030 = 0x89; 0x0160 = 0x8A; 0x2039 = 0x8B; 0x0152 = 0x8C;
    0x017D = 0x8E; 0x2018 = 0x91; 0x2019 = 0x92; 0x201C = 0x93;
    0x201D = 0x94; 0x2022 = 0x95; 0x2013 = 0x96; 0x2014 = 0x97;
    0x02DC = 0x98; 0x2122 = 0x99; 0x0161 = 0x9A; 0x203A = 0x9B;
    0x0153 = 0x9C; 0x017E = 0x9E; 0x0178 = 0x9F
}

function Convert-MojibakeToUtf8([string]$Text) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($character in $Text.ToCharArray()) {
        $code = [int][char]$character
        if ($code -le 0xFF) {
            $bytes.Add([byte]$code)
        } elseif ($cp1252Reverse.ContainsKey($code)) {
            $bytes.Add([byte]$cp1252Reverse[$code])
        } else {
            throw "Unexpected character U+$($code.ToString('X4')) while repairing encoding."
        }
    }
    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    return $utf8Strict.GetString($bytes.ToArray())
}

$desktop = [Environment]::GetFolderPath('Desktop')
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $desktop "Backup-Codifica-Arte-In-Ferro-$timestamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($relative in $targets) {
    $path = Join-Path $repoRoot $relative
    if (-not (Test-Path $path)) { continue }

    $backupPath = Join-Path $backupRoot $relative
    $backupDirectory = Split-Path -Parent $backupPath
    if ($backupDirectory) {
        New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
    }
    Copy-Item -Force $path $backupPath

    $currentText = $utf8Strict.GetString([System.IO.File]::ReadAllBytes($path))
    $fixedText = Convert-MojibakeToUtf8 $currentText
    [System.IO.File]::WriteAllText($path, $fixedText, $utf8NoBom)
}

$badMarkers = @([char]0x00C3, [char]0x00C2, [char]0x00E2, [char]0xFFFD)
$remaining = @()
foreach ($relative in $targets) {
    $path = Join-Path $repoRoot $relative
    if (-not (Test-Path $path)) { continue }
    $text = [System.IO.File]::ReadAllText($path, $utf8Strict)
    foreach ($marker in $badMarkers) {
        if ($text.Contains([string]$marker)) {
            $remaining += $relative
            break
        }
    }
}

if ($remaining.Count -gt 0) {
    Write-Host ''
    Write-Host 'Some suspicious encoding markers remain in:' -ForegroundColor Yellow
    $remaining | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
    Write-Host 'Do not commit yet. Send a photo of this window.' -ForegroundColor Yellow
    exit 2
}

Write-Host ''
Write-Host 'ENCODING CORRECTION COMPLETED.' -ForegroundColor Green
Write-Host "Backup saved on Desktop: $backupRoot"
Write-Host 'Return to GitHub Desktop and refresh Changes.'
Write-Host ''
