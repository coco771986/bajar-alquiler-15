# Plot rent at 15 percent

Lowers the rent tenants pay in Car Park Capital to 15 percent of the original value, or restores the game's original rent.

The game ships with 460 per tenant per day. Option 1 sets it to 69. Option 2 sets it back to 460. The land purchase price does not change.

## How to use it

1. Download `bajar-alquiler-15.bat`. The same script is also in `bajar-alquiler-15.txt`.
2. Double-click the file.
3. Choose 1 to lower the rent, or 2 to restore the original value.
4. Load City, Egypt, or Florida again.

It finds the game folder on its own, in Steam and on the local drives.

FULL .BAT:
@echo off
setlocal EnableExtensions
title Plot rent
set "MODE=%~1"
if /I "%MODE%"=="nopause" set "MODE="
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0'; $c=[IO.File]::ReadAllText($p); $k='###POWERSHELL'+'###'; $i=$c.IndexOf($k); if($i -lt 0){ Write-Output 'Missing PowerShell block'; exit 1 }; Invoke-Expression $c.Substring($i+$k.Length)"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Finished with error %RC%.
if /I "%~1"=="nopause" exit /b %RC%
if /I "%~2"=="nopause" exit /b %RC%
pause
exit /b %RC%

###POWERSHELL###
$ErrorActionPreference = 'Stop'

# 460 is the game's original rent. 69 is 15 percent.
$Stock = 'dailyRentPerTenant = 460'
$Reduced = 'dailyRentPerTenant = 69'

$RelFiles = @(
  'houses\Apartments0.lua',
  'houses\Apartments1.lua',
  'houses\Apartments2.lua',
  'houses\House0.lua',
  'houses\PaintedLady.lua',
  'houses\PaintedLadyCorner.lua',
  'egypt\EgyptApartments0.lua',
  'egypt\EgyptApartments1.lua',
  'egypt\EgyptApartments2.lua',
  'egypt\EgyptApartments3.lua',
  'florida\FloridaApartments0.lua',
  'florida\FloridaApartments1.lua',
  'florida\FloridaApartments2.lua',
  'florida\FloridaApartments3.lua',
  'florida\FloridaApartments4.lua'
)

function Test-Game([string]$Folder) {
  if ([string]::IsNullOrWhiteSpace($Folder)) { return $false }
  $house = Join-Path $Folder 'assets\scripts\entities\simulation\placeables\houses\House0.lua'
  return (Test-Path -LiteralPath $house)
}

function Add-Unique([System.Collections.Generic.List[string]]$List, [string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  $clean = ($Path -replace '/', '\').TrimEnd('\')
  foreach ($existing in $List) {
    if ($existing -eq $clean) { return }
  }
  $List.Add($clean)
}

function Add-LibrariesFromSteam([System.Collections.Generic.List[string]]$List, [string]$SteamRoot) {
  if ([string]::IsNullOrWhiteSpace($SteamRoot)) { return }
  $SteamRoot = ($SteamRoot -replace '/', '\').TrimEnd('\')
  Add-Unique $List $SteamRoot
  $vdf = Join-Path $SteamRoot 'steamapps\libraryfolders.vdf'
  if (-not (Test-Path -LiteralPath $vdf)) { return }
  $text = [IO.File]::ReadAllText($vdf)
  $found = [regex]::Matches($text, '"path"\s+"([^"]+)"')
  foreach ($item in $found) {
    Add-Unique $List ($item.Groups[1].Value -replace '\\\\', '\')
  }
}

function Get-LibraryPaths {
  $paths = New-Object System.Collections.Generic.List[string]
  foreach ($key in @(
    'HKCU:\Software\Valve\Steam',
    'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
    'HKLM:\SOFTWARE\Valve\Steam'
  )) {
    try {
      $item = Get-ItemProperty -Path $key -ErrorAction Stop
    } catch {
      continue
    }
    if ($item.SteamPath) { Add-LibrariesFromSteam $paths $item.SteamPath }
    if ($item.InstallPath) { Add-LibrariesFromSteam $paths $item.InstallPath }
  }
  $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
  foreach ($disk in $disks) {
    $root = $disk.DeviceID + '\'
    foreach ($tail in @(
      'SteamLibrary',
      'Steam',
      'Games',
      'Games\Steam',
      'Program Files (x86)\Steam',
      'Program Files\Steam'
    )) {
      $folder = Join-Path $root $tail
      if (Test-Path -LiteralPath $folder) {
        Add-LibrariesFromSteam $paths $folder
      }
    }
  }
  return $paths
}

$mode = $env:MODE
if ([string]::IsNullOrWhiteSpace($mode)) {
  Write-Output '1. Lower tenant rent to 15 percent (69 per tenant)'
  Write-Output '2. Restore the original game value (460 per tenant)'
  $mode = Read-Host 'Choose 1 or 2'
}
$mode = "$mode".Trim().ToLowerInvariant()

if ($mode -eq '2' -or $mode -eq 'restore' -or $mode -eq 'revert' -or $mode -eq 'original') {
  $Old = $Reduced
  $New = $Stock
  $label = 'original value (460)'
} elseif ($mode -eq '1' -or $mode -eq 'apply' -or $mode -eq 'lower') {
  $Old = $Stock
  $New = $Reduced
  $label = '15 percent (69)'
} else {
  Write-Output 'Invalid choice. Use 1 to lower rent or 2 to restore the original.'
  exit 1
}

Write-Output 'Searching for Car Park Capital...'
$Game = $null
foreach ($lib in (Get-LibraryPaths)) {
  $candidate = Join-Path $lib 'steamapps\common\Car Park Capital'
  if (Test-Game $candidate) {
    $Game = $candidate
    break
  }
}

if (-not $Game) {
  Write-Output 'Car Park Capital was not found in Steam or on the local drives.'
  exit 1
}

Write-Output ('Game: ' + $Game)
Write-Output ('Action: ' + $label)
Write-Output ''

$base = Join-Path $Game 'assets\scripts\entities\simulation\placeables'
$enc = New-Object System.Text.UTF8Encoding $false
$changed = 0
$already = 0
$problems = 0

foreach ($rel in $RelFiles) {
  $path = Join-Path $base $rel
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Output ('MISSING  ' + $rel)
    $problems++
    continue
  }
  $text = [IO.File]::ReadAllText($path)
  $oldCount = ([regex]::Matches($text, [regex]::Escape($Old))).Count
  $newCount = ([regex]::Matches($text, [regex]::Escape($New))).Count
  if ($oldCount -eq 1) {
    $updated = $text.Replace($Old, $New)
    [IO.File]::WriteAllText($path, $updated, $enc)
    Write-Output ('OK       ' + $rel)
    $changed++
  } elseif ($oldCount -eq 0 -and $newCount -ge 1) {
    Write-Output ('ALREADY  ' + $rel)
    $already++
  } else {
    Write-Output ('UNEXPECTED  ' + $rel + '  (source=' + $oldCount + ', target=' + $newCount + ')')
    $problems++
  }
}

Write-Output ''
Write-Output ('Changed: ' + $changed)
Write-Output ('Already set: ' + $already)
Write-Output ('Problems: ' + $problems)
Write-Output 'The land purchase price is unchanged.'
if ($problems -gt 0) { exit 1 }
exit 0

