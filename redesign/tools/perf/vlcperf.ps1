# Performance round for one VLC build (stock or redesign), portable mode, same media.
#
#   powershell -File vlcperf.ps1 -Build <build dir> -Kind stock|redesign -Out <results.json> [-Only a,b]
#
# Scenarios (names usable with -Only):
#   startup   3 launches without media: launch -> main window shown (ms)
#   open      3 launches with the test video: launch -> first video frame on screen (ms)
#   play      test video playing windowed 15 s: CPU %, RAM, GPU 3D / video decode %
#   idle      paused on the player 10 s
#   panel     side panel open while playing 10 s (redesign: settings sidebar; stock: playlist)
#   seek      seeking forward every 0.7 s for 10 s
#   motion    UI smoothness from 120 fps Desktop Duplication captures on a paused video:
#             hover sweep over the control bar, seek bar drag, volume drag, panel open, panel close
#   4k        4K 60 fps 80 Mbit/s file windowed and fullscreen, 20 s each: frames displayed / lost
#             (VLC's own statistics through the cli interface on 127.0.0.1), CPU, GPU
#   queue     520-item queue: panel open latency and scrolling smoothness
# Window: 2400x1350 physical at 0,0 (1920x1080 logical at 125 %). Captures stay in the out folder
# (they show the screen; never commit them).
param(
    [Parameter(Mandatory)][string]$Build,
    [Parameter(Mandatory)][ValidateSet('stock', 'redesign')][string]$Kind,
    [Parameter(Mandatory)][string]$Out,
    [string[]]$Only = @()
)
$ErrorActionPreference = 'Stop'
# -File passes "a,b" as one string
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Media ='<TEST_MEDIA_DIR>\<TEST_VIDEO>'
$Media4k = '<WORK_DIR>\perfmedia\4k60_80mbps.mp4'
$Queue = '<WORK_DIR>\perfmedia\queue500.m3u'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutDir = Split-Path -Parent $Out
New-Item -ItemType Directory -Force $OutDir | Out-Null
$RcPort = 42120

Add-Type -AssemblyName System.Windows.Forms
if (-not ('RdPerf' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RdPerf {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
}
"@
}
[RdPerf]::SetProcessDPIAware() | Out-Null

# control positions (window pixels) per build
$P = @{
    redesign = @{ barY = 1306; seekX0 = 320; seekX1 = 1920; seekY = 1306; volX0 = 2105; volX1 = 2195; volY = 1306
                  panelBtn = @(2310, 1306); queueBtn = @(2352, 1306); panelRoi = '1855,55,520,1215'; barRoi = '0,1270,2400,75' }
    stock    = @{ barY = 1290; seekX0 = 60; seekX1 = 2340; seekY = 1238; volX0 = 2130; volX1 = 2250; volY = 1290
                  panelBtn = @(2358, 64); queueBtn = @(2358, 64); panelRoi = '1500,90,900,1120'; barRoi = '0,1200,2400,150' }
}[$Kind]

$Results = [ordered]@{ kind = $Kind; build = $Build; date = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
function Want($name) { return ($Only.Count -eq 0) -or ($Only -contains $name) }
function Exe { return (Get-ChildItem $Build -Recurse -Filter vlc.exe | Select-Object -First 1) }
function LogPath { return (Join-Path $Build 'vlc-perf-log.txt') }

function Get-Win($proc) {
    for ($i = 0; $i -lt 200; $i++) {
        $proc.Refresh()
        if ($proc.HasExited) { throw 'VLC exited' }
        $h = $proc.MainWindowHandle
        if ($h -ne 0) {
            $r = New-Object RdPerf+RECT; [RdPerf]::GetWindowRect($h, [ref]$r) | Out-Null
            if (($r.Right - $r.Left) -ge 400) { return $h }
        }
        Start-Sleep -Milliseconds 25
    }
    throw 'no window'
}
function Focus($h) {
    $fg = [RdPerf]::GetForegroundWindow()
    if ($fg -eq $h) { return }
    $t1 = [RdPerf]::GetWindowThreadProcessId($fg, [IntPtr]::Zero); $t2 = [RdPerf]::GetCurrentThreadId()
    [RdPerf]::AttachThreadInput($t2, $t1, $true) | Out-Null
    [RdPerf]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0003) | Out-Null
    [RdPerf]::BringWindowToTop($h) | Out-Null; [RdPerf]::SetForegroundWindow($h) | Out-Null
    [RdPerf]::AttachThreadInput($t2, $t1, $false) | Out-Null
    Start-Sleep -Milliseconds 150
    if ([RdPerf]::GetForegroundWindow() -ne $h) { throw 'VLC is not the foreground window; no input sent' }
}
function Start-Vlc([string]$media, [switch]$Rc) {
    $exe = Exe
    New-Item -ItemType Directory -Force (Join-Path $exe.DirectoryName 'portable') | Out-Null
    Remove-Item (LogPath) -ErrorAction SilentlyContinue
    $a = @('--no-qt-privacy-ask', '--no-qt-updates-notif', '--no-qt-video-autoresize', '--loop',
           '--file-logging', "--logfile=`"$(LogPath)`"", '--log-verbose=2')
    if ($Rc) { $a += @('--extraintf=cli', "--rc-host=127.0.0.1:$RcPort") }
    if ($media) { $a += "`"$media`"" }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $exe.FullName -ArgumentList $a -WorkingDirectory $exe.DirectoryName -PassThru
    $h = Get-Win $p
    $tWin = $sw.ElapsedMilliseconds
    return @{ proc = $p; hwnd = $h; sw = $sw; tWin = $tWin }
}
function Place($v) {
    [RdPerf]::MoveWindow($v.hwnd, 0, 0, 2400, 1350, $true) | Out-Null
    Focus $v.hwnd
}
function Stop-Vlc($v) {
    if (-not $v) { return }
    try { $v.proc.CloseMainWindow() | Out-Null } catch {}
    if (-not $v.proc.WaitForExit(5000)) { try { $v.proc.Kill() } catch {} ; $v.proc.WaitForExit(3000) | Out-Null }
}
function Wait-Log([string]$pattern, $sw, [int]$timeoutMs = 20000) {
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        $l = LogPath
        if (Test-Path $l) {
            $hit = Select-String -Path $l -Pattern $pattern -SimpleMatch -Quiet -ErrorAction SilentlyContinue
            if ($hit) { return $sw.ElapsedMilliseconds }
        }
        Start-Sleep -Milliseconds 20
    }
    return $null
}
Add-Type -AssemblyName System.Drawing
# launch -> the video is on screen: the centre of the window turns bright (the test video's
# first frames are a light Windows settings page; both players are dark before the video shows)
function Wait-Video($v, [int]$timeoutMs = 20000) {
    $bmp = New-Object System.Drawing.Bitmap 64, 64
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        while ($v.sw.ElapsedMilliseconds -lt $timeoutMs) {
            $r = New-Object RdPerf+RECT; [RdPerf]::GetWindowRect($v.hwnd, [ref]$r) | Out-Null
            $cx = [int](($r.Left + $r.Right) / 2) - 32; $cy = [int](($r.Top + $r.Bottom) / 2) - 32
            $g.CopyFromScreen($cx, $cy, 0, 0, $bmp.Size)
            $sum = 0
            for ($y = 0; $y -lt 64; $y += 8) { for ($x = 0; $x -lt 64; $x += 8) { $sum += $bmp.GetPixel($x, $y).GetBrightness() } }
            if ($sum / 64 -gt 0.6) { return $v.sw.ElapsedMilliseconds }
            Start-Sleep -Milliseconds 30
        }
        return $null
    } finally { $g.Dispose(); $bmp.Dispose() }
}
function Move($x, $y) { [RdPerf]::SetCursorPos($x, $y) | Out-Null }
function Down { [RdPerf]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero) }
function Up { [RdPerf]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero) }
function Click($x, $y) { Move $x $y; Start-Sleep -Milliseconds 30; Down; Start-Sleep -Milliseconds 40; Up }
function Wheel($n) { [RdPerf]::mouse_event(0x0800, 0, 0, $n, [IntPtr]::Zero) }
function Key($k) { [System.Windows.Forms.SendKeys]::SendWait($k) }

function Sample($v, [int]$seconds) {
    $p = $v.proc; $p.Refresh()
    $cpu0 = $p.TotalProcessorTime; $t0 = Get-Date
    $priv = @(); $ws = @(); $g3d = @(); $gvd = @()
    $path = "\GPU Engine(pid_$($p.Id)_*)\Utilization Percentage"
    for ($i = 0; $i -lt $seconds; $i++) {
        $c = $null
        try { $c = Get-Counter -Counter $path -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop } catch { Start-Sleep 1 }
        if ($c) {
            $s = $c.CounterSamples
            $g3d += ($s | Where-Object { $_.InstanceName -like '*engtype_3d' } | Measure-Object CookedValue -Sum).Sum
            $gvd += ($s | Where-Object { $_.InstanceName -like '*engtype_videodecode' } | Measure-Object CookedValue -Sum).Sum
        }
        $p.Refresh(); $priv += $p.PrivateMemorySize64 / 1MB; $ws += $p.WorkingSet64 / 1MB
    }
    $p.Refresh()
    $wall = ((Get-Date) - $t0).TotalSeconds
    $cpu = ($p.TotalProcessorTime - $cpu0).TotalSeconds / $wall / [Environment]::ProcessorCount * 100
    return [ordered]@{
        cpu_pct = [math]::Round($cpu, 1)
        ram_private_mb = [math]::Round(($priv | Measure-Object -Average).Average, 0)
        ram_private_max_mb = [math]::Round(($priv | Measure-Object -Maximum).Maximum, 0)
        ram_ws_mb = [math]::Round(($ws | Measure-Object -Average).Average, 0)
        gpu_3d_pct = if ($g3d.Count) { [math]::Round(($g3d | Measure-Object -Average).Average, 1) } else { $null }
        gpu_videodecode_pct = if ($gvd.Count) { [math]::Round(($gvd | Measure-Object -Average).Average, 1) } else { $null }
    }
}

function Rc([string]$cmd) {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect('127.0.0.1', $RcPort)
    $s = $c.GetStream(); $s.ReadTimeout = 1500
    $w = New-Object IO.StreamWriter($s); $w.NewLine = "`n"; $w.AutoFlush = $true
    Start-Sleep -Milliseconds 300
    $buf = New-Object byte[] 65536
    while ($s.DataAvailable) { $null = $s.Read($buf, 0, $buf.Length) }
    $w.WriteLine($cmd)
    Start-Sleep -Milliseconds 600
    $text = ''
    while ($s.DataAvailable) { $n = $s.Read($buf, 0, $buf.Length); $text += [Text.Encoding]::UTF8.GetString($buf, 0, $n) }
    $c.Close()
    return $text
}
function Stats {
    $t = Rc 'stats'
    $d = [regex]::Match($t, 'frames displayed\s*:\s*(\d+)').Groups[1].Value
    $l = [regex]::Match($t, 'frames lost\s*:\s*(\d+)').Groups[1].Value
    return @{ displayed = [int]$d; lost = [int]$l }
}

# 120 fps Desktop Duplication capture of the window, only changed frames, at quarter size
function Capture([string]$name, [double]$seconds, [scriptblock]$action) {
    $file = Join-Path $OutDir "$Kind-$name.mkv"
    Remove-Item $file -ErrorAction SilentlyContinue
    $vf = "ddagrab=output_idx=0:framerate=120:dup_frames=0:draw_mouse=1:offset_x=0:offset_y=0:video_size=2400x1350,hwdownload,format=bgra,scale=600:338:flags=area"
    $ff = Start-Process ffmpeg -ArgumentList @('-v', 'error', '-y', '-filter_complex', $vf, '-fps_mode', 'passthrough',
          '-c:v', 'libx264rgb', '-preset', 'ultrafast', '-qp', '0', '-t', "$seconds", "`"$file`"") -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 900
    & $action
    $ff.WaitForExit(([int]$seconds + 10) * 1000) | Out-Null
    return $file
}
function Motion([string]$file, [string]$roi, [string]$cursor) {
    $j = & python -I (Join-Path $Here 'motion.py') $file $roi $cursor 4
    return ($j | ConvertFrom-Json)
}

# ---------------------------------------------------------------- scenarios
$v = $null
try {
    if (Want 'startup') {
        $runs = @()
        for ($i = 0; $i -lt 3; $i++) { $x = Start-Vlc ''; $runs += $x.tWin; Start-Sleep 2; Stop-Vlc $x; Start-Sleep 2 }
        $Results.startup_window_ms = $runs
    }
    if (Want 'open') {
        $runs = @()
        for ($i = 0; $i -lt 3; $i++) {
            $x = Start-Vlc $Media
            [RdPerf]::SetWindowPos($x.hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x0003) | Out-Null
            $runs += (Wait-Video $x)
            Start-Sleep 2; Stop-Vlc $x; Start-Sleep 2
        }
        $Results.open_video_ready_ms = $runs
    }
    if ((Want 'play') -or (Want 'idle') -or (Want 'panel') -or (Want 'seek') -or (Want 'motion')) {
        $v = Start-Vlc $Media; Start-Sleep 3; Place $v; Move 1200 700; Start-Sleep 2
        if (Want 'play') { Move 1200 700; $Results.play = Sample $v 15 }
        if (Want 'idle') { Key ' '; Start-Sleep 1; $Results.idle_paused = Sample $v 10; Key ' '; Start-Sleep 1 }
        if (Want 'panel') {
            Move 1300 900; Start-Sleep -Milliseconds 300; Click $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep 1
            $Results.panel_open_playing = Sample $v 10
            Click $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep 1
        }
        if (Want 'seek') {
            $t0 = Get-Date
            $v.proc.Refresh(); $c0 = $v.proc.TotalProcessorTime
            for ($i = 0; $i -lt 14; $i++) { Key '{RIGHT}'; Start-Sleep -Milliseconds 700 }
            $v.proc.Refresh()
            $Results.seek = [ordered]@{ cpu_pct = [math]::Round(($v.proc.TotalProcessorTime - $c0).TotalSeconds / ((Get-Date) - $t0).TotalSeconds / [Environment]::ProcessorCount * 100, 1);
                                       ram_private_mb = [math]::Round($v.proc.PrivateMemorySize64 / 1MB, 0) }
        }
        if (Want 'motion') {
            Key ' '; Start-Sleep 1   # pause: only the UI changes on screen
            $m = [ordered]@{}
            # hover sweep along the control bar, 2.4 s
            $f = Capture 'hover' 4 { Move 40 ($P.barY); Start-Sleep -Milliseconds 300
                for ($x = 40; $x -le 2380; $x += 20) { Move $x $P.barY; Start-Sleep -Milliseconds 20 } }
            $m.hover = Motion $f $P.barRoi '-'
            # seek bar drag 20 % -> 80 % in 1.5 s
            $f = Capture 'seekdrag' 4 { Move 1200 900; Start-Sleep -Milliseconds 200
                $x0 = [int]($P.seekX0 + 0.2 * ($P.seekX1 - $P.seekX0)); $x1 = [int]($P.seekX0 + 0.8 * ($P.seekX1 - $P.seekX0))
                Move $x0 $P.seekY; Start-Sleep -Milliseconds 60; Down
                for ($k = 0; $k -le 75; $k++) { Move ([int]($x0 + ($x1 - $x0) * $k / 75)) $P.seekY; Start-Sleep -Milliseconds 20 }
                Up }
            $m.seek_drag = Motion $f $P.barRoi '-'
            # volume drag
            $f = Capture 'voldrag' 3 { Move 1200 900; Start-Sleep -Milliseconds 200
                Move $P.volX1 $P.volY; Start-Sleep -Milliseconds 60; Down
                for ($k = 0; $k -le 50; $k++) { Move ([int]($P.volX1 - ($P.volX1 - $P.volX0) * $k / 50)) $P.volY; Start-Sleep -Milliseconds 20 }
                for ($k = 0; $k -le 50; $k++) { Move ([int]($P.volX0 + ($P.volX1 - $P.volX0) * 0.8 * $k / 50)) $P.volY; Start-Sleep -Milliseconds 20 }
                Up }
            $m.volume_drag = Motion $f $P.barRoi '-'
            # panel open: cursor jumps onto the button (input marker), click right after
            $f = Capture 'panelopen' 3 { Move 1300 900; Start-Sleep -Milliseconds 300
                Move $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep -Milliseconds 15; Down; Start-Sleep -Milliseconds 30; Up }
            $m.panel_open = Motion $f $P.panelRoi "$($P.panelBtn[0]),$($P.panelBtn[1])"
            Start-Sleep 1
            $f = Capture 'panelclose' 3 { Move 1300 900; Start-Sleep -Milliseconds 300
                Move $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep -Milliseconds 15; Down; Start-Sleep -Milliseconds 30; Up }
            $m.panel_close = Motion $f $P.panelRoi "$($P.panelBtn[0]),$($P.panelBtn[1])"
            $Results.motion = $m
            Key ' '
        }
        Stop-Vlc $v; $v = $null; Start-Sleep 2
    }
    if (Want '4k') {
        $v = Start-Vlc $Media4k -Rc; Start-Sleep 3; Place $v; Move 1200 700; Start-Sleep 2
        $s0 = Stats; $r = Sample $v 20; $s1 = Stats
        $r.frames_displayed = $s1.displayed - $s0.displayed; $r.frames_lost = $s1.lost - $s0.lost
        $Results.k4_windowed = $r
        Key 'f'; Start-Sleep 3
        $s0 = Stats; $r = Sample $v 20; $s1 = Stats
        $r.frames_displayed = $s1.displayed - $s0.displayed; $r.frames_lost = $s1.lost - $s0.lost
        $Results.k4_fullscreen = $r
        Key 'f'; Start-Sleep 1
        Stop-Vlc $v; $v = $null; Start-Sleep 2
    }
    if (Want 'queue') {
        $v = Start-Vlc $Queue; Start-Sleep 4; Place $v; Move 1200 700; Start-Sleep 1; Key ' '; Start-Sleep 1
        $f = Capture 'queueopen' 3 { Move 1300 900; Start-Sleep -Milliseconds 300
            Move $P.queueBtn[0] $P.queueBtn[1]; Start-Sleep -Milliseconds 15; Down; Start-Sleep -Milliseconds 30; Up }
        $q = [ordered]@{ open = (Motion $f $P.panelRoi "$($P.queueBtn[0]),$($P.queueBtn[1])") }
        Start-Sleep 1
        $roi = $P.panelRoi.Split(','); $cx = [int]$roi[0] + [int]$roi[2] / 2; $cy = [int]$roi[1] + [int]$roi[3] / 2
        $f = Capture 'queuescroll' 4 { Move $cx $cy; Start-Sleep -Milliseconds 300
            for ($k = 0; $k -lt 40; $k++) { Wheel (-120); Start-Sleep -Milliseconds 35 } }
        $q.scroll = Motion $f $P.panelRoi '-'
        $v.proc.Refresh(); $q.ram_private_mb = [math]::Round($v.proc.PrivateMemorySize64 / 1MB, 0)
        $Results.queue = $q
        Stop-Vlc $v; $v = $null
    }
}
finally {
    if ($v) { Stop-Vlc $v }
    $Results | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $Out
    Write-Output ($Results | ConvertTo-Json -Depth 6)
}
