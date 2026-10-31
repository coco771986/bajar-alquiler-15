@echo off
setlocal EnableExtensions
title Alquiler de parcelas al 15 por ciento
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0'; $c=[IO.File]::ReadAllText($p); $k='###POWERSHELL'+'###'; $i=$c.IndexOf($k); if($i -lt 0){ Write-Output 'Falta el bloque de PowerShell'; exit 1 }; Invoke-Expression $c.Substring($i+$k.Length)"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Termino con error %RC%.
if /I "%~1"=="nopause" exit /b %RC%
pause
exit /b %RC%

###POWERSHELL###
$ErrorActionPreference = 'Stop'

# Alquiler diario por inquilino. El juego trae 460. 69 es el 15 por ciento.
$Old = 'dailyRentPerTenant = 460'
$New = 'dailyRentPerTenant = 69'

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

Write-Output 'Buscando Car Park Capital...'
$Game = $null
foreach ($lib in (Get-LibraryPaths)) {
  $candidate = Join-Path $lib 'steamapps\common\Car Park Capital'
  if (Test-Game $candidate) {
    $Game = $candidate
    break
  }
}

if (-not $Game) {
  Write-Output 'No encontre Car Park Capital en Steam ni en los discos locales.'
  exit 1
}

Write-Output ('Juego: ' + $Game)
Write-Output ''

$base = Join-Path $Game 'assets\scripts\entities\simulation\placeables'
$enc = New-Object System.Text.UTF8Encoding $false
$changed = 0
$already = 0
$problems = 0

foreach ($rel in $RelFiles) {
  $path = Join-Path $base $rel
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Output ('FALTA  ' + $rel)
    $problems++
    continue
  }
  $text = [IO.File]::ReadAllText($path)
  $oldCount = ([regex]::Matches($text, [regex]::Escape($Old))).Count
  $newCount = ([regex]::Matches($text, [regex]::Escape($New))).Count
  if ($oldCount -eq 1) {
    $updated = $text.Replace($Old, $New)
    [IO.File]::WriteAllText($path, $updated, $enc)
    Write-Output ('OK     ' + $rel)
    $changed++
  } elseif ($oldCount -eq 0 -and $newCount -ge 1) {
    Write-Output ('YA     ' + $rel)
    $already++
  } else {
    Write-Output ('RARO   ' + $rel + '  (460=' + $oldCount + ', 69=' + $newCount + ')')
    $problems++
  }
}

Write-Output ''
Write-Output ('Cambiados: ' + $changed)
Write-Output ('Ya estaban en 69: ' + $already)
Write-Output ('Problemas: ' + $problems)
Write-Output 'El precio de compra del terreno no cambia.'
if ($problems -gt 0) { exit 1 }
exit 0
