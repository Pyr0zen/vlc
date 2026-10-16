# Authoring helper: starts the test player on the verify clip, sizes it like the scenarios do,
# runs optional steps, writes the UI Automation tree (accessible names, roles, rectangles) and a
# screenshot of the player window into a new folder under outRoot, then quits the player.
#   powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1 [-Build public|vlc]
#       [-Steps <JSON file or text with an array of steps>] [-PlayerArgs '<extra player args>'] [-Media <file>,<file>]
param([string]$Build = 'public', [string]$Steps = '[]', [string]$PlayerArgs = '', [string[]]$Media = @(),
      [double]$Width = 1920, [double]$Height = 1080)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'driver.ps1')
. (Join-Path $here 'steps.ps1')
. (Join-Path $here 'config.ps1')
$cfg = Get-VerifyConfig
$exe = Join-Path $cfg.testMediaDir $cfg.builds.$Build
$out = Join-Path $cfg.outRoot ('probe-' + (Get-Date -Format 'yyyyMMdd-HHmmss')); New-Item -ItemType Directory -Force $out | Out-Null
$foreign = Get-ForeignTestPlayers (Join-Path $cfg.testMediaDir 'builds') $cfg.ignorePids
if ($foreign) { throw "another test player is running (pid $($foreign.Id -join ', ')); wait for it to close" }
if (-not $Media) { $Media = @(Join-Path $cfg.testMediaDir 'builds\test-media\verify\Videos\Verify Clip.mkv') }
if (Test-Path -LiteralPath $Steps) { $Steps = Get-Content -Raw -LiteralPath $Steps }
$stepList = @((ConvertFrom-Json $Steps) | ForEach-Object { $_ })
try {
    $a = @('--no-one-instance', '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-video-title-show')
    if ($Build -eq 'vlc') { $a += '--no-qt-updates-notif' }   # Cone builds have no update checker
    if ($PlayerArgs) { $a += $PlayerArgs.Split(' ') }
    foreach ($mf in $Media) { $a += "`"$mf`"" }
    $m = Start-Player $exe $a
    Start-Sleep -Seconds 2
    $m = Set-PlayerSize $Width $Height
    $c = Get-ClientRect $m.Handle
    "main window: '$($m.Title)' client $($c.Left),$($c.Top) $($c.Width)x$($c.Height) scale $(Get-Scale $m.Handle)"
    Invoke-FocusPlayer $m.Handle | Out-Null
    $ctx = New-StepContext $out 'probe'
    foreach ($s in $stepList) { Invoke-Step $s $ctx }
    $s = Save-WindowShot $m.Handle (Join-Path $out 'window.png') -Client; "shot: $($s.Method) $($s.Width)x$($s.Height)"
    Get-UiaTree | Set-Content -Encoding utf8 (Join-Path $out 'uia.txt')
    Get-PlayerWindows | Format-Table -AutoSize | Out-String -Width 250 | Set-Content -Encoding utf8 (Join-Path $out 'windows.txt')
    $ctx.Notes; $ctx.Checks | ForEach-Object { "$($_.check): $($_.pass) $($_.detail)" }
} finally {
    try { Restore-PlayerVolume } catch {}
    "quit: $(Stop-Players)"
}
"output: $out"
