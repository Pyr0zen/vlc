# Verification harness runner: drives the test build through the scenario table, screenshots the
# player window, then compare.py diffs the shots against the Figma frames and writes the report.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1 [options]
#     -Build public|vlc        which fixed test folder to run (default public: builds\current-public\Cone.exe)
#     -Only P2-03,IB-08,...    only scenarios covering these VIDEO_INDEX row IDs (or scenario ids)
#     -Area player             only scenario files whose "area" matches
#     -DryRun                  print the plan and validate the Figma nodes; starts nothing, sends nothing
#     -NoCompare               run and screenshot only (compare later: python compare.py <run dir>)
#     -Label <text>            appended to the run folder name
# See README.md for the scenario format and the safety rules.
param([string]$Build = 'public', [string]$Only = '', [string]$Area = '', [switch]$DryRun, [switch]$NoCompare,
      [string]$Label = '', [string[]]$Files = @(), [int]$WaitForOthersMin = 30)
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
$plan = New-Object System.Collections.ArrayList
foreach ($f in $Files) {
    $data = Get-Content -Raw -Encoding UTF8 $f | ConvertFrom-Json
    if ($Area -and $data.area -ne $Area) { continue }
    foreach ($se in $data.sessions) {
        $sel = @($se.scenarios | Where-Object {
            $sc = $_
            (-not $onlySet) -or ($onlySet -contains $sc.id) -or (@($sc.rows | Where-Object { $onlySet -contains $_ }).Count -gt 0) -or
            (@($sc.compare | ForEach-Object { $_.rows } | Where-Object { $_ -and ($onlySet -contains $_) }).Count -gt 0) })
        if ($sel.Count -gt 0) { [void]$plan.Add([pscustomobject]@{ File = (Split-Path $f -Leaf); Area = $data.area; Session = $se; Scenarios = $sel }) }
    }
}
$nScen = ($plan | ForEach-Object { $_.Scenarios.Count } | Measure-Object -Sum).Sum
"plan: $($plan.Count) session(s), $nScen scenario(s), build '$Build'"

$exePath = [string]$cfg.builds.$Build
$exe = if ([IO.Path]::IsPathRooted($exePath)) { $exePath } else { Join-Path $cfg.testMediaDir $exePath }
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
        "session $($se.id) [$($p.File)]: media $(@($se.media) -join ', '); args $(@($se.args) -join ' '); size $(@($se.size) -join 'x')"
        $ctx = New-StepContext '' 'dry' -DryRun
        foreach ($s in @($se.setup)) { if ($s) { Invoke-Step $s $ctx } }
        foreach ($sc in $p.Scenarios) {
            "  scenario $($sc.id) rows $(@($sc.rows) -join ','): $($sc.title)"
            foreach ($s in @($se.reset) + @($sc.steps)) { if ($s) { Invoke-Step $s $ctx } }
            foreach ($c in @($sc.compare)) { if ($c) { "    compare $($c.id): shot $($c.shot) node $($c.node) ref $($c.ref) anchor $($c.anchor)" } }
            foreach ($h in @($sc.human)) { if ($h) { "    human: $h" } }
        }
    }
    if (-not (Test-Path -LiteralPath $exe)) { "WARNING: player not found: $exe" }
    foreach ($p in $plan) { foreach ($m in @($p.Session.media)) { if ($m -and -not (Test-Path -LiteralPath (Join-Path $mediaRoot $m))) { "WARNING: media missing: $m (run make_media.py)" } } }
    & python (Join-Path $here 'compare.py') --validate @($plan | ForEach-Object { Join-Path (Join-Path $here 'scenarios') $_.File } | Select-Object -Unique)
    $valid = $LASTEXITCODE
    "dry run: nothing started, no input sent"
    exit $valid
}

# --- run -----------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $exe)) { throw "player not found: $exe" }
$runName = (Get-Date -Format 'yyyyMMdd-HHmmss') + $(if ($Label) { "-$Label" } else { '' })
$runDir = Join-Path $cfg.outRoot $runName
New-Item -ItemType Directory -Force $runDir | Out-Null
$logFile = Join-Path $runDir 'run.log'
$script:Log = { param($m) Write-Host $m; Add-Content -LiteralPath $logFile -Value $m -Encoding utf8 }
$buildId = ''
$br = Join-Path (Split-Path $exe) 'build-run.txt'; if (Test-Path $br) { $buildId = (Get-Content $br -Raw).Trim() }
if ($exe -match '\\builds\\(\d{6,})\\') { $buildId = "run $($Matches[1])" + $(if ($buildId) { " ($buildId)" } else { '' }) }
Write-VLog "run $runName, build '$Build' ($buildId), $nScen scenario(s)"

# another test player (the main session's manual test) must not be running: wait for it before
# every session
$ignore = @($cfg.ignorePids | ForEach-Object { [int]$_ })
function Wait-ForOtherPlayers {
    $waitEnd = (Get-Date).AddMinutes($WaitForOthersMin)
    while ($true) {
        $foreign = Get-ForeignTestPlayers (Join-Path $cfg.testMediaDir 'builds') $ignore
        if (-not $foreign) { return }
        if ((Get-Date) -gt $waitEnd) { throw "another test player is still running (pid $($foreign.Id -join ', ')); not started" }
        Write-VLog "  waiting: another test player is running (pid $($foreign.Id -join ', '))"
        Start-Sleep -Seconds 15
    }
}
Wait-ForOtherPlayers

# run-specific profile: a snapshot of the profile source (never edited in place), mirrored into the
# build's portable folder before every session and then given the session's demo values
$profileSource = if ($cfg.PSObject.Properties['profileSource'] -and $cfg.profileSource) {
    if ([IO.Path]::IsPathRooted([string]$cfg.profileSource)) { [string]$cfg.profileSource } else { Join-Path $cfg.testMediaDir ([string]$cfg.profileSource) } } else { $null }
$profileTarget = Join-Path (Split-Path $exe) 'portable'
$profileBase = $null
if ($profileSource) {
    if ($profileTarget -like (Join-Path $cfg.testMediaDir 'builds\current*')) { throw "refusing to overwrite the profile of a fixed test folder: $profileTarget" }
    if ([string]::Equals($profileTarget.TrimEnd([char]92), $profileSource.TrimEnd([char]92), [StringComparison]::OrdinalIgnoreCase)) { throw "profileSource and the build's portable folder are the same" }
    $profileBase = Join-Path $runDir 'profile-base'
    robocopy $profileSource $profileBase /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "copying the profile source failed ($LASTEXITCODE)" }
    Write-VLog "profile: snapshot of the profile source in profile-base; each session starts from it"
}
function Initialize-Profile($se) {
    $applied = @()
    if (-not $profileBase) { return $applied }
    robocopy $profileBase $profileTarget /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "preparing the run profile failed ($LASTEXITCODE)" }
    $vlcrc = Join-Path $profileTarget 'vlcrc'
    if (-not (Test-Path $vlcrc)) { return $applied }
    $text = [IO.File]::ReadAllText($vlcrc)
    # harness overrides (config "profileOverrides"), e.g. qt-cast-discovery=0: no cast discovery,
    # so no listening socket and no Windows Firewall prompt over the player for a new build path
    if ($cfg.PSObject.Properties['profileOverrides'] -and $cfg.profileOverrides) {
        foreach ($p in $cfg.profileOverrides.PSObject.Properties) {
            $key = [regex]::Escape($p.Name); $line = "$($p.Name)=$($p.Value)"
            if ($text -match "(?m)^#?$key=.*$") { $text = [regex]::Replace($text, "(?m)^#?$key=.*$", $line.Replace('$', '$$'), 1) } else { $text += "`n$line`n" }
            $applied += "harness: $line"
        }
    }
    if (-not $script:Demo -or -not $se.PSObject.Properties['demo']) { [IO.File]::WriteAllText($vlcrc, $text, (New-Object System.Text.UTF8Encoding $false)); return $applied }
    foreach ($sid in @($se.demo)) {
        $scr = $script:Demo.screens.$sid
        if (-not $scr) { continue }
        foreach ($v in @($scr.values)) {
            if ($v.how -ne 'vlcrc' -or -not $v.option) { continue }
            $pairs = @(@([string]$v.option, [string]$v.value))
            if ($v.PSObject.Properties['extra']) { foreach ($x in @($v.extra)) { $pairs += ,@([string]$x.option, [string]$x.value) } }
            $lines = @()
            foreach ($pv in $pairs) {
                $key = [regex]::Escape($pv[0]); $line = "$($pv[0])=$($pv[1])"; $lines += $line
                if ($text -match "(?m)^#?$key=.*$") { $text = [regex]::Replace($text, "(?m)^#?$key=.*$", $line.Replace('$', '$$'), 1) }
                else { $text += "`n$line`n" }
            }
            $applied += "${sid}: $($v.label) = $($v.figma) (vlcrc $($lines -join ', '))"
        }
    }
    [IO.File]::WriteAllText($vlcrc, $text, (New-Object System.Text.UTF8Encoding $false))
    return $applied
}
$demoLog = [ordered]@{}

$results = New-Object System.Collections.ArrayList
$cleanup = @()
$aborted = $null
try {
    foreach ($p in $plan) {
        if ($aborted) { break }
        $se = $p.Session
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Write-VLog "session $($se.id)"
        # "{media}" in an argument stands for the verify media folder (e.g. --sub-file={media}\Videos\x.srt)
        $a = @($baseArgs) + @($se.args | Where-Object { $_ } | ForEach-Object { $x = ([string]$_).Replace('{media}', $mediaRoot); if ($x -match '^(--[^=]+=)(.* .*)$') { $Matches[1] + '"' + $Matches[2] + '"' } else { $x } })
        foreach ($m in @($se.media)) { if ($m) { $a += ('"{0}"' -f (Join-Path $mediaRoot $m)) } }
        $sessionError = $null
        $setupChecks = @()
        try {
            Wait-ForOtherPlayers
            $applied = @(Initialize-Profile $se)
            if ($applied.Count) { $demoLog[$se.id] = $applied; foreach ($x in $applied) { Write-VLog "  demo: $x" } }
            Start-Player $exe $a | Out-Null
            $size = if ($se.size) { $se.size } else { @(1920, 1080) }
            Set-PlayerSize ([double]$size[0]) ([double]$size[1]) | Out-Null
            Start-Sleep -Milliseconds 800
            $m0 = Get-MainWindow; Invoke-FocusPlayer $m0.Handle | Out-Null
            # Qt builds its accessibility tree on the first UI Automation request: wait until the
            # player's interface is visible to UIA before the first step looks for one
            if (-not (Find-UiaElement 'Main interface' '' 15000)) { Write-VLog '  note: UI Automation did not show the player interface within 15 s' }
            $ctx = New-StepContext $runDir "$($se.id)-setup"
            try { foreach ($s in @($se.setup)) { if ($s) { Invoke-Step $s $ctx } } }
            finally { $setupChecks = @($ctx.Checks | ForEach-Object { $x = [ordered]@{}; foreach ($k in $_.Keys) { $x[$k] = $_[$k] }; $x.check = "setup: " + $x.check; $x }) }
        } catch {
            $sessionError = "session setup failed: $($_.Exception.Message)"; Write-VLog "  $sessionError"
            if ($sessionError -like '*GUARD:*') { $aborted = "aborted: $($_.Exception.Message)" }
        }
        foreach ($sc in $p.Scenarios) {
            $r = [ordered]@{ id = $sc.id; title = $sc.title; rows = @($sc.rows); compare = @($sc.compare | Where-Object { $_ }); human = @($sc.human | Where-Object { $_ })
                status = 'ok'; error = $null; shots = @(); checks = @(); notes = @(); seconds = 0 }
            $ssw = [Diagnostics.Stopwatch]::StartNew()
            if ($sessionError -or $aborted) { $r.status = 'error'; $r.error = $(if ($aborted) { $aborted } else { $sessionError }); [void]$results.Add($r); continue }
            Write-VLog "  scenario $($sc.id): $($sc.title)"
            $ctx = New-StepContext $runDir $sc.id
            try {
                foreach ($s in @($se.reset) + @($sc.steps)) { if ($s) { Invoke-Step $s $ctx } }
            } catch {
                $r.status = 'error'; $r.error = $_.Exception.Message
                Write-VLog "    ERROR: $($r.error)"
                if ($r.error -like 'GUARD:*') { $aborted = "aborted: $($r.error)" }
                try { if (-not (Get-MainWindow 3)) { throw 'gone' } } catch { $sessionError = 'the player window is gone (crash?)'; Write-VLog "    $sessionError" }
            }
            # the session's setup checks (e.g. the seek position) belong to every scenario of it
            $r.shots = @($ctx.Shots); $r.checks = @($setupChecks) + @($ctx.Checks); $r.notes = @($ctx.Notes)
            $r.seconds = [math]::Round($ssw.Elapsed.TotalSeconds, 1)
            [void]$results.Add($r)
        }
        if (-not $aborted) { try { Invoke-FocusPlayer (Get-MainWindow 3).Handle | Out-Null; Send-Keys '{ESC}'; Restore-PlayerVolume } catch { Write-VLog "  volume not restored: $($_.Exception.Message)" } }
        $q = Stop-Players -NoKeys:([bool]$aborted)
        $cleanup += "$($se.id): $q"
        Write-VLog "  quit: $q ($([math]::Round($sw.Elapsed.TotalSeconds, 1)) s)"
        if ($q -like 'STILL RUNNING*') { $aborted = "aborted: a player did not close ($q)"; break }
    }
} finally {
    $final = Stop-Players -NoKeys:([bool]$aborted)
    Update-Started
    $left = @($script:StartedPids)
    $cleanup += "final: $final; started players left: $($left.Count)" + $(if ($script:StuckPids.Count) { "; stuck in termination (no window, cannot be ended): $($script:StuckPids -join ', ')" } else { '' })
    Write-VLog "cleanup: $($cleanup[-1])"
    $run = [ordered]@{ run = $runName; build = "$Build $buildId"; started = $t0.ToString('o'); seconds = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        aborted = $aborted; cleanup = ($cleanup -join ' | '); demo = $demoLog; scenarios = @($results) }
    $run | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $runDir 'run.json') -Encoding utf8
}
if (-not $NoCompare) { & python (Join-Path $here 'compare.py') $runDir }
"run folder: $runDir"
