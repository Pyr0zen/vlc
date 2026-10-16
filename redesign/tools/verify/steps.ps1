# Scenario step executor (dot-sourced by verify.ps1 and probe.ps1 after driver.ps1).
# A step is one JSON object; the keys are listed in README.md ("Step reference").
# Positions are logical pixels (Figma units) inside the main window's client area, measured from
# the corner named by "from" (tl default, tr, bl, br), so the same step works windowed and in
# fullscreen.

function New-StepContext([string]$outDir, [string]$scenarioId, [switch]$DryRun) {
    [pscustomobject]@{ OutDir = $outDir; Scenario = $scenarioId; DryRun = [bool]$DryRun
        Shots = New-Object System.Collections.ArrayList; Checks = New-Object System.Collections.ArrayList
        Notes = New-Object System.Collections.ArrayList }
}

function Resolve-Pos($step, [string]$key) {
    $p = $step.$key; $x = [double]$p[0]; $y = [double]$p[1]
    $from = if ($step.PSObject.Properties['from']) { [string]$step.from } else { 'tl' }
    if ($from -ne 'tl') {
        $m = Get-MainWindow; $s = Get-Scale $m.Handle; $c = Get-ClientRect $m.Handle
        $W = $c.Width / $s; $H = $c.Height / $s
        if ($from -like '*r') { $x = $W - $x }
        if ($from -like 'b*') { $y = $H - $y }
    }
    return @($x, $y)
}

function Get-StepProp($step, [string]$name, $default) {
    if ($step.PSObject.Properties[$name]) { return $step.$name } else { return $default }
}

function Format-Step($step) { ($step | ConvertTo-Json -Compress -Depth 6) }

function Find-StepElement($step) {
    $el = Find-UiaElement ([string]$step.uia) ([string](Get-StepProp $step 'role' '')) ([int](Get-StepProp $step 'timeout' 3000)) ([string](Get-StepProp $step 'match' 'exact'))
    return $el
}

function Invoke-Step($step, $ctx) {
    if ($ctx.DryRun) { Write-VLog ("    [dry] " + (Format-Step $step)); return }
    $names = @($step.PSObject.Properties.Name)
    if ($names -contains 'wait') { Start-Sleep -Milliseconds ([int]$step.wait); return }
    if ($names -contains 'keys') { Send-Keys ([string]$step.keys); Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 300)); return }
    if ($names -contains 'click') {
        $p = Resolve-Pos $step 'click'
        Send-Click $p[0] $p[1] ([string](Get-StepProp $step 'button' 'left')) ([int](Get-StepProp $step 'count' 1))
        Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 400)); return
    }
    if ($names -contains 'hover') { $p = Resolve-Pos $step 'hover'; Move-Mouse $p[0] $p[1] | Out-Null; Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 500)); return }
    if ($names -contains 'wiggle') { $p = Resolve-Pos $step 'wiggle'; Wiggle-Mouse $p[0] $p[1]; Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 400)); return }
    if ($names -contains 'wheel') { $p = Resolve-Pos $step 'wheel'; Send-Wheel $p[0] $p[1] ([int](Get-StepProp $step 'delta' 120)); Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 400)); return }
    if ($names -contains 'drag') {
        $d = $step.drag
        $a = Resolve-Pos ([pscustomobject]@{ p = @($d[0], $d[1]); from = (Get-StepProp $step 'from' 'tl') }) 'p'
        $b = Resolve-Pos ([pscustomobject]@{ p = @($d[2], $d[3]); from = (Get-StepProp $step 'from' 'tl') }) 'p'
        Send-Drag $a[0] $a[1] $b[0] $b[1]; Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 400)); return
    }
    if ($names -contains 'resize') { Set-PlayerSize ([double]$step.resize[0]) ([double]$step.resize[1]) | Out-Null; Start-Sleep -Milliseconds 500; return }
    if ($names -contains 'uia') {
        $el = Find-StepElement $step
        $optional = [bool](Get-StepProp $step 'optional' $false)
        if (-not $el) {
            if ($optional) { [void]$ctx.Notes.Add("optional element '$($step.uia)' not found"); return }
            throw "UIA element '$($step.uia)' not found"
        }
        $action = [string](Get-StepProp $step 'action' 'click')
        switch ($action) {
            'click' { Invoke-UiaElement $el | Out-Null }
            'rightclick' { Invoke-UiaElement $el 'right' | Out-Null }
            'hover' { $r = $el.Current.BoundingRectangle; Move-Mouse ($r.X + $r.Width / 2) ($r.Y + $r.Height / 2) -Screen | Out-Null }
            'invoke' {
                Assert-Guard; $p = $null
                if ($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p)) { $p.Invoke() } else { throw "no Invoke pattern on '$($step.uia)'" }
            }
            'setvalue' { [void]$ctx.Notes.Add("$($step.uia): " + (Set-UiaValue $el $step.value)) }
            'focus' { Assert-Guard; $el.SetFocus() }
            default { throw "unknown uia action '$action'" }
        }
        Start-Sleep -Milliseconds ([int](Get-StepProp $step 'after' 400)); return
    }
    if ($names -contains 'shot') { Save-ScenarioShot $step $ctx; return }
    if ($names -contains 'expect') { Test-Expectation $step $ctx; return }
    if ($names -contains 'demo') { Set-DemoState ([string]$step.demo) $ctx; return }
    if ($names -contains 'volume') { Set-PlayerVolume ([double]$step.volume) $ctx; return }
    if ($names -contains 'uiaDump') { Get-UiaTree | Set-Content -Encoding utf8 (Join-Path $ctx.OutDir ("{0}__{1}.uia.txt" -f $ctx.Scenario, $step.uiaDump)); return }
    if ($names -contains 'note') { [void]$ctx.Notes.Add([string]$step.note); return }
    throw "unknown step: $(Format-Step $step)"
}

# screenshot of the player's client area (+ every other visible window of the player when
# "windows": "all", e.g. a dialog or a menu that is its own window), with the facts compare.py
# needs: scale, client size, rectangles of the named UIA elements
function Save-ScenarioShot($step, $ctx) {
    $name = [string]$step.shot
    $m = Get-MainWindow; $s = Get-Scale $m.Handle; $c = Get-ClientRect $m.Handle
    $file = Join-Path $ctx.OutDir ("{0}__{1}.png" -f $ctx.Scenario, $name)
    $shot = Save-WindowShot $m.Handle $file -Client
    $meta = [ordered]@{ name = $name; file = (Split-Path $file -Leaf); scale = $s; method = $shot.Method
        client = [ordered]@{ w = $c.Width; h = $c.Height; wl = [math]::Round($c.Width / $s, 2); hl = [math]::Round($c.Height / $s, 2) }
        title = $m.Title; time = (Get-Date -Format o); extra = @(); uia = [ordered]@{} }
    if ([string](Get-StepProp $step 'windows' 'main') -eq 'all') {
        $i = 0
        foreach ($w in (Get-PlayerWindows)) {
            if ($w.Handle -eq $m.Handle -or $w.Class -eq 'Static' -or $w.Width -lt 8 -or $w.Height -lt 8) { continue }
            $i++; $f2 = Join-Path $ctx.OutDir ("{0}__{1}__w{2}.png" -f $ctx.Scenario, $name, $i)
            $x = Save-WindowShot $w.Handle $f2
            $meta.extra += [ordered]@{ file = (Split-Path $f2 -Leaf); title = $w.Title; class = $w.Class
                x = [math]::Round(($x.Left - $c.Left) / $s, 1); y = [math]::Round(($x.Top - $c.Top) / $s, 1); w = [math]::Round($x.Width / $s, 1); h = [math]::Round($x.Height / $s, 1); wPx = $x.Width; hPx = $x.Height }
        }
    }
    foreach ($u in @(Get-StepProp $step 'uiaRects' @())) {
        $el = Find-UiaElement ([string]$u) '' 800
        if ($el) { $meta.uia[[string]$u] = Get-UiaRect $el }
    }
    # "uiaAll": every UI Automation element of the player's windows with a rectangle (logical px
    # in the client area), for the measured checks against the Figma spec in compare.py
    $meta.public = [bool]$script:PublicBuild
    if ([bool](Get-StepProp $step 'uiaAll' $false)) { $meta.uiaAll = @(Get-UiaRects) }
    [void]$ctx.Shots.Add($meta)
    Write-VLog ("    shot {0} ({1}, {2}x{3})" -f $name, $shot.Method, $c.Width, $c.Height)
}

# automatic behaviour check through UI Automation: element present / absent / on screen, or a
# slider value; the result is recorded, a failing check marks the row "differs"
function Test-Expectation($step, $ctx) {
    $e = $step.expect
    $desc = [string](Get-StepProp $step 'check' (Format-Step $e))
    $el = Find-UiaElement ([string]$e.uia) ([string](Get-StepProp $e 'role' '')) ([int](Get-StepProp $e 'timeout' 1500)) ([string](Get-StepProp $e 'match' 'exact'))
    $ok = $true; $why = ''
    $visible = $false
    if ($el) { try { $visible = (-not $el.Current.IsOffscreen) -and (-not $el.Current.BoundingRectangle.IsEmpty) } catch {} }
    if ($e.PSObject.Properties['present']) {
        if ([bool]$e.present -ne [bool]$el) { $ok = $false; $why = "present=$([bool]$el)" }
    }
    if ($e.PSObject.Properties['visible']) {
        if ([bool]$e.visible -ne $visible) { $ok = $false; $why = "visible=$visible" }
    }
    if (($e.PSObject.Properties['value'] -or $e.PSObject.Properties['name']) -and -not $el) { $ok = $false; $why = 'element not found' }
    if ($e.PSObject.Properties['value'] -and $el) {
        $v = Get-UiaValue $el
        $tol = [double](Get-StepProp $e 'tol' 0.001)
        if (-not $v -or [math]::Abs([double]$v.Value - [double]$e.value) -gt $tol) { $ok = $false; $why = "value=$($v.Value)" }
    }
    if ($e.PSObject.Properties['name'] -and $el) {
        if ($el.Current.Name -notlike [string]$e.name) { $ok = $false; $why = "name='$($el.Current.Name)'" }
    }
    [void]$ctx.Checks.Add([ordered]@{ check = $desc; pass = $ok; detail = $why })
    Write-VLog ("    check {0}: {1} {2}" -f $desc, $(if ($ok) { 'pass' } else { 'FAIL' }), $why)
}

# sets the player volume (1.0 = 100 %) with the mouse wheel over the volume slider, read back
# through the "Volume" slider; the first change remembers the profile's volume so Restore-PlayerVolume can put it back
$script:OrigVolume = $null
function Set-PlayerVolume([double]$target, $ctx) {
    $el = Find-UiaElement 'Volume' 'Slider' 2000
    if (-not $el) { throw "Volume slider not found" }
    $v = (Get-UiaValue $el).Value
    if ($null -eq $script:OrigVolume) { $script:OrigVolume = $v }
    for ($i = 0; $i -lt 80 -and [math]::Abs($v - $target) -gt 0.026; $i++) {
        $r = Get-UiaRect $el
        if (-not $r -or $r.offscreen) {
            # the bar may have faded: a small move in the middle of the window brings it back
            $m = Get-MainWindow; $s = Get-Scale $m.Handle; $cl = Get-ClientRect $m.Handle
            Wiggle-Mouse ($cl.Width / $s / 2) ($cl.Height / $s / 2); Start-Sleep -Milliseconds 400
            $el = Find-UiaElement 'Volume' 'Slider' 1000; $r = if ($el) { Get-UiaRect $el } else { $null }
            if (-not $r -or $r.offscreen) { throw "the volume slider is not on screen" }
        }
        Send-Wheel ($r.x + $r.w / 2) ($r.y + $r.h / 2) $(if ($v -gt $target) { -120 } else { 120 })
        Start-Sleep -Milliseconds 120
        $el = Find-UiaElement 'Volume' 'Slider' 1000; $v = (Get-UiaValue $el).Value
    }
    if ($ctx) { [void]$ctx.Notes.Add(("volume {0:N2} (asked {1:N2})" -f $v, $target)) }
}
function Restore-PlayerVolume {
    if ($null -eq $script:OrigVolume) { return }
    try { Set-PlayerVolume $script:OrigVolume $null; Write-VLog ("  volume restored to {0:N2}" -f $script:OrigVolume) } catch { Write-VLog "  volume not restored: $($_.Exception.Message)" }
    $script:OrigVolume = $null
}
# all UIA elements with an on-screen rectangle: {n name, t type, x, y, w, h} in client logical px
function Get-UiaRects {
    $m = Get-MainWindow; $sc = Get-Scale $m.Handle; $cl = Get-ClientRect $m.Handle
    $out = New-Object System.Collections.ArrayList
    foreach ($w in (Get-PlayerWindows)) {
        if ($w.Class -eq 'Static') { continue }
        try { $root = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle) } catch { continue }
        $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $all) {
            try {
                $cur = $el.Current; $r = $cur.BoundingRectangle
                if ($r.IsEmpty -or $r.Width -le 0 -or $cur.IsOffscreen) { continue }
                [void]$out.Add([ordered]@{ n = $cur.Name; t = $cur.ControlType.ProgrammaticName.Replace('ControlType.', '')
                    x = [math]::Round(($r.X - $cl.Left) / $sc, 1); y = [math]::Round(($r.Y - $cl.Top) / $sc, 1)
                    w = [math]::Round($r.Width / $sc, 1); h = [math]::Round($r.Height / $sc, 1) })
            } catch {}
        }
    }
    return $out.ToArray()
}

# per-media / per-session values of the design's demo state (demo_state.json, how = "ui"): set
# through the UI before the screen is compared; each value set (or not) is noted in the run
function Set-DemoState([string]$screen, $ctx) {
    if (-not $script:Demo) { [void]$ctx.Notes.Add("demo ${screen}: demo_state.json missing"); return }
    $scr = $script:Demo.screens.$screen
    if (-not $scr) { return }
    foreach ($v in @($scr.values)) {
        if ($v.how -ne 'ui' -or -not $v.uia) { continue }
        $role = if ($v.uia.PSObject.Properties['role']) { [string]$v.uia.role } else { '' }
        $match = if ($v.uia.PSObject.Properties['match']) { [string]$v.uia.match } else { 'exact' }
        $el = Find-UiaElement ([string]$v.uia.name) $role 2000 $match
        if (-not $el) { [void]$ctx.Notes.Add("demo ${screen}: '$($v.label)' not set (control '$($v.uia.name)' not found)"); continue }
        try {
            if ($role -eq 'Edit' -or $v.PSObject.Properties['input']) {
                $text = if ($v.PSObject.Properties['input']) { [string]$v.input } else { [string]$v.figma }
                Invoke-UiaElement $el | Out-Null; Start-Sleep -Milliseconds 250
                Send-Keys '^a'; Send-Keys ($text.Replace('+', '{+}').Replace('%', '{%}').Replace('^', '{^}')); Send-Keys '{ENTER}'
                Start-Sleep -Milliseconds 400
                [void]$ctx.Notes.Add("demo ${screen}: $($v.label) = $($v.figma) (typed '$text' into '$($v.uia.name)')")
            } else {
                Invoke-UiaElement $el | Out-Null; Start-Sleep -Milliseconds 400
                [void]$ctx.Notes.Add("demo ${screen}: $($v.label) = $($v.figma) (clicked '$($v.uia.name)')")
            }
        } catch { [void]$ctx.Notes.Add("demo ${screen}: '$($v.label)' not set: $($_.Exception.Message)") }
    }
}
