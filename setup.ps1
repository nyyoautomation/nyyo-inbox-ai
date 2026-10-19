# Nyyo inbox -> CRM kit - sort your messages with AI into a Sheet-ready table (Windows).
# Free 1-click install kit, MIT licence. Nyyo Automation.
#
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1            first run: settings, .env, samples, dry run
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Check     check settings and keys, process nothing
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Live      really send (only what your settings switch on)
#
# Options: -Reprocess, -NoOpen. Safe to run again (see INSTALL.md).
param([switch]$Live, [switch]$Check, [switch]$Reprocess, [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 3 }

if (-not (Test-Path (Join-Path $KitDir 'kit/nyyo_crm.py'))) { Die 'Kit files missing: run this script from the unzipped kit folder.' }
Set-Location $KitDir

# 1. Python 3.9+ (standard library only)
$Py = $null; $PyArgs = @()
foreach ($c in @(@('py', '-3'), @('python3'), @('python'))) {
  $cmd = Get-Command $c[0] -ErrorAction SilentlyContinue
  if (-not $cmd) { continue }
  $extra = @($c | Select-Object -Skip 1)
  & $cmd.Source @extra -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>$null
  if ($LASTEXITCODE -eq 0) { $Py = $cmd.Source; $PyArgs = $extra; break }
}
if (-not $Py) { Die 'Python 3.9 or newer is needed. See INSTALL.md, Step 1 (Windows).' }

# 2. Your files (created once, never overwritten)
if (-not (Test-Path 'config/settings.ini')) {
  Copy-Item 'config/settings.example.ini' 'config/settings.ini'
  Say 'Created config/settings.ini (AI: built-in rules, nothing switched on). Edit it later, then run setup again.'
}
if (-not (Test-Path '.env')) {
  Copy-Item '.env.example' '.env'
  if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    try { & icacls .env /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null } catch { }
  } else { & chmod 600 .env }
  Say 'Created .env for your keys (private to you). Fill it only when you switch something on.'
}
if (-not (Test-Path 'inbox')) {
  New-Item -ItemType Directory 'inbox' | Out-Null
  Copy-Item 'samples/inbox/*' 'inbox/'
  Say 'Created inbox/ with 8 made-up sample messages. Replace them with your own .eml or .txt files.'
}

# 3. Run
$pass = @('--config', 'config/settings.ini', '--env', '.env')
if ($Live) { $pass += '--live' }; if ($Check) { $pass += '--check' }; if ($Reprocess) { $pass += '--reprocess' }
$ErrorActionPreference = 'Continue'
& $Py @PyArgs 'kit/nyyo_crm.py' @pass
$rc = $LASTEXITCODE
Write-Host ''
switch ($rc) {
  0 { Say "Finished. Your table: $KitDir\output\leads.csv" }
  1 { Warn "Finished with warnings (see [!] lines above). Your table: $KitDir\output\leads.csv" }
  3 { Warn 'Fix config/settings.ini or .env (see the message above) and run setup again.' }
  4 { Warn 'A key was refused: check it in .env (INSTALL.md, Troubleshooting).' }
  default { Warn "The kit stopped with an error (code $rc). See INSTALL.md, Troubleshooting." }
}
if (-not $NoOpen -and $rc -le 1 -and [Environment]::UserInteractive -and ($IsWindows -or $env:OS -eq 'Windows_NT')) {
  Start-Process explorer.exe (Join-Path $KitDir 'output')
}
exit $rc
