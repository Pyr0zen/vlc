# Verification harness runner: drives the test build through the scenario table, screenshots the
# player window, then compare.py diffs the shots against the Figma frames and writes the report.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1 [options]
#     -Build public|vlc        which build of the config to run (builds.public / builds.vlc)
#     -Only P2-03,IB-08,...    only scenarios covering these VIDEO_INDEX row IDs (or scenario ids)
#     -Area player             only scenario files whose "area" matches
#     -Lanes 3                 run the sessions marked "lane": "uia" in up to 3 parallel UIA lanes
#                              (own build copy and profile each, no keyboard / mouse input, window
#                              off screen); the other sessions run meanwhile in the one manual lane
#     -ExitRetest 10 -RetestSession sidebar
#                              repeat one session N times (manual lane) and count stuck exits,
#                              quitting half with Ctrl+Q and half with WM_CLOSE
#     -LanesOnly               with -Lanes: only the UIA lane sessions (e.g. while the manual lane is busy)
#     -DryRun                  print the plan and validate the Figma nodes; starts nothing, sends nothing
#     -NoCompare               run and screenshot only (compare later: python compare.py <run dir>)
#     -Label <text>            appended to the run folder name
#   (internal) -Worker -LaneNo k -RunDir <dir> -Sessions <ids>: one UIA lane, started by the runner
# See README.md for the scenario format, the lanes and the safety rules.
param([string]$Build = 'public', [string]$Only = '', [string]$Area = '', [switch]$DryRun, [switch]$NoCompare,
      [string]$Label = '', [string[]]$Files = @(), [int]$WaitForOthersMin = 30, [int]$Lanes = 0,
      [switch]$Worker, [int]$LaneNo = 0, [string]$RunDir = '', [string]$Sessions = '',
      [int]$ExitRetest = 0, [string]$RetestSession = '', [string]$BuildExe = '', [switch]$LanesOnly)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'driver.ps1')
. (Join-Path $here 'steps.ps1')
. (Join-Path $here 'config.ps1')
$cfg = Get-VerifyConfig
$t0 = Get-Date

# --- scenario table ------------------------------------------------------------------------
if (-not $Files -or $Files.Count -eq 0) { $Files = @(Get-ChildItem (Join-Path $here 'scenarios') -Filter *.json | Sort-Object Name | ForEach-Object FullName) }
$onlySet = @($Only.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$sessionSet = @($Sessions.Split(',') + @($RetestSession) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$plan = New-Object System.Collections.ArrayList
foreach ($f in $Files) {
    $data = Get-Content -Raw -Encoding UTF8 $f | ConvertFrom-Json
    if ($Area -and $data.area -ne $Area) { continue }
    foreach ($se in $data.sessions) {
        if ($sessionSet.Count -and -not ($sessionSet -contains $se.id)) { continue }
        $sel = @($se.scenarios | Where-Object {
            $sc = $_
            (-not $onlySet) -or ($onlySet -contains $sc.id) -or (@($sc.rows | Where-Object { $onlySet -contains $_ }).Count -gt 0) -or
            (@($sc.compare | ForEach-Object { $_.rows } | Where-Object { $_ -and ($onlySet -contains $_) }).Count -gt 0) })
        if ($sel.Count -gt 0) {
            $isUia = ($se.PSObject.Properties['lane'] -and $se.lane -eq 'uia')
            [void]$plan.Add([pscustomobject]@{ File = (Split-Path $f -Leaf); Area = $data.area; Session = $se; Scenarios = $sel; Uia = $isUia })
        }
    }
}
$nScen = ($plan | ForEach-Object { $_.Scenarios.Count } | Measure-Object -Sum).Sum
if (-not $Worker) { "plan: $($plan.Count) session(s), $nScen scenario(s), build '$Build'" + $(if ($Lanes) { ", $(@($plan | Where-Object Uia).Count) session(s) for $Lanes UIA lane(s)" } else { '' }) }

$exePath = [string]$cfg.builds.$Build
$exe = if ([IO.Path]::IsPathRooted($exePath)) { $exePath } else { Join-Path $cfg.testMediaDir $exePath }
if ($BuildExe) { $exe = $BuildExe }
# a UIA lane runs its own copy of the build (path handed over by the runner)
if ($Worker -and $env:VERIFY_LANE_EXE) { $exe = $env:VERIFY_LANE_EXE }
$script:PublicBuild = ($Build -eq 'public')
# demo state: values the Figma screens show (subtitle delay -4 s, toggles, colours), set per
# session in a run-specific copy of the test profile (vlcrc) or through the UI (per-media values)
$demoFile = Join-Path $here 'demo_state.json'
$script:Demo = if (Test-Path $demoFile) { Get-Content -Raw -Encoding UTF8 $demoFile | ConvertFrom-Json } else { $null }
$mediaRoot = Join-Path $cfg.testMediaDir 'builds\test-media\verify'
# --no-one-instance: the started process never hands its media to another running player
# --no-qt-updates-notif only for vlc.exe: the Cone builds have no update checker and refuse to
# start with an unknown option
$baseArgs = @('--no-one-instance', '--no-qt-privacy-ask', '--no-qt-video-autoresize', '--no-video-title-show')
if ($Build -eq 'vlc') { $baseArgs += '--no-qt-updates-notif' }

if ($DryRun) {
    foreach ($p in $plan) {
        $se = $p.Session
        "session $($se.id) [$($p.File)]$(if ($p.Uia) { ' (UIA lane)' }): media $(@($se.media) -join ', '); args $(@($se.args) -join ' ')"
        $ctx = New-StepContext '' 'dry' -DryRun
        foreach ($s in @($se.setup)) { if ($s) { Invoke-Step $s $ctx } }
        foreach ($sc in $p.Scenarios) {
            "  scenario $($sc.id) rows $(@($sc.rows) -join ','): $($sc.title)"
            foreach ($s in @($se.reset) + @($sc.steps)) { if ($s) { Invoke-Step $s $ctx } }
            foreach ($c in @($sc.compare)) { if ($c) { "    compare $($c.id): shot $($c.shot) node $($c.node) ref $($c.ref) anchor $($c.anchor)" } }
        }
    }
    if (-not (Test-Path -LiteralPath $exe)) { "WARNING: player not found: $exe" }
    foreach ($p in $plan) { foreach ($m in @($p.Session.media)) { if ($m -and -not (Test-Path -LiteralPath (Join-Path $mediaRoot $m))) { "WARNING: media missing: $m (run make_media.py)" } } }
    & python (Join-Path $here 'compare.py') --validate @($plan | ForEach-Object { Join-Path (Join-Path $here 'scenarios') $_.File } | Select-Object -Unique)
    $valid = $LASTEXITCODE
    "dry run: nothing started, no input sent"
    exit $valid
}

# --- run folder, log ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $exe)) { throw "player not found: $exe" }
if ($Worker) {
    $runName = Split-Path $RunDir -Leaf
    $logFile = Join-Path $RunDir "lane$LaneNo.log"
    # (driver.ps1 has its own $script:Lane: the parameter has another name)
    $script:NoInput = $true; $script:Lane = $LaneNo
    if ($LaneNo -lt 1) { throw "a UIA lane needs -LaneNo 1..n (its window goes off screen)" }
} else {
    $runName = (Get-Date -Format 'yyyyMMdd-HHmmss') + $(if ($Label) { "-$Label" } else { '' })
    $RunDir = Join-Path $cfg.outRoot $runName
    New-Item -ItemType Directory -Force $RunDir | Out-Null
    $logFile = Join-Path $RunDir 'run.log'
}
$script:Log = { param($m) Write-Host $m; Add-Content -LiteralPath $logFile -Value $m -Encoding utf8 }
$buildId = ''
$br = Join-Path (Split-Path $exe) 'build-run.txt'; if (Test-Path $br) { $buildId = (Get-Content $br -Raw).Trim() }
$buildNum = if ($exe -match '\\builds\\(\d{6,})\\') { $Matches[1] } else { '' }
if ($buildNum) { $buildId = "run $buildNum" + $(if ($buildId) { " ($buildId)" } else { '' }) }
if (-not $Worker) { Write-VLog "run $runName, build '$Build' ($buildId), $nScen scenario(s)" }

# another test player (the main session's manual test) must not be running: only the manual lane
# waits for it (UIA lanes take no input and sit off screen)
$ignore = @($cfg.ignorePids | ForEach-Object { [int]$_ })
$laneDirs = @()
function Wait-ForOtherPlayers {
    $waitEnd = (Get-Date).AddMinutes($WaitForOthersMin)
    while ($true) {
        $foreign = @(Get-ForeignTestPlayers (Join-Path $cfg.testMediaDir 'builds') $ignore | Where-Object {
            $pp = $null; try { $pp = $_.Path } catch {}
            -not ($laneDirs | Where-Object { $pp -and $pp.StartsWith($_ + [char]92, [StringComparison]::OrdinalIgnoreCase) }) })
        if (-not $foreign) { return }
        if ((Get-Date) -gt $waitEnd) { throw "another test player is still running (pid $($foreign.Id -join ', ')); not started" }
        Write-VLog "  waiting: another test player is running (pid $($foreign.Id -join ', '))"
        Start-Sleep -Seconds 15
    }
}

# --- profiles ----------------------------------------------------------------------------------
# run-specific profile: a snapshot of the profile source (never edited in place), mirrored into the
# player's portable folder before every session and then given the overrides and demo values
$profileSource = if ($cfg.PSObject.Properties['profileSource'] -and $cfg.profileSource) {
    if ([IO.Path]::IsPathRooted([string]$cfg.profileSource)) { [string]$cfg.profileSource } else { Join-Path $cfg.testMediaDir ([string]$cfg.profileSource) } } else { $null }
$profileBase = if ($profileSource) { Join-Path $RunDir 'profile-base' } else { $null }
function Assert-ProfileTarget([string]$target) {
    if ($target -like (Join-Path $cfg.testMediaDir 'builds\current*')) { throw "refusing to overwrite the profile of a fixed test folder: $target" }
    if ($profileSource -and [string]::Equals($target.TrimEnd([char]92), $profileSource.TrimEnd([char]92), [StringComparison]::OrdinalIgnoreCase)) { throw "profileSource and the player's portable folder are the same" }
}
if ($profileSource -and -not $Worker) {
    robocopy $profileSource $profileBase /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "copying the profile source failed ($LASTEXITCODE)" }
    Write-VLog "profile: snapshot of the profile source in profile-base; each session starts from it"
}
function Set-VlcrcLine([string]$text, [string]$key, [string]$value) {
    $k = [regex]::Escape($key); $line = "$key=$value"
    if ($text -match "(?m)^#?$k=.*$") { return [regex]::Replace($text, "(?m)^#?$k=.*$", $line.Replace('$', '$$'), 1) }
    return $text + "`n$line`n"
}
function Initialize-Profile($se, [string]$target) {
    $applied = @()
    if (-not $profileBase) { return $applied }
    Assert-ProfileTarget $target
    robocopy $profileBase $target /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "preparing the run profile failed ($LASTEXITCODE)" }
    $vlcrc = Join-Path $target 'vlcrc'
    if (-not (Test-Path $vlcrc)) { return $applied }
    $text = [IO.File]::ReadAllText($vlcrc)
    # harness overrides (config "profileOverrides"): qt-cast-discovery=0, so no listening socket and
    # no Windows Firewall prompt for a new build path; UIA lanes add "laneOverrides"
    # (qt-pin-controls=1: the bars stay up without mouse movement, so their buttons can be invoked)
    $ov = @()
    if ($cfg.PSObject.Properties['profileOverrides'] -and $cfg.profileOverrides) { $ov += @($cfg.profileOverrides.PSObject.Properties) }
    if ($script:NoInput -and $cfg.PSObject.Properties['laneOverrides'] -and $cfg.laneOverrides) { $ov += @($cfg.laneOverrides.PSObject.Properties) }
    foreach ($p in $ov) { $text = Set-VlcrcLine $text $p.Name ([string]$p.Value); $applied += "harness: $($p.Name)=$($p.Value)" }
    if ($se.PSObject.Properties['vlcrc'] -and $se.vlcrc) {
        foreach ($p in $se.vlcrc.PSObject.Properties) { $text = Set-VlcrcLine $text $p.Name ([string]$p.Value); $applied += "session: $($p.Name)=$($p.Value)" }
    }
    if ($se.PSObject.Properties['demo'] -and -not $script:Demo) { $applied += "demo values NOT applied: demo_state.json not loaded" }
    if ($script:Demo -and $se.PSObject.Properties['demo']) {
        foreach ($sid in @($se.demo)) {
            $scr = $script:Demo.screens.$sid
            if (-not $scr) { continue }
            foreach ($v in @($scr.values)) {
                if ($v.how -ne 'vlcrc' -or -not $v.option) { continue }
                $pairs = @(, @([string]$v.option, [string]$v.value))
                if ($v.PSObject.Properties['extra']) { foreach ($x in @($v.extra)) { $pairs += ,@([string]$x.option, [string]$x.value) } }
                foreach ($pv in $pairs) { $text = Set-VlcrcLine $text $pv[0] $pv[1] }
                $applied += "${sid}: $($v.label) = $($v.figma) (vlcrc $(($pairs | ForEach-Object { "$($_[0])=$($_[1])" }) -join ', '))"
            }
        }
    }
    [IO.File]::WriteAllText($vlcrc, $text, (New-Object System.Text.UTF8Encoding $false))
    # the redesign's per-show presets (rd-presets.json) put their values back at every file open,
    # so the demo values also go into the current preset ("option:<key>", stereo mode, pitch, filters)
    $pj = Join-Path $target 'rd-presets.json'
    if ($script:Demo -and $se.PSObject.Properties['demo'] -and (Test-Path $pj)) {
        $pre = Get-Content -Raw -Encoding UTF8 $pj | ConvertFrom-Json
        $cur = @($pre.presets | Where-Object { $_.id -eq $pre.current })[0]
        if ($cur) {
            foreach ($sid in @($se.demo)) {
                foreach ($v in @($script:Demo.screens.$sid.values)) {
                    if ($v.how -ne 'vlcrc' -or -not $v.option) { continue }
                    $pairs = @(, @([string]$v.option, [string]$v.value))
                    if ($v.PSObject.Properties['extra']) { foreach ($x in @($v.extra)) { $pairs += ,@([string]$x.option, [string]$x.value) } }
                    foreach ($pv in $pairs) {
                        $key = $null; $val = $null
                        if ($pv[0] -eq 'stereo-mode') { $key = 'choice:stereo-mode'; $val = [string]$v.figma }
                        elseif ($pv[0] -eq 'pitch-shift') { $key = 'audio:pitch-shift'; $val = [double]$pv[1] }
                        elseif ($pv[0] -eq 'audio-filter') { foreach ($fl in ([string]$pv[1]).Split(':')) { if ($cur.values.PSObject.Properties["audioFilter:$fl"]) { $cur.values."audioFilter:$fl" = $true; $applied += "${sid}: preset audioFilter:$fl = true" } }; continue }
                        elseif ($cur.values.PSObject.Properties["option:$($pv[0])"]) {
                            $key = "option:$($pv[0])"; $old = $cur.values.$key
                            $val = if ($old -is [bool]) { $pv[1] -eq '1' } elseif ($old -is [int] -or $old -is [long] -or $old -is [double]) { [double]$pv[1] } else { [string]$pv[1] }
                        }
                        if ($key -and $cur.values.PSObject.Properties[$key]) { $cur.values.$key = $val; $applied += "${sid}: preset $key = $val" }
                    }
                }
            }
            [IO.File]::WriteAllText($pj, ($pre | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding $false))
        }
    }
    return $applied
}

# --- one session ---------------------------------------------------------------------------
# returns @{ results; cleanup; demo; seconds; lost; aborted }. lost = the player disappeared or
# lost its window during the session (e.g. closed by hand): the caller discards it and retries
function Invoke-Session($p, [string]$sessionExe, [string]$profileTarget, [string]$quit = 'keys') {
    $se = $p.Session
    $out = @{ results = New-Object System.Collections.ArrayList; cleanup = ''; demo = @(); seconds = 0; lost = $null; aborted = $null; stuck = $false }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-VLog "session $($se.id)$(if ($script:NoInput) { " (lane $script:Lane)" })"
    $a = @($baseArgs) + @($se.args | Where-Object { $_ } | ForEach-Object { $x = ([string]$_).Replace('{media}', $mediaRoot); if ($x -match '^(--[^=]+=)(.* .*)$') { $Matches[1] + '"' + $Matches[2] + '"' } else { $x } })
    foreach ($m in @($se.media)) { if ($m) { $a += ('"{0}"' -f (Join-Path $mediaRoot $m)) } }
    $sessionError = $null; $setupChecks = @()
    $proc = $null
    try {
        if (-not $script:NoInput) { Wait-ForOtherPlayers }
        $out.demo = @(Initialize-Profile $se $profileTarget)
        foreach ($x in $out.demo) { Write-VLog "  demo: $x" }
        $quick = [bool]($se.PSObject.Properties['quick'] -and $se.quick)
        Start-Player $sessionExe $a -Minimized:$script:NoInput -Quick:$quick | Out-Null
        $proc = $script:StartedProcs[$script:StartedProcs.Count - 1]
        if ($quick) { throw 'QUICK' }
        $size = if ($se.size) { $se.size } else { @(1920, 1080) }
        Set-PlayerSize ([double]$size[0]) ([double]$size[1]) -Offscreen $script:Lane | Out-Null
        Start-Sleep -Milliseconds 800
        if (-not $script:NoInput) { $m0 = Get-MainWindow; Invoke-FocusPlayer $m0.Handle | Out-Null }
        # Qt builds its accessibility tree on the first UI Automation request: wait until the
        # player's interface is visible to UIA before the first step looks for one
        if (-not (Find-UiaElement 'Main interface' '' 15000)) { Write-VLog '  note: UI Automation did not show the player interface within 15 s' }
        if ($script:NoInput -and -not (Find-UiaElement 'Playback Settings' 'Button' 15000)) { Write-VLog '  note: the control bar buttons did not show in UI Automation within 15 s' }
        $ctx = New-StepContext $RunDir "$($se.id)-setup"
        try { foreach ($s in @($se.setup)) { if ($s) { Invoke-Step $s $ctx } } }
        finally { $setupChecks = @($ctx.Checks | ForEach-Object { $x = [ordered]@{}; foreach ($k in $_.Keys) { $x[$k] = $_[$k] }; $x.check = "setup: " + $x.check; $x }) }
    } catch {
      if ($_.Exception.Message -eq 'QUICK') { $sessionError = $null }  # quick session: no sizing, no warm-up
      else {
        $sessionError = "session setup failed: $($_.Exception.Message)"; Write-VLog "  $sessionError"
        if ($sessionError -like '*GUARD:*') { $out.aborted = "aborted: $($_.Exception.Message)" }
      }
    }
    foreach ($sc in $p.Scenarios) {
        $r = [ordered]@{ id = $sc.id; title = $sc.title; rows = @($sc.rows); compare = @($sc.compare | Where-Object { $_ }); human = @($sc.human | Where-Object { $_ })
            status = 'ok'; error = $null; shots = @(); checks = @(); notes = @(); seconds = 0; session = $se.id; lane = $(if ($script:NoInput) { "uia$script:Lane" } else { 'manual' }) }
        $ssw = [Diagnostics.Stopwatch]::StartNew()
        if ($sessionError -or $out.aborted -or $out.lost) { $r.status = 'error'; $r.error = @($out.lost, $out.aborted, $sessionError) | Where-Object { $_ } | Select-Object -First 1; [void]$out.results.Add($r); continue }
        Write-VLog "  scenario $($sc.id): $($sc.title)"
        $ctx = New-StepContext $RunDir $sc.id
        try {
            foreach ($s in @($se.reset) + @($sc.steps)) { if ($s) { Invoke-Step $s $ctx } }
        } catch {
            $r.status = 'error'; $r.error = $_.Exception.Message
            Write-VLog "    ERROR: $($r.error)"
            if ($r.error -like 'GUARD:*') { $out.aborted = "aborted: $($r.error)" }
        }
        # the player must still be there with its window, or the results come from a dead player
        $alive = $false
        try { $alive = (-not $proc.HasExited) -and [bool](Get-MainWindow 2) } catch {}
        if (-not $alive) { $out.lost = 'aborted (window closed)'; Write-VLog "    the player or its window is gone: session aborted (window closed)" }
        $r.shots = @($ctx.Shots); $r.checks = @($setupChecks) + @($ctx.Checks); $r.notes = @($ctx.Notes)
        $r.seconds = [math]::Round($ssw.Elapsed.TotalSeconds, 1)
        [void]$out.results.Add($r)
    }
    if (-not $out.aborted -and -not $out.lost -and -not $script:NoInput -and $quit -eq 'keys') {
        try { Invoke-FocusPlayer (Get-MainWindow 3).Handle | Out-Null; Send-Keys '{ESC}'; Restore-PlayerVolume } catch { Write-VLog "  volume not restored: $($_.Exception.Message)" }
    }
    if ($quit -eq 'none') { $out.proc = $proc; $out.seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1); return $out }
    $q = Stop-Players -NoKeys:([bool]$out.aborted -or [bool]$out.lost -or $quit -eq 'close')
    $out.cleanup = "$($se.id)$(if ($script:NoInput) { "@lane$script:Lane" }): $q"
    $out.stuck = ($q -like 'STUCK*')
    $out.seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    Write-VLog "  quit: $q ($($out.seconds) s)"
    if ($q -like 'STILL RUNNING*') { $out.aborted = "aborted: a player did not close ($q)" }
    return $out
}
# a session, retried once when its player went away mid-session
function Invoke-SessionWithRetry($p, [string]$sessionExe, [string]$profileTarget) {
    $o = Invoke-Session $p $sessionExe $profileTarget
    if ($o.lost -and -not $o.aborted) {
        Write-VLog "  retrying session $($p.Session.id) once (the first try is discarded)"
        $first = $o.cleanup
        $o = Invoke-Session $p $sessionExe $profileTarget
        $o.cleanup = "first try aborted (window closed): $first; retry: $($o.cleanup)"
    }
    return $o
}

# --- UIA lane worker -----------------------------------------------------------------------------
if ($Worker) {
    # (not "$demo": PowerShell names are case-insensitive, that would replace $script:Demo)
    $res = New-Object System.Collections.ArrayList; $clean = @(); $laneDemo = [ordered]@{}; $times = [ordered]@{}
    $laneExe = $exe; $laneProfile = Join-Path (Split-Path $exe) 'portable'
    $lw = [Diagnostics.Stopwatch]::StartNew()
    try {
        foreach ($p in $plan) {
            $o = Invoke-SessionWithRetry $p $laneExe $laneProfile
            foreach ($r in $o.results) { [void]$res.Add($r) }
            $clean += $o.cleanup; $laneDemo[$p.Session.id] = $o.demo; $times[$p.Session.id] = $o.seconds
            if ($o.aborted) { break }
        }
    } finally {
        $final = Stop-Players -NoKeys
        $clean += "lane$LaneNo final: $final" + $(if ($script:StuckPids.Count) { "; stuck in termination: $($script:StuckPids -join ', ')" } else { '' })
        $lo = [ordered]@{ lane = $LaneNo; seconds = [math]::Round($lw.Elapsed.TotalSeconds, 1); sessions = $times; cleanup = $clean; demo = $laneDemo; stuck = @($script:StuckPids); scenarios = @($res) }
        $lo | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $RunDir "lane$LaneNo.json") -Encoding utf8
    }
    exit 0
}

# --- exit retest: one session N times, counting stuck exits --------------------------------------
# each try: the session's steps, then one quit (odd tries Escape x2 + Ctrl+Q, even tries WM_CLOSE to
# the main window), 5 s later the process is checked: gone = clean; still listed with one thread and
# no window = stuck (left untouched, pid noted); still with a window = hung (then closed normally)
if ($ExitRetest -gt 0) {
    if (-not $plan.Count) { throw "no session '$RetestSession'" }
    $p = $plan[0]; $tally = @(); $rt0 = Get-Date
    $profileTarget = Join-Path (Split-Path $exe) 'portable'
    for ($i = 1; $i -le $ExitRetest; $i++) {
        $how = if ($i % 2) { 'Ctrl+Q' } else { 'WM_CLOSE' }
        $o = Invoke-Session $p $exe $profileTarget 'none'
        $proc = $o.proc; $state = 'no player'; $threads = $null
        if ($o.aborted -or $o.lost) {
            # the steps did not run (guard, lost window): not a valid try; close and go on
            $state = 'aborted (not counted)'; Write-VLog "  $(Stop-Players -NoKeys)"
        }
        elseif ($proc) {
            try {
                $m = Get-MainWindow 3
                if ($how -eq 'Ctrl+Q') {
                    if (Invoke-FocusPlayer $m.Handle) { foreach ($k in '{ESC}', '{ESC}', '^q') { if (Test-PlayerForeground) { [System.Windows.Forms.SendKeys]::SendWait($k); Set-Injected; Start-Sleep -Milliseconds 250 } } }
                    else { $how = 'WM_CLOSE (no foreground for Ctrl+Q)'; [RdVerifyWin2]::PostMessage($m.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
                } else { [RdVerifyWin2]::PostMessage($m.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
            } catch { $how += " (window lookup failed: $($_.Exception.Message))" }
            Start-Sleep -Seconds 5
            $q = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if (-not $q -or $q.StartTime -ne $proc.StartTime) { $state = 'clean' }
            else {
                $threads = $q.Threads.Count
                $state = if (Test-NoWindow $proc.Id) { 'stuck' } else { 'hung with a window' }
            }
            if ($state -eq 'stuck') { $script:StuckPids += $proc.Id; [void]$script:StartedProcs.Remove($proc) }
            elseif ($state -ne 'clean') { Write-VLog "  $(Stop-Players)" }
        }
        $script:StartedProcs.Clear(); Update-Started
        $tally += [ordered]@{ try = $i; quit = $how; state = $state; pid = $(if ($proc) { $proc.Id } else { $null }); threads = $threads; seconds = $o.seconds; lost = $o.lost; error = (@($o.results | Where-Object { $_.error } | ForEach-Object { $_.error }) -join '; ') }
        Write-VLog ("retest {0}/{1} {2}: quit {3}: {4}{5}" -f $i, $ExitRetest, $p.Session.id, $how, $state, $(if ($state -eq 'stuck') { " (pid $($proc.Id), $threads thread(s))" } else { '' }))
        if ($o.aborted -and @($tally | Where-Object { $_.state -like 'aborted*' }).Count -ge 3) { break }
    }
    # Windows' own crash records for the player in the retest's time window (read only)
    $events = @()
    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $rt0 } -ErrorAction SilentlyContinue |
            Where-Object { ($_.ProviderName -in 'Application Error', 'Windows Error Reporting', 'Application Hang') -and $_.Message -match 'Cone\.exe' } |
            ForEach-Object { [ordered]@{ time = $_.TimeCreated.ToString('o'); provider = $_.ProviderName; id = $_.Id; message = ($_.Message -split "`n" | Select-Object -First 6) -join ' ' } })
    } catch {}
    $sum = [ordered]@{ run = $runName; build = "$Build $buildId"; exe = (Split-Path $exe -Leaf); session = $p.Session.id
        tries = @($tally | Where-Object { $_.state -notlike 'aborted*' }).Count; aborted_tries = @($tally | Where-Object { $_.state -like 'aborted*' }).Count
        stuck_ctrl_q = @($tally | Where-Object { $_.state -eq 'stuck' -and $_.quit -like 'Ctrl+Q*' }).Count
        stuck_wm_close = @($tally | Where-Object { $_.state -eq 'stuck' -and $_.quit -like 'WM_CLOSE*' }).Count
        hung = @($tally | Where-Object { $_.state -like 'hung*' }).Count
        stuck_pids = @($tally | Where-Object { $_.state -eq 'stuck' } | ForEach-Object { $_.pid }); events = $events; tries_detail = $tally }
    $sum | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $RunDir "exit-retest-$($p.Session.id).json") -Encoding utf8
    Write-VLog "exit retest $($p.Session.id): $($sum.stuck_ctrl_q) stuck after Ctrl+Q, $($sum.stuck_wm_close) after WM_CLOSE, $($sum.hung) hung, of $($sum.tries) tries; $($events.Count) crash / WER event(s)"
    "run folder: $RunDir"
    exit 0
}

# --- main run: UIA lanes in parallel + the manual lane -------------------------------------------
$results = New-Object System.Collections.ArrayList
$cleanup = @(); $demoLog = [ordered]@{}; $laneInfo = [ordered]@{}; $aborted = $null
$workers = @()
$manualPlan = @($plan | Where-Object { -not ($Lanes -gt 0 -and $_.Uia) -and -not $LanesOnly })
$uiaPlan = @($plan | Where-Object { $Lanes -gt 0 -and $_.Uia })
if ($uiaPlan.Count) {
    # lane copies of the build: <builds>\<run number>-lane<k>, made and refreshed by the harness
    # (never the fixed test folders); their portable folders get the run profile per session
    $n = [math]::Min($Lanes, $uiaPlan.Count)
    $buckets = @(); for ($k = 0; $k -lt $n; $k++) { $buckets += , (New-Object System.Collections.ArrayList) }
    $loads = @(0) * $n
    foreach ($p in ($uiaPlan | Sort-Object { - $_.Scenarios.Count })) {
        $k = 0; for ($j = 1; $j -lt $n; $j++) { if ($loads[$j] -lt $loads[$k]) { $k = $j } }
        [void]$buckets[$k].Add($p); $loads[$k] += $p.Scenarios.Count
    }
    $srcDir = Split-Path $exe
    $slot = 0
    for ($k = 1; $k -le $n; $k++) {
        # a lane folder whose player is stuck in termination keeps its files locked: use the next one
        do {
            $slot++
            $ld = Join-Path (Join-Path $cfg.testMediaDir 'builds') ("{0}-lane{1}" -f $(if ($buildNum) { $buildNum } else { 'build' }), $slot)
            $busy = @(Get-Process Cone, vlc -ErrorAction SilentlyContinue | Where-Object { $pp = $null; try { $pp = $_.Path } catch {}; $pp -and $pp.StartsWith($ld + [char]92, [StringComparison]::OrdinalIgnoreCase) })
            if ($busy) { Write-VLog "lane folder $(Split-Path $ld -Leaf) is busy (pid $($busy.Id -join ', ')): skipped" }
        } while ($busy -and $slot -lt 12)
        if ($ld -like (Join-Path $cfg.testMediaDir 'builds\current*')) { throw "bad lane folder $ld" }
        $lsw = [Diagnostics.Stopwatch]::StartNew()
        # the network discovery plugins (UPnP, mDNS, SAP) are left out of lane copies: they open
        # listening sockets, and every new exe path would raise a Windows Firewall prompt
        robocopy $srcDir $ld /MIR /XD (Join-Path $srcDir 'portable') (Join-Path $ld 'portable') /XF libupnp_plugin.dll libmicrodns_plugin.dll libsap_plugin.dll /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "copying the build to $ld failed ($LASTEXITCODE)" }
        foreach ($nd in 'libupnp_plugin.dll', 'libmicrodns_plugin.dll', 'libsap_plugin.dll') {
            $nf = Join-Path $ld "plugins\services_discovery\$nd"; if (Test-Path -LiteralPath $nf) { Remove-Item -LiteralPath $nf }
        }
        $laneDirs += $ld
        $ids = ($buckets[$k - 1] | ForEach-Object { $_.Session.id }) -join ','
        $laneExe = Join-Path $ld (Split-Path $exe -Leaf)
        $laneCfg = @{ lane = $k; exe = $laneExe }
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $here 'verify.ps1')`"", '-Worker', '-LaneNo', $k, '-RunDir', "`"$RunDir`"",
                     '-Sessions', $ids, '-Build', $Build, '-WaitForOthersMin', $WaitForOthersMin)
        if ($Area) { $argList += @('-Area', $Area) }
        if ($Only) { $argList += @('-Only', "`"$Only`"") }
        $env:VERIFY_LANE_EXE = $laneExe
        $wp = Start-Process powershell -ArgumentList $argList -WindowStyle Hidden -PassThru
        $null = $wp.Handle
        $workers += [pscustomobject]@{ Lane = $k; Proc = $wp; Sessions = $ids; Dir = $ld; CopySec = [math]::Round($lsw.Elapsed.TotalSeconds, 1) }
        Write-VLog "lane ${k}: sessions $ids (build copy $([math]::Round($lsw.Elapsed.TotalSeconds, 1)) s)"
    }
    Remove-Item Env:\VERIFY_LANE_EXE -ErrorAction SilentlyContinue
}
$msw = [Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($p in $manualPlan) {
        if ($aborted) { break }
        $o = Invoke-SessionWithRetry $p $exe (Join-Path (Split-Path $exe) 'portable')
        foreach ($r in $o.results) { [void]$results.Add($r) }
        $cleanup += $o.cleanup; if ($o.demo) { $demoLog[$p.Session.id] = $o.demo }
        $laneInfo["manual:$($p.Session.id)"] = $o.seconds
        if ($o.aborted) { $aborted = $o.aborted }
    }
} finally {
    $final = Stop-Players -NoKeys:([bool]$aborted)
    Update-Started
    $cleanup += "manual final: $final; started players left: $(@($script:StartedPids).Count)" + $(if ($script:StuckPids.Count) { "; stuck in termination (no window, never ended): $($script:StuckPids -join ', ')" } else { '' })
    Write-VLog "cleanup: $($cleanup[-1])"
    $manualSec = [math]::Round($msw.Elapsed.TotalSeconds, 1)
    foreach ($w in $workers) {
        if (-not $w.Proc.WaitForExit(30 * 60 * 1000)) { Write-VLog "lane $($w.Lane): worker still running after 30 min"; continue }
        $lj = Join-Path $RunDir "lane$($w.Lane).json"
        if (Test-Path $lj) {
            $lo = Get-Content -Raw -Encoding UTF8 $lj | ConvertFrom-Json
            foreach ($r in @($lo.scenarios)) { [void]$results.Add($r) }
            $cleanup += @($lo.cleanup)
            foreach ($pr in $lo.demo.PSObject.Properties) { $demoLog["$($pr.Name)@lane$($w.Lane)"] = @($pr.Value) }
            $laneInfo["lane$($w.Lane)"] = [ordered]@{ seconds = $lo.seconds; copy_seconds = $w.CopySec; sessions = $lo.sessions; stuck = @($lo.stuck) }
        } else { $cleanup += "lane$($w.Lane): no result file (worker failed; see lane$($w.Lane).log)" }
    }
    $laneInfo['manual'] = [ordered]@{ seconds = $manualSec; sessions = @($manualPlan | ForEach-Object { $_.Session.id }) }
    $run = [ordered]@{ run = $runName; build = "$Build $buildId"; started = $t0.ToString('o'); seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        lanes = $laneInfo; aborted = $aborted; cleanup = ($cleanup -join ' | '); demo = $demoLog; scenarios = @($results) }
    $run | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $RunDir 'run.json') -Encoding utf8
}
if (-not $NoCompare) { & python (Join-Path $here 'compare.py') $RunDir }
"run folder: $RunDir"
