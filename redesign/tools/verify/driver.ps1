# Player driver for the verification harness (dot-sourced by verify.ps1 and probe.ps1).
# Windows PowerShell 5.1. Everything here acts only on player processes this script started
# itself (kept as process objects with an open handle, so their ids cannot be reused by another
# program), never on any other window or process.
#
# Safety rules (see README.md):
# - input (keys, mouse) is sent only while a window of a started player is the foreground
#   window; mouse buttons and the wheel additionally only while the pointer is exactly on the
#   target point and the window under it belongs to a started player; keys are sent one token at
#   a time, each behind the guard; otherwise the driver waits and retries, and gives up without
#   sending anything
# - the player is only brought to the front while the user is not using the keyboard or mouse
# - screenshots capture only windows of a started player (PrintWindow of that window; the screen
#   area of that window only when every sampled point of it shows a window of the player)
# - Stop-Players closes every player process the run started and reports any left over

Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes

if (-not ('RdVerifyWin2' -as [type])) {
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class RdVerifyWin2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
  [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
}
"@
}
# physical pixels everywhere (per-monitor v2, fallback system aware): window rects, cursor
# positions and captures then use the same unit
try { if (-not [RdVerifyWin2]::SetProcessDpiAwarenessContext([IntPtr](-4))) { [RdVerifyWin2]::SetProcessDPIAware() | Out-Null } } catch { [RdVerifyWin2]::SetProcessDPIAware() | Out-Null }

$script:StartedProcs = New-Object System.Collections.ArrayList   # process objects (open handles)
$script:StartedPids = New-Object System.Collections.Generic.List[int]   # ids of the live ones
$script:StuckPids = @()
$script:GuardRetrySec = 60
$script:LastInjectTick = 0
$script:UserIdleMs = 1500
$script:Log = { param($m) Write-Host $m }

function Write-VLog([string]$m) { & $script:Log $m }

# --- processes -----------------------------------------------------------------------------
# keeps $script:StartedPids to the started processes that are still running
function Update-Started {
    $script:StartedPids.Clear()
    foreach ($p in $script:StartedProcs) {
        try {
            if (-not $p.HasExited) { $script:StartedPids.Add($p.Id); continue }
            # Cone builds can report "exited" while the process stays listed with one thread
            # (stuck in termination): still count it, so the cleanup reports it
            $q = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
            if ($q -and $q.StartTime -eq $p.StartTime) { $script:StartedPids.Add($p.Id) }
        } catch {}
    }
}
function Test-NoWindow([int]$procId) {
    $script:nw = $true
    [RdVerifyWin2]::EnumWindows({ param($h, $x)
        $q = [uint32]0; [RdVerifyWin2]::GetWindowThreadProcessId($h, [ref]$q) | Out-Null
        if ([int]$q -eq $procId -and [RdVerifyWin2]::IsWindowVisible($h)) { $script:nw = $false }
        return $true }, [IntPtr]::Zero) | Out-Null
    return $script:nw
}
# other players from the builds folder (builds\*: the fixed test folders and downloaded runs) that this run did not start (the
# main session's manual tests). A process without any visible window that started more than a
# minute ago is stuck in termination, not a running player, and is skipped; "ignorePids" only
# count while they have no window.
function Get-ForeignTestPlayers([string]$buildsDir, [int[]]$ignorePids) {
    Update-Started
    @(Get-Process vlc, Cone -ErrorAction SilentlyContinue | Where-Object {
        $p = $null; try { $p = $_.Path } catch {}
        $proc = $_
        if (-not $p -or -not $p.StartsWith($buildsDir.TrimEnd([char]92) + [char]92, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($script:StartedPids -contains $proc.Id) { return $false }
        $noWin = Test-NoWindow $proc.Id
        if ($noWin -and (($ignorePids -contains $proc.Id) -or ($script:StuckPids -contains $proc.Id))) { return $false }
        $old = $false; try { $old = $proc.StartTime -lt (Get-Date).AddMinutes(-1) } catch {}
        -not ($noWin -and $old) })
}
function Get-WindowInfo([IntPtr]$h) {
    $t = New-Object System.Text.StringBuilder 512; [RdVerifyWin2]::GetWindowText($h, $t, 512) | Out-Null
    $c = New-Object System.Text.StringBuilder 256; [RdVerifyWin2]::GetClassName($h, $c, 256) | Out-Null
    $q = [uint32]0; [RdVerifyWin2]::GetWindowThreadProcessId($h, [ref]$q) | Out-Null
    $r = Get-VisibleRect $h
    [pscustomobject]@{ Handle = $h; Title = $t.ToString(); Class = $c.ToString(); Pid = [int]$q;
        Left = $r.Left; Top = $r.Top; Width = $r.Right - $r.Left; Height = $r.Bottom - $r.Top }
}
# the visible frame (DWM extended frame bounds: without the invisible resize borders)
function Get-VisibleRect([IntPtr]$h) {
    $r = New-Object RdVerifyWin2+RECT
    $hr = [RdVerifyWin2]::DwmGetWindowAttribute($h, 9, [ref]$r, 16)
    if ($hr -ne 0) { [RdVerifyWin2]::GetWindowRect($h, [ref]$r) | Out-Null }
    return $r
}
# every visible top-level window of the started players
function Get-PlayerWindows {
    Update-Started
    $script:wins = New-Object System.Collections.ArrayList
    $ids = @($script:StartedPids)
    if ($ids.Count -eq 0) { return @() }
    [RdVerifyWin2]::EnumWindows({ param($h, $x)
        $q = [uint32]0; [RdVerifyWin2]::GetWindowThreadProcessId($h, [ref]$q) | Out-Null
        if ($ids -contains [int]$q -and [RdVerifyWin2]::IsWindowVisible($h)) { [void]$script:wins.Add((Get-WindowInfo $h)) }
        return $true }, [IntPtr]::Zero) | Out-Null
    return $script:wins.ToArray()
}
# the player's main window: the largest visible window titled "... - Cone" / "... VLC media player"
# (Qt keeps a hidden dummy window and short-lived tooltip windows; both are skipped)
function Get-MainWindow([int]$timeoutSec = 10) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    do {
        $best = $null
        foreach ($w in (Get-PlayerWindows)) {
            if (($w.Title -like '*Cone*' -or $w.Title -like '*VLC media player*') -and $w.Width -ge 400 -and $w.Height -ge 300) {
                if (-not $best -or ($w.Width * $w.Height) -gt ($best.Width * $best.Height)) { $best = $w }
            }
        }
        if ($best) { return $best }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $end)
    throw "player window not found"
}
function Get-Scale([IntPtr]$h) { $d = [RdVerifyWin2]::GetDpiForWindow($h); if ($d -le 0) { $d = 96 }; return $d / 96.0 }
# the client area (the Qt Quick content) in screen pixels
function Get-ClientRect([IntPtr]$h) {
    $r = New-Object RdVerifyWin2+RECT; [RdVerifyWin2]::GetClientRect($h, [ref]$r) | Out-Null
    $p = New-Object RdVerifyWin2+POINT; [RdVerifyWin2]::ClientToScreen($h, [ref]$p) | Out-Null
    return [pscustomobject]@{ Left = $p.X; Top = $p.Y; Width = $r.Right; Height = $r.Bottom }
}

# --- foreground guard ----------------------------------------------------------------------
function Test-PlayerPid([IntPtr]$h) {
    $q = [uint32]0; [RdVerifyWin2]::GetWindowThreadProcessId($h, [ref]$q) | Out-Null
    return ($script:StartedPids -contains [int]$q)
}
function Test-PlayerForeground { Update-Started; return (Test-PlayerPid ([RdVerifyWin2]::GetForegroundWindow())) }
# the top-level window under a screen point belongs to a started player
function Test-PlayerAt([int]$x, [int]$y) {
    $pt = New-Object RdVerifyWin2+POINT; $pt.X = $x; $pt.Y = $y
    $h = [RdVerifyWin2]::WindowFromPoint($pt)
    if ($h -eq [IntPtr]::Zero) { return $false }
    return (Test-PlayerPid ([RdVerifyWin2]::GetAncestor($h, 2)))
}
# true while the user is using the keyboard or mouse: input newer than the driver's own last
# injection and less than UserIdleMs old
function Test-UserActive {
    $l = New-Object RdVerifyWin2+LASTINPUTINFO; $l.cbSize = 8
    [RdVerifyWin2]::GetLastInputInfo([ref]$l) | Out-Null
    $now = [uint32]([Environment]::TickCount -band 0x7fffffff)
    $last = [uint32]($l.dwTime -band 0x7fffffff)
    $sinceInput = ($now - $last) -band 0x7fffffff
    $afterOurs = (($last - [uint32]$script:LastInjectTick) -band 0x7fffffff)
    return ($sinceInput -lt $script:UserIdleMs -and $afterOurs -gt 300 -and $afterOurs -lt 0x40000000)
}
function Set-Injected { $script:LastInjectTick = [Environment]::TickCount -band 0x7fffffff }
# brings the main window to the front; sends nothing when a player window is already in front or
# while the user is using the PC. Windows only lets the process that received the last input take
# the foreground: the driver injects one press of an unassigned virtual key (0x97, reserved as
# "unassigned" in winuser.h) instead of the usual Alt tap, which could open a menu bar
function Invoke-FocusPlayer([IntPtr]$h) {
    if (Test-PlayerForeground) { return $true }
    if (Test-UserActive) { return $false }
    $fg = [RdVerifyWin2]::GetForegroundWindow()
    $t1 = [RdVerifyWin2]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
    $t2 = [RdVerifyWin2]::GetCurrentThreadId()
    [RdVerifyWin2]::AttachThreadInput($t2, $t1, $true) | Out-Null
    [RdVerifyWin2]::keybd_event(0x97, 0, 0, [IntPtr]::Zero); [RdVerifyWin2]::keybd_event(0x97, 0, 2, [IntPtr]::Zero)
    Set-Injected
    [RdVerifyWin2]::BringWindowToTop($h) | Out-Null
    [RdVerifyWin2]::SetForegroundWindow($h) | Out-Null
    [RdVerifyWin2]::AttachThreadInput($t2, $t1, $false) | Out-Null
    Start-Sleep -Milliseconds 200
    return (Test-PlayerForeground)
}
# the guard every input goes through: waits (and retries focusing the player while the user is
# idle) until a window of a started player is in front; throws without sending anything after
# GuardRetrySec
function Assert-Guard([switch]$NoFocus) {
    $end = (Get-Date).AddSeconds($script:GuardRetrySec); $warned = $false
    while ($true) {
        if (Test-PlayerForeground) { return }
        if (-not $NoFocus) { try { $m = Get-MainWindow 2; if (Invoke-FocusPlayer $m.Handle) { return } } catch {} }
        if ((Get-Date) -gt $end) { throw "GUARD: the player is not the foreground window; no input sent" }
        if (-not $warned) { Write-VLog "  guard: player not in front (or the PC is in use), waiting"; $warned = $true }
        Start-Sleep -Seconds 2
    }
}
# guard for a mouse button / wheel event at screen point (x, y)
function Assert-PointerTarget([int]$x, [int]$y) {
    $end = (Get-Date).AddSeconds($script:GuardRetrySec)
    while ($true) {
        Assert-Guard
        $p = New-Object RdVerifyWin2+POINT; [RdVerifyWin2]::GetCursorPos([ref]$p) | Out-Null
        if ($p.X -eq $x -and $p.Y -eq $y -and (Test-PlayerAt $x $y)) { return }
        if ((Get-Date) -gt $end) { throw "GUARD: the pointer is not on the player at $x,$y (moved, or another window covers it); no click sent" }
        Start-Sleep -Milliseconds 500
        if (-not (Test-UserActive)) { [RdVerifyWin2]::SetCursorPos($x, $y) | Out-Null; Set-Injected; Start-Sleep -Milliseconds 100 }
    }
}

# --- input ---------------------------------------------------------------------------------
# window-relative positions are logical pixels (Figma units) from the top-left of the main
# window's client area (the Qt Quick content)
function Convert-ToScreen([double]$x, [double]$y) {
    $m = Get-MainWindow; $s = Get-Scale $m.Handle; $c = Get-ClientRect $m.Handle
    return @([int][math]::Round($c.Left + $x * $s), [int][math]::Round($c.Top + $y * $s))
}
# SendKeys strings split into tokens ("^a", "{ENTER}", "+{TAB}", "x"), each sent behind the guard
function Split-SendKeys([string]$keys) {
    $tokens = New-Object System.Collections.ArrayList; $i = 0; $mods = ''
    while ($i -lt $keys.Length) {
        $ch = $keys[$i]
        if ('^+%'.Contains([string]$ch)) { $mods += $ch; $i++; continue }
        if ($ch -eq '{') {
            $j = $keys.IndexOf('}', $i + 2); if ($j -lt 0) { $j = $keys.Length - 1 }
            [void]$tokens.Add($mods + $keys.Substring($i, $j - $i + 1)); $i = $j + 1
        } elseif ($ch -eq '(') {
            $j = $keys.IndexOf(')', $i); if ($j -lt 0) { $j = $keys.Length - 1 }
            [void]$tokens.Add($mods + $keys.Substring($i, $j - $i + 1)); $i = $j + 1
        } else { [void]$tokens.Add($mods + $ch); $i++ }
        $mods = ''
    }
    return $tokens.ToArray()
}
function Send-Keys([string]$keys) {
    foreach ($t in (Split-SendKeys $keys)) { Assert-Guard; [System.Windows.Forms.SendKeys]::SendWait($t); Set-Injected }
}
function Move-Mouse([double]$x, [double]$y, [switch]$Screen) {
    Assert-Guard
    if ($Screen) { $p = @([int]$x, [int]$y) } else { $p = Convert-ToScreen $x $y }
    # another window over the target (a prompt, the taskbar): wait for it to go, never click it
    $end = (Get-Date).AddSeconds($script:GuardRetrySec); $warned = $false
    while (-not (Test-PlayerAt $p[0] $p[1])) {
        if ((Get-Date) -gt $end) { throw "GUARD: $($p[0]),$($p[1]) is not on the player (outside the window or covered); pointer not moved" }
        if (-not $warned) { Write-VLog "  guard: another window covers $($p[0]),$($p[1]); waiting"; $warned = $true }
        Start-Sleep -Seconds 2
    }
    [RdVerifyWin2]::SetCursorPos($p[0], $p[1]) | Out-Null; Set-Injected
    return , $p
}
# a small mouse move inside the window (bars appear on mouse movement)
function Wiggle-Mouse([double]$x, [double]$y) { Move-Mouse ($x + 6) $y | Out-Null; Start-Sleep -Milliseconds 60; Move-Mouse $x $y | Out-Null }
function Send-Click([double]$x, [double]$y, [string]$button = 'left', [int]$count = 1, [switch]$Screen) {
    $p = Move-Mouse $x $y -Screen:$Screen; Start-Sleep -Milliseconds 120
    if ($button -eq 'right') { $down = 0x0008; $up = 0x0010 } elseif ($button -eq 'middle') { $down = 0x0020; $up = 0x0040 } else { $down = 0x0002; $up = 0x0004 }
    for ($k = 0; $k -lt $count; $k++) {
        Assert-PointerTarget $p[0] $p[1]
        [RdVerifyWin2]::mouse_event($down, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 40
        [RdVerifyWin2]::mouse_event($up, 0, 0, 0, [IntPtr]::Zero); Set-Injected; Start-Sleep -Milliseconds 70
    }
}
function Send-Wheel([double]$x, [double]$y, [int]$delta) {
    $p = Move-Mouse $x $y; Start-Sleep -Milliseconds 100
    Assert-PointerTarget $p[0] $p[1]
    [RdVerifyWin2]::mouse_event(0x0800, 0, 0, [BitConverter]::ToUInt32([BitConverter]::GetBytes($delta), 0), [IntPtr]::Zero); Set-Injected
}
function Send-Drag([double]$x1, [double]$y1, [double]$x2, [double]$y2, [int]$steps = 30) {
    $p = Move-Mouse $x1 $y1; Start-Sleep -Milliseconds 120
    Assert-PointerTarget $p[0] $p[1]
    [RdVerifyWin2]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero); Set-Injected
    try {
        for ($k = 1; $k -le $steps; $k++) {
            if (-not (Test-PlayerForeground)) { throw "GUARD: the player lost the foreground; drag stopped" }
            $q = Convert-ToScreen ($x1 + ($x2 - $x1) * $k / $steps) ($y1 + ($y2 - $y1) * $k / $steps)
            if (-not (Test-PlayerAt $q[0] $q[1])) { throw "GUARD: the drag left the player window; drag stopped" }
            [RdVerifyWin2]::SetCursorPos($q[0], $q[1]) | Out-Null; Set-Injected; Start-Sleep -Milliseconds 30
        }
    } finally { [RdVerifyWin2]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero); Set-Injected }
}

# --- UI Automation -------------------------------------------------------------------------
# Qt Quick exposes Accessible.name / role through UIA; the lookup runs over every window of the
# started players (popups and dialogs can be separate top-level windows)
function Find-UiaElement([string]$name, [string]$role, [int]$timeoutMs = 3000, [string]$match = 'exact') {
    $ct = $null
    if ($role) { $ct = [System.Windows.Automation.ControlType]::($role) }
    $end = (Get-Date).AddMilliseconds($timeoutMs)
    do {
        foreach ($w in (Get-PlayerWindows)) {
            try { $root = [System.Windows.Automation.AutomationElement]::FromHandle($w.Handle) } catch { continue }
            if ($match -eq 'exact') {
                $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
                if ($ct) { $cond = New-Object System.Windows.Automation.AndCondition($cond, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ct))) }
                $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
                if ($el) { return $el }
            } else {
                $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
                foreach ($el in $all) {
                    $n = $el.Current.Name
                    if ($n -and $n -like "*$name*" -and (-not $ct -or $el.Current.ControlType -eq $ct)) { return $el }
                }
            }
        }
        Start-Sleep -Milliseconds 150
    } while ((Get-Date) -lt $end)
    return $null
}
# clicks the element's centre with the mouse (keeps hover / press behaviour real); falls back to
# the Invoke pattern when the element has no on-screen rectangle
function Invoke-UiaElement($el, [string]$button = 'left') {
    $r = $el.Current.BoundingRectangle
    if (-not $r.IsEmpty -and $r.Width -gt 0 -and -not $el.Current.IsOffscreen) {
        Send-Click ($r.X + $r.Width / 2) ($r.Y + $r.Height / 2) $button 1 -Screen
        return 'mouse'
    }
    Assert-Guard
    $p = $null
    if ($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p)) { $p.Invoke(); return 'invoke' }
    throw "element '$($el.Current.Name)' is off screen and has no Invoke pattern"
}
# sets a slider (RangeValue pattern) or a text field (Value pattern) directly on the element
function Set-UiaValue($el, $value) {
    Assert-Guard
    $p = $null
    if ($el.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$p)) {
        $min = $p.Current.Minimum; $max = $p.Current.Maximum
        try { $p.SetValue([double]$value) } catch { throw "RangeValue.SetValue($value) failed on '$($el.Current.Name)' (range $min..$max, read-only $($p.Current.IsReadOnly)): $($_.Exception.InnerException.Message)" }
        return "range $min..$max -> $value"
    }
    if ($el.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$p)) { $p.SetValue([string]$value); return "value -> $value" }
    throw "element '$($el.Current.Name)' has no RangeValue or Value pattern"
}
function Get-UiaValue($el) {
    $p = $null
    if ($el.TryGetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern, [ref]$p)) { return [pscustomobject]@{ Value = $p.Current.Value; Min = $p.Current.Minimum; Max = $p.Current.Maximum } }
    if ($el.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$p)) { return [pscustomobject]@{ Value = $p.Current.Value } }
    return $null
}
# element rectangle in logical pixels relative to the main window's client area
function Get-UiaRect($el) {
    $r = $el.Current.BoundingRectangle
    if ($r.IsEmpty) { return $null }
    $m = Get-MainWindow; $s = Get-Scale $m.Handle; $c = Get-ClientRect $m.Handle
    return [pscustomobject]@{ x = [math]::Round(($r.X - $c.Left) / $s, 1); y = [math]::Round(($r.Y - $c.Top) / $s, 1); w = [math]::Round($r.Width / $s, 1); h = [math]::Round($r.Height / $s, 1); offscreen = $el.Current.IsOffscreen }
}
function Get-UiaTree([int]$maxDepth = 12) {
    $out = New-Object System.Collections.Generic.List[string]
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    function Walk($el, $d) {
        if ($d -gt $maxDepth) { return }
        try {
            $c = $el.Current; $r = $c.BoundingRectangle
            $rect = if ($r.IsEmpty) { '-' } else { '{0},{1} {2}x{3}' -f [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height }
            $out.Add(('{0}{1} "{2}" [{3}] {4}' -f ('  ' * $d), $c.ControlType.ProgrammaticName.Replace('ControlType.', ''), $c.Name, $c.ClassName, $rect))
        } catch { return }
        $ch = $walker.GetFirstChild($el)
        while ($ch) { Walk $ch ($d + 1); $ch = $walker.GetNextSibling($ch) }
    }
    foreach ($w in (Get-PlayerWindows)) {
        $out.Add("WINDOW '$($w.Title)' class=$($w.Class) $($w.Left),$($w.Top) $($w.Width)x$($w.Height)")
        try { Walk ([System.Windows.Automation.AutomationElement]::FromHandle($w.Handle)) 1 } catch { $out.Add("  (no UIA: $_)") }
    }
    return $out
}

# --- capture -------------------------------------------------------------------------------
# one window only: PrintWindow with PW_RENDERFULLCONTENT renders the window's own content (no
# other window or desktop pixel can end up in the image). If that comes back black, the screen
# area of that window is copied, but only while the player is in front and every sampled point of
# the area (every 24 px) shows a window of the player; otherwise the shot fails.
# -Client keeps only the client area (the main window's Qt Quick content, without the 1 px
# frame Windows draws around the frameless window)
function Save-WindowShot([IntPtr]$h, [string]$out, [switch]$Client) {
    $wr = New-Object RdVerifyWin2+RECT; [RdVerifyWin2]::GetWindowRect($h, [ref]$wr) | Out-Null
    if ($Client) { $c = Get-ClientRect $h; $r = [pscustomobject]@{ Left = $c.Left; Top = $c.Top; Right = $c.Left + $c.Width; Bottom = $c.Top + $c.Height } }
    else { $r = Get-VisibleRect $h }
    $w = $wr.Right - $wr.Left; $ht = $wr.Bottom - $wr.Top
    $bmp = New-Object System.Drawing.Bitmap $w, $ht
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
    $ok = [RdVerifyWin2]::PrintWindow($h, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    $cx = $r.Left - $wr.Left; $cy = $r.Top - $wr.Top; $cw = $r.Right - $r.Left; $ch = $r.Bottom - $r.Top
    $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch), $bmp.PixelFormat)
    $bmp.Dispose()
    $method = 'printwindow'
    if (-not $ok -or (Test-BlankBitmap $crop)) {
        $crop.Dispose()
        Assert-Guard -NoFocus
        for ($y = $r.Top; $y -lt $r.Bottom; $y += 24) { for ($x = $r.Left; $x -lt $r.Right; $x += 24) {
            if (-not (Test-PlayerAt $x $y)) { throw "capture refused: PrintWindow failed and $x,$y of the player area shows another window" } } }
        $crop = New-Object System.Drawing.Bitmap $cw, $ch
        $g = [System.Drawing.Graphics]::FromImage($crop); $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $crop.Size); $g.Dispose()
        $method = 'screen'
    }
    $crop.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $crop.Dispose()
    return [pscustomobject]@{ Path = $out; Left = $r.Left; Top = $r.Top; Width = $cw; Height = $ch; Method = $method }
}
# PrintWindow failures come back black (or transparent); a flat video picture is not blank
function Test-BlankBitmap($bmp) {
    foreach ($fx in 0.02, 0.25, 0.5, 0.75, 0.98) { foreach ($fy in 0.02, 0.25, 0.5, 0.75, 0.98) {
        $p = $bmp.GetPixel([int](($bmp.Width - 1) * $fx), [int](($bmp.Height - 1) * $fy))
        if ($p.A -gt 0 -and ($p.R -gt 6 -or $p.G -gt 6 -or $p.B -gt 6)) { return $false } } }
    return $true
}

# --- launch and quit -----------------------------------------------------------------------
# Start-Player creates <build>\portable when it is missing (portable mode: the player keeps its
# settings there instead of the user's real profile)
function Start-Player([string]$exe, [string[]]$playerArgs) {
    New-Item -ItemType Directory -Force (Join-Path (Split-Path $exe) 'portable') | Out-Null
    $p = Start-Process -FilePath $exe -ArgumentList $playerArgs -WorkingDirectory (Split-Path $exe) -PassThru
    $null = $p.Handle   # keeps the process handle open: its id cannot be reused while we track it
    [void]$script:StartedProcs.Add($p)
    Update-Started
    $m = Get-MainWindow 30
    # VLC's "closed abruptly" prompt (after an earlier forced close) asks to restore the old
    # playlist: answer "No" through UI Automation (Invoke goes to that button only, no
    # keyboard or mouse input)
    $end = (Get-Date).AddSeconds(4)
    while ((Get-Date) -lt $end) {
        $prompt = Get-PlayerWindows | Where-Object { $_.Title -like '*closed abruptly*' } | Select-Object -First 1
        if ($prompt) {
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($prompt.Handle)
            $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'No')
            $no = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
            $ip = $null
            if ($no -and $no.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$ip)) { $ip.Invoke(); Write-VLog '  dismissed the "closed abruptly" prompt (No)' }
            Start-Sleep -Milliseconds 500; break
        }
        Start-Sleep -Milliseconds 250
    }
    return (Get-MainWindow 10)
}
# sets the client area (the Qt Quick content) to the given size in logical pixels, with its
# top-left corner at the top-left of the monitor's work area (the 1 px window frame goes just off
# it); refuses when the client would not fit the work area (taskbar or other windows could then
# sit over the targets)
function Set-PlayerSize([double]$w, [double]$h) {
    $m = Get-MainWindow
    if ([RdVerifyWin2]::IsZoomed($m.Handle)) { [RdVerifyWin2]::ShowWindow($m.Handle, 9) | Out-Null; Start-Sleep -Milliseconds 300 }
    $mi = New-Object RdVerifyWin2+MONITORINFO; $mi.cbSize = 40
    [RdVerifyWin2]::GetMonitorInfo([RdVerifyWin2]::MonitorFromWindow($m.Handle, 2), [ref]$mi) | Out-Null
    $work = $mi.rcWork
    for ($i = 0; $i -lt 3; $i++) {
        $s = Get-Scale $m.Handle
        $pw = [int][math]::Round($w * $s); $ph = [int][math]::Round($h * $s)
        if ($pw -gt ($work.Right - $work.Left) -or $ph -gt ($work.Bottom - $work.Top)) { throw "a $w x $h client ($pw x $ph px) does not fit the monitor's work area ($($work.Right - $work.Left) x $($work.Bottom - $work.Top) px)" }
        $wr = New-Object RdVerifyWin2+RECT; [RdVerifyWin2]::GetWindowRect($m.Handle, [ref]$wr) | Out-Null
        $c = Get-ClientRect $m.Handle
        $bl = $c.Left - $wr.Left; $bt = $c.Top - $wr.Top
        $br = $wr.Right - ($c.Left + $c.Width); $bb = $wr.Bottom - ($c.Top + $c.Height)
        [RdVerifyWin2]::MoveWindow($m.Handle, $work.Left - $bl, $work.Top - $bt, $pw + $bl + $br, $ph + $bt + $bb, $true) | Out-Null
        Start-Sleep -Milliseconds 400
        $c = Get-ClientRect $m.Handle
        if ($c.Width -eq $pw -and $c.Height -eq $ph -and $c.Left -eq $work.Left -and $c.Top -eq $work.Top) { return (Get-MainWindow) }
    }
    throw "the player window could not be sized to $w x $h (client is $($c.Width) x $($c.Height) px at $($c.Left),$($c.Top))"
}
# graceful quit: Escape x2 + Ctrl+Q while the player is in front, then WM_CLOSE to its windows;
# a started process still alive after that is ended (only processes this run started)
function Stop-Players([int]$waitSec = 10, [switch]$NoKeys) {
    $alive = { Update-Started; @($script:StartedPids) }
    if (@(& $alive).Count -eq 0) { $script:StartedProcs.Clear(); return 'none running' }
    if (-not $NoKeys) {
        try {
            $m = Get-MainWindow 2
            if (Invoke-FocusPlayer $m.Handle) {
                foreach ($k in '{ESC}', '{ESC}', '^q') {
                    if (-not (Test-PlayerForeground)) { break }
                    [System.Windows.Forms.SendKeys]::SendWait($k); Set-Injected; Start-Sleep -Milliseconds 250
                }
            }
        } catch {}
    }
    $end = (Get-Date).AddSeconds($waitSec)
    while (@(& $alive).Count -gt 0 -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 300 }
    $how = 'ctrl+q'
    if (@(& $alive).Count -gt 0) {
        foreach ($w in (Get-PlayerWindows)) { [RdVerifyWin2]::PostMessage($w.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
        $end = (Get-Date).AddSeconds($waitSec)
        while (@(& $alive).Count -gt 0 -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 300 }
        $how = 'close message'
    }
    # a process that still shows a window is hung: end it (only processes this run started). One
    # without any window is already terminating (Cone builds can stick there with one thread):
    # it is never touched, only reported
    if (@(& $alive).Count -gt 0 -and @(Get-PlayerWindows | Where-Object { $_.Class -ne 'Static' }).Count -gt 0) {
        foreach ($p in $script:StartedProcs) { try { if (-not $p.HasExited -and -not (Test-NoWindow $p.Id)) { $p.Kill() } } catch {} }
        Start-Sleep -Seconds 2
        $how = 'ended (hung with a window)'
    }
    $left = @(& $alive)
    if ($left.Count -gt 0) {
        # a process that has no window left and does not exit is stuck in termination (seen on
        # Cone builds: one thread left); it takes no input, so the run goes on, and the report
        # lists it as a finding
        $withWindows = @(Get-PlayerWindows | Where-Object { $_.Class -ne 'Static' })
        if ($withWindows.Count -eq 0) {
            foreach ($id in $left) { $script:StuckPids += $id }
            $script:StartedProcs.Clear(); $script:StartedPids.Clear()
            return "STUCK in termination, no window ($how): pid $($left -join ', ')"
        }
        return "STILL RUNNING: $($left -join ', ')"
    }
    $script:StartedProcs.Clear(); $script:StartedPids.Clear()
    return "closed ($how)"
}
