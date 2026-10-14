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
#   motion    UI smoothness from Desktop Duplication captures on a paused video: hover sweep over
#             the control bar, seek bar drag, volume drag (pointer steps every 4 ms, faster than
#             the 99 Hz refresh, logged on the QPC clock), panel open, panel close (click latency,
#             animation length); motion.py maps the input log onto the capture with a sync marker
#   4k        4K 60 fps 80 Mbit/s file windowed and fullscreen, 20 s each: frames displayed / lost
#             (VLC's own statistics through the cli interface on 127.0.0.1), CPU, GPU
#   queue     520-item queue: panel open latency and wheel scrolling smoothness
# Each capture <out dir>\<kind>-<name>.mkv comes with <capture>.input.json (input log) and
# <capture>.png (its last frame: check that the panel really opened where the ROI expects it).
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

# Motion input and capture sync (C# so the timing does not depend on PowerShell):
#   RdInput   paced pointer input on a 1 ms timer (timeBeginPeriod), every event logged with its
#             QueryPerformanceCounter time in microseconds; each event first checks that the VLC
#             window under test (Target) is in front, like Guard
#   RdMarker  a 20x20 no-activate, click-through, topmost square of our own in the captured area;
#             it flips black/white at logged QPC times so motion.py can map QPC onto the capture's
#             timestamps (ddagrab stamps frames relative to its first frame, on its own clock)
if (-not ('RdInput' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public static class RdInput {
  [DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint p);
  [DllImport("winmm.dll")] static extern uint timeEndPeriod(uint p);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern void mouse_event(uint f, uint dx, uint dy, int d, IntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);

  // the VLC window under test; every input below refuses unless it is the foreground window
  public static IntPtr Target = IntPtr.Zero;
  static readonly List<string> events = new List<string>();
  static int lastX = -1, lastY = -1;

  public static double NowUs() { return Stopwatch.GetTimestamp() * 1000000.0 / Stopwatch.Frequency; }
  static void Guard() {
    if (Target == IntPtr.Zero || GetForegroundWindow() != Target)
      throw new InvalidOperationException("VLC is not the foreground window: no input sent, round stopped");
  }
  static void Rec(string type, int x, int y, int d, string tag) {
    double t = NowUs();
    lock (events) events.Add(string.Format(CultureInfo.InvariantCulture,
      "{{\"t\":{0:F1},\"type\":\"{1}\",\"x\":{2},\"y\":{3},\"d\":{4},\"tag\":\"{5}\"}}", t, type, x, y, d, tag));
  }
  public static void Clear() { lock (events) events.Clear(); }
  public static string EventsJson() { lock (events) return "[" + string.Join(",", events.ToArray()) + "]"; }

  // waits until an absolute NowUs() time: 1 ms sleeps (timer at 1 ms), then a short spin; a
  // Sleep(1) can take up to ~2 ms, so the last 2.5 ms spin (measured: max 0.07 ms late)
  static void WaitUntil(double us) {
    while (true) {
      double r = us - NowUs();
      if (r <= 0) return;
      if (r > 2500) Thread.Sleep(1); else Thread.SpinWait(200);
    }
  }
  public static void Pause(double ms) {
    timeBeginPeriod(1);
    try { WaitUntil(NowUs() + ms * 1000.0); } finally { timeEndPeriod(1); }
  }
  public static void Move(int x, int y, string tag) {
    Guard(); SetCursorPos(x, y); lastX = x; lastY = y; Rec("move", x, y, 0, tag);
  }
  static bool buttonDown;
  public static void Down(string tag) { Guard(); mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); buttonDown = true; Rec("down", lastX, lastY, 0, tag); }
  public static void Up(string tag) { Guard(); mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); buttonDown = false; Rec("up", lastX, lastY, 0, tag); }
  // after an aborted drag: releases the button this harness pressed, the one input sent without
  // the foreground check (a stuck button would turn every later pointer move into a drag; VLC
  // holds the mouse capture during a drag, so the release still goes to VLC)
  public static bool ReleaseIfDown() {
    if (!buttonDown) return false;
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); buttonDown = false; Rec("up", lastX, lastY, 0, "abort");
    return true;
  }
  // pointer path: point i is sent at start + i * stepMs (absolute deadlines, so no drift)
  public static void Path(int[] xs, int[] ys, double stepMs, string tag) {
    if (xs.Length != ys.Length) throw new ArgumentException("path: xs and ys differ in length");
    timeBeginPeriod(1);
    try {
      double t0 = NowUs();
      for (int i = 0; i < xs.Length; i++) {
        WaitUntil(t0 + i * stepMs * 1000.0);
        Guard(); SetCursorPos(xs[i], ys[i]); lastX = xs[i]; lastY = ys[i];
        Rec("move", xs[i], ys[i], 0, tag);
      }
    } finally { timeEndPeriod(1); }
  }
  // n wheel notches of delta, one every stepMs
  public static void Wheels(int n, int delta, double stepMs, string tag) {
    timeBeginPeriod(1);
    try {
      double t0 = NowUs();
      for (int i = 0; i < n; i++) {
        WaitUntil(t0 + i * stepMs * 1000.0);
        Guard(); mouse_event(0x0800, 0, 0, delta, IntPtr.Zero);
        Rec("wheel", lastX, lastY, delta, tag);
      }
    } finally { timeEndPeriod(1); }
  }

  // the process's main Qt window: visible, at least 400 px wide, never the console window that
  // the cli interface opens (r1 measured that console by mistake); the largest one wins
  public static IntPtr FindMainWindow(int pid) {
    IntPtr best = IntPtr.Zero; long bestArea = 0; bool bestQt = false;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != (uint)pid || !IsWindowVisible(h)) return true;
      StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, sb.Capacity);
      string cls = sb.ToString();
      if (cls == "ConsoleWindowClass") return true;
      RECT r; GetWindowRect(h, out r);
      int w = r.Right - r.Left, ht = r.Bottom - r.Top;
      if (w < 400) return true;
      bool qt = cls.StartsWith("Qt");
      long area = (long)w * ht;
      if ((qt && !bestQt) || (qt == bestQt && area > bestArea)) { best = h; bestArea = area; bestQt = qt; }
      return true;
    }, IntPtr.Zero);
    return best;
  }
  public static string ClassOf(IntPtr h) { StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, sb.Capacity); return sb.ToString(); }
}

public class RdMarkerForm : Form {
  public RdMarkerForm(Rectangle r) {
    FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false; AutoScaleMode = AutoScaleMode.None; BackColor = Color.Black; Bounds = r;
  }
  protected override bool ShowWithoutActivation { get { return true; } }
  // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_TRANSPARENT: never takes focus,
  // no taskbar button, above VLC, clicks pass through
  protected override CreateParams CreateParams {
    get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x08000000 | 0x00000080 | 0x00000008 | 0x00000020; return cp; }
  }
}

public sealed class RdMarker : IDisposable {
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  RdMarkerForm form;
  readonly Thread thread;
  readonly ManualResetEvent ready = new ManualResetEvent(false);
  readonly List<string> flips = new List<string>();
  bool white;
  public readonly int X, Y, W, H;
  // the form lives on its own thread with its own message loop, so it never looks hung
  public RdMarker(int x, int y, int w, int h) {
    X = x; Y = y; W = w; H = h;
    thread = new Thread(delegate() {
      form = new RdMarkerForm(new Rectangle(x, y, w, h));
      form.Shown += delegate { ready.Set(); };
      Application.Run(form);
    });
    thread.IsBackground = true;
    thread.SetApartmentState(ApartmentState.STA);
    thread.Start();
    if (!ready.WaitOne(5000)) throw new InvalidOperationException("the sync marker window did not appear");
  }
  // back to black and on top of the (topmost) VLC window, without activating
  public void Reset() {
    form.Invoke(new MethodInvoker(delegate {
      white = false; form.BackColor = Color.Black; form.Refresh();
      SetWindowPos(form.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x0013);
    }));
    lock (flips) flips.Clear();
  }
  // toggles the colour; the time is taken right after the paint, on the form's thread
  public void Flip() {
    form.Invoke(new MethodInvoker(delegate {
      white = !white; form.BackColor = white ? Color.White : Color.Black; form.Refresh();
      double t = RdInput.NowUs();
      lock (flips) flips.Add(string.Format(CultureInfo.InvariantCulture, "{{\"t\":{0:F1},\"v\":{1}}}", t, white ? 1 : 0));
    }));
  }
  // a short burst with uneven spacing, so the flips can be matched without ambiguity
  public void Burst() {
    double[] gaps = { 47, 61, 83, 0 };
    foreach (double g in gaps) { Flip(); if (g > 0) RdInput.Pause(g); }
  }
  public string FlipsJson() { lock (flips) return "[" + string.Join(",", flips.ToArray()) + "]"; }
  public void Dispose() {
    try { if (form != null && form.IsHandleCreated) form.Invoke(new MethodInvoker(form.Close)); } catch (Exception) {}
    thread.Join(3000);
  }
}
"@
}

# control positions (window pixels of the 2400x1350 window) per build, checked against window
# screenshots at this size: redesign gear 2311,1307 / queue 2352,1307, side panel 1867-2366 x
# 62-1258, seek bar 298-1942, volume 2098-2202; stock playlist button 2359,64, seek bar y 1237,
# volume 2128-2250 at y 1290. The stock playlist pops up at the right edge above the seek bar
# (width from its saved setting); listAt is a point inside it for the wheel.
$P = @{
    redesign = @{ barY = 1306; seekX0 = 320; seekX1 = 1920; seekY = 1306; volX0 = 2105; volX1 = 2195; volY = 1306
                  panelBtn = @(2310, 1306); queueBtn = @(2352, 1306); panelRoi = '1855,55,520,1215'; barRoi = '0,1270,2400,75'
                  listAt = @(2110, 700) }
    stock    = @{ barY = 1290; seekX0 = 60; seekX1 = 2340; seekY = 1238; volX0 = 2130; volX1 = 2250; volY = 1290
                  panelBtn = @(2358, 64); queueBtn = @(2358, 64); panelRoi = '1500,90,900,1120'; barRoi = '0,1200,2400,150'
                  listAt = @(2200, 640) }
}[$Kind]

$Results = [ordered]@{ kind = $Kind; build = $Build; date = (Get-Date -Format 'yyyy-MM-dd HH:mm') }

# the machine must be quiet (no builds, agents or other heavy work), or the numbers mean nothing
# total CPU of every process over 3 s (performance counters are not available on this PC)
function Total-CpuSeconds { (Get-Process | ForEach-Object { try { $_.TotalProcessorTime.TotalSeconds } catch { 0 } } | Measure-Object -Sum).Sum }
$c0 = Total-CpuSeconds; Start-Sleep 3; $c1 = Total-CpuSeconds
$bg = [pscustomobject]@{ Average = ($c1 - $c0) / 3 / [Environment]::ProcessorCount * 100 }
$Results.background_cpu_pct = [math]::Round($bg.Average, 1)
# the Claude app itself and Chrome use about 15-20 % while a session runs; both builds see the same
if ($bg.Average -gt 30) { throw "the PC is busy ($([math]::Round($bg.Average, 1)) % CPU before starting); run again when it is quiet" }
function Want($name) { return ($Only.Count -eq 0) -or ($Only -contains $name) }
function Exe { return (Get-ChildItem $Build -Recurse -Filter vlc.exe | Select-Object -First 1) }
function LogPath { return (Join-Path $Build 'vlc-perf-log.txt') }

# the Qt main window, never MainWindowHandle: with the cli interface that can be VLC's console
# window, and round 1 resized, focused, clicked and captured that console instead of the player
function Get-Win($proc) {
    for ($i = 0; $i -lt 800; $i++) {
        $proc.Refresh()
        if ($proc.HasExited) { throw 'VLC exited' }
        $h = [RdInput]::FindMainWindow($proc.Id)
        if ($h -ne [IntPtr]::Zero) { return $h }
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
    # --rc-quiet: on Windows the cli interface otherwise opens a console window
    if ($Rc) { $a += @('--extraintf=cli', "--rc-host=127.0.0.1:$RcPort", '--rc-quiet') }
    if ($media) { $a += "`"$media`"" }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $exe.FullName -ArgumentList $a -WorkingDirectory $exe.DirectoryName -PassThru
    $h = Get-Win $p
    $tWin = $sw.ElapsedMilliseconds
    return @{ proc = $p; hwnd = $h; sw = $sw; tWin = $tWin }
}
# sizes the window; no input, no focus change (pause, seek and fullscreen go through VLC's cli)
function Place($v) {
    [RdPerf]::MoveWindow($v.hwnd, 0, 0, 2400, 1350, $true) | Out-Null
}
# brings VLC to the front for the scenarios that need the mouse (panel, motion, queue); throws
# when the user keeps another window in front, and the scenario is skipped
function Engage($v) {
    Focus $v.hwnd
    $script:CurHwnd = $v.hwnd
    [RdInput]::Target = $v.hwnd
    # the coordinates below are window pixels of a 2400x1350 window at 0,0: refuse anything else
    $r = New-Object RdPerf+RECT; [RdPerf]::GetWindowRect($v.hwnd, [ref]$r) | Out-Null
    if ([math]::Abs($r.Left) -gt 2 -or [math]::Abs($r.Top) -gt 2 -or [math]::Abs($r.Right - 2400) -gt 2 -or [math]::Abs($r.Bottom - 1350) -gt 2) {
        throw "VLC window is at $($r.Left),$($r.Top)-$($r.Right),$($r.Bottom), not 0,0-2400,1350 ($([RdInput]::ClassOf($v.hwnd)))"
    }
}
# every input helper refuses unless the VLC window under test is in front, so no key, click or
# pointer move can ever reach another application (Sticky uses this PC)
$script:CurHwnd = [IntPtr]::Zero
function Guard {
    if ($script:CurHwnd -eq [IntPtr]::Zero -or [RdPerf]::GetForegroundWindow() -ne $script:CurHwnd) {
        throw 'VLC is not the foreground window: no input sent, round stopped'
    }
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
function MouseTo($x, $y) { Guard; [RdPerf]::SetCursorPos($x, $y) | Out-Null }
function Down { Guard; [RdPerf]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero) }
function Up { Guard; [RdPerf]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero) }
function Click($x, $y) { MouseTo $x $y; Start-Sleep -Milliseconds 30; Down; Start-Sleep -Milliseconds 40; Up }
function Wheel($n) { Guard; [RdPerf]::mouse_event(0x0800, 0, 0, $n, [IntPtr]::Zero) }
function Key($k) { Guard; [System.Windows.Forms.SendKeys]::SendWait($k) }

# CPU from the process times; GPU from nvidia-smi (whole GPU: 3D/compute load and the video
# decoder), valid because the machine is quiet during a round
function Gpu {
    $o = & nvidia-smi --query-gpu=utilization.gpu,utilization.decoder --format=csv,noheader,nounits 2>$null
    if (-not $o) { return $null }
    $a = ($o | Select-Object -First 1).Split(',') | ForEach-Object { [double]$_.Trim() }
    return $a
}
function Sample($v, [int]$seconds) {
    $p = $v.proc; $p.Refresh()
    $cpu0 = $p.TotalProcessorTime; $t0 = Get-Date
    $priv = @(); $ws = @(); $g3d = @(); $gvd = @()
    for ($i = 0; $i -lt $seconds; $i++) {
        Start-Sleep -Milliseconds 1000
        $g = Gpu
        if ($g) { $g3d += $g[0]; $gvd += $g[1] }
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
        gpu_pct = if ($g3d.Count) { [math]::Round(($g3d | Measure-Object -Average).Average, 1) } else { $null }
        gpu_decoder_pct = if ($gvd.Count) { [math]::Round(($gvd | Measure-Object -Average).Average, 1) } else { $null }
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

# Desktop Duplication capture of the window, only changed frames, at quarter size, no pointer
# (the pointer is not UI: drawing it made every pointer step count as an update in round 1).
# ddagrab stamps each frame when it acquires it, in microseconds; framerate=240 only sets how
# often it polls (frames come only on screen changes), so a stamp is at most ~4 ms after the
# present. -enc_time_base 1:1000 keeps millisecond stamps: by default the encoder rounds them to
# 1/framerate (round 1: every stamp on the 8.3 ms grid of 120 fps).
# The sync marker flips before and after the action; the input log (QPC times of every event
# and flip) goes next to the capture as <capture>.input.json for motion.py.
$MarkerRect = @(0, 1330, 20, 20)   # window pixels, bottom-left corner; motion.py masks it out
function Capture([string]$name, [double]$seconds, [scriptblock]$action) {
    $file = Join-Path $OutDir "$Kind-$name.mkv"
    Remove-Item $file -ErrorAction SilentlyContinue
    $vf = "ddagrab=output_idx=0:framerate=240:dup_frames=0:draw_mouse=0:offset_x=0:offset_y=0:video_size=2400x1350,hwdownload,format=bgra,scale=600:338:flags=area"
    $script:Marker.Reset()
    [RdInput]::Clear()
    $ff = Start-Process ffmpeg -ArgumentList @('-v', 'error', '-y', '-filter_complex', $vf, '-fps_mode', 'passthrough',
          '-enc_time_base:v', '1:1000', '-c:v', 'libx264rgb', '-preset', 'ultrafast', '-qp', '0', '-t', "$seconds", "`"$file`"") -PassThru -WindowStyle Hidden
    try {
        Start-Sleep -Milliseconds 1000
        if ($ff.HasExited) { throw "ffmpeg stopped at once (exit $($ff.ExitCode))" }
        $script:Marker.Burst()
        & $action
        Start-Sleep -Milliseconds 300
        $script:Marker.Burst()
        $log = '{"marker":[' + ($MarkerRect -join ',') + '],"flips":' + $script:Marker.FlipsJson() + ',"events":' + [RdInput]::EventsJson() + '}'
        [IO.File]::WriteAllText("$file.input.json", $log)
        if (-not $ff.WaitForExit(([int]$seconds + 10) * 1000)) { throw 'ffmpeg did not finish' }
    } finally {
        [RdInput]::ReleaseIfDown() | Out-Null
        if (-not $ff.HasExited) { try { $ff.Kill() } catch {} ; $ff.WaitForExit(3000) | Out-Null }
    }
    return $file
}
# kind: drag | scroll (every input step should move the UI), hover, open (click -> panel)
function Motion([string]$file, [string]$kind, [string]$roi) {
    $j = & python -I (Join-Path $Here 'motion.py') $file "$file.input.json" $kind $roi --scale 4 --png "$file.png"
    return ($j | ConvertFrom-Json)
}
# Paced pointer helpers (RdInput; each step checks that VLC is in front, like Guard)
# bring the bars up and let their animations finish, so they are not part of the measurement
function Wake {
    [RdInput]::Move(1300, 900, 'prep'); [RdInput]::Pause(60); [RdInput]::Move(1320, 910, 'prep'); [RdInput]::Pause(700)
}
# straight line from (x0,y0) to (x1,y1) in n steps, one step every $stepMs
function Line([int]$x0, [int]$y0, [int]$x1, [int]$y1, [int]$n, [double]$stepMs, [string]$tag) {
    $xs = New-Object int[] ($n + 1); $ys = New-Object int[] ($n + 1)
    for ($k = 0; $k -le $n; $k++) { $xs[$k] = [int][math]::Round($x0 + ($x1 - $x0) * $k / $n); $ys[$k] = [int][math]::Round($y0 + ($y1 - $y0) * $k / $n) }
    [RdInput]::Path($xs, $ys, $stepMs, $tag)
}
# click on a button: hover first (its hover feedback is not the measured response), then press;
# Qt buttons act on release, so motion.py measures from the "up" event
function ClickAt([int]$x, [int]$y) {
    [RdInput]::Move($x, $y, 'prep'); [RdInput]::Pause(250)
    [RdInput]::Down('click'); [RdInput]::Pause(40); [RdInput]::Up('click')
}
$script:Marker = $null
function New-Marker {
    if (-not $script:Marker) { $script:Marker = New-Object RdMarker $MarkerRect[0], $MarkerRect[1], $MarkerRect[2], $MarkerRect[3] }
}
function Close-Marker { if ($script:Marker) { $script:Marker.Dispose(); $script:Marker = $null } }

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
        $v = Start-Vlc $Media -Rc; Start-Sleep 3; Place $v; Start-Sleep 2
        if (Want 'play') { $Results.play = Sample $v 15 }
        if (Want 'idle') { Rc 'pause' | Out-Null; Start-Sleep 1; $Results.idle_paused = Sample $v 10; Rc 'pause' | Out-Null; Start-Sleep 1 }
        if (Want 'panel') {
            try {
                Engage $v
                MouseTo 1300 900; Start-Sleep -Milliseconds 300; Click $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep 1
                $Results.panel_open_playing = Sample $v 10
                Click $P.panelBtn[0] $P.panelBtn[1]; Start-Sleep 1
            } catch { $Results.panel_open_playing = "skipped: $($_.Exception.Message)" }
        }
        if (Want 'seek') {
            $t0 = Get-Date
            $v.proc.Refresh(); $c0 = $v.proc.TotalProcessorTime
            for ($i = 0; $i -lt 10; $i++) { Rc ("seek " + (10 + 10 * $i)) | Out-Null }
            $v.proc.Refresh()
            $Results.seek = [ordered]@{ cpu_pct = [math]::Round(($v.proc.TotalProcessorTime - $c0).TotalSeconds / ((Get-Date) - $t0).TotalSeconds / [Environment]::ProcessorCount * 100, 1);
                                       ram_private_mb = [math]::Round($v.proc.PrivateMemorySize64 / 1MB, 0) }
        }
        if (Want 'motion') { try {
            Rc 'pause' | Out-Null; Start-Sleep 1   # pause: only the UI changes on screen
            Engage $v; New-Marker; Engage $v       # the marker never takes focus; checked again anyway
            Guard
            $m = [ordered]@{}
            # hover sweep along the control bar: 4 px every 4 ms (1000 px/s, 2.5 steps per 99 Hz frame)
            $f = Capture 'hover' 7 { Wake
                [RdInput]::Move(40, $P.barY, 'prep'); [RdInput]::Pause(400)
                Line 40 $P.barY 2380 $P.barY 585 4 'phase'; [RdInput]::Pause(300) }
            $m.hover = Motion $f 'hover' $P.barRoi
            # seek bar drag 20 % -> 80 % in 1.5 s, one step every 4 ms
            $f = Capture 'seekdrag' 6 { Wake
                $x0 = [int]($P.seekX0 + 0.2 * ($P.seekX1 - $P.seekX0)); $x1 = [int]($P.seekX0 + 0.8 * ($P.seekX1 - $P.seekX0))
                [RdInput]::Move($x0, $P.seekY, 'prep'); [RdInput]::Pause(250); [RdInput]::Down('prep'); [RdInput]::Pause(150)
                Line $x0 $P.seekY $x1 $P.seekY 375 4 'phase'
                [RdInput]::Pause(150); [RdInput]::Up('prep') }
            $m.seek_drag = Motion $f 'drag' $P.barRoi
            # volume drag: max -> min -> 80 %, 0.45 s each way, one step every 4 ms
            $f = Capture 'voldrag' 5 { Wake
                $x80 = [int]($P.volX0 + 0.8 * ($P.volX1 - $P.volX0))
                [RdInput]::Move($P.volX1, $P.volY, 'prep'); [RdInput]::Pause(250); [RdInput]::Down('prep'); [RdInput]::Pause(150)
                Line $P.volX1 $P.volY $P.volX0 $P.volY 112 4 'phase'
                Line $P.volX0 $P.volY $x80 $P.volY 112 4 'phase'
                [RdInput]::Pause(150); [RdInput]::Up('prep') }
            $m.volume_drag = Motion $f 'drag' $P.barRoi
            # panel open / close: click latency, then how long until the panel is still
            $f = Capture 'panelopen' 6 { Wake; ClickAt $P.panelBtn[0] $P.panelBtn[1]; [RdInput]::Pause(1500) }
            $m.panel_open = Motion $f 'open' $P.panelRoi
            Start-Sleep 1
            $f = Capture 'panelclose' 6 { Wake; ClickAt $P.panelBtn[0] $P.panelBtn[1]; [RdInput]::Pause(1500) }
            $m.panel_close = Motion $f 'open' $P.panelRoi
            $Results.motion = $m
            Rc 'pause' | Out-Null
        } catch { $Results.motion = "skipped: $($_.Exception.Message)" } finally { Close-Marker } }
        Stop-Vlc $v; $v = $null; Start-Sleep 2
    }
    if (Want '4k') {
        $v = Start-Vlc $Media4k -Rc; Start-Sleep 3; Place $v; Start-Sleep 2
        $s0 = Stats; $r = Sample $v 20; $s1 = Stats
        $r.frames_displayed = $s1.displayed - $s0.displayed; $r.frames_lost = $s1.lost - $s0.lost
        $Results.k4_windowed = $r
        Rc 'fullscreen on' | Out-Null; Start-Sleep 3
        $s0 = Stats; $r = Sample $v 20; $s1 = Stats
        $r.frames_displayed = $s1.displayed - $s0.displayed; $r.frames_lost = $s1.lost - $s0.lost
        $Results.k4_fullscreen = $r
        Rc 'fullscreen off' | Out-Null; Start-Sleep 1
        Stop-Vlc $v; $v = $null; Start-Sleep 2
    }
    if (Want 'queue') {
        $v = Start-Vlc $Queue -Rc; Start-Sleep 4; Place $v; Rc 'pause' | Out-Null; Start-Sleep 1
        try { Engage $v; New-Marker; Engage $v; Guard
        $f = Capture 'queueopen' 6 { Wake; ClickAt $P.queueBtn[0] $P.queueBtn[1]; [RdInput]::Pause(1500) }
        $q = [ordered]@{ open = (Motion $f 'open' $P.panelRoi) }
        Start-Sleep 1
        # 40 wheel notches down, one every 35 ms, over the list
        $f = Capture 'queuescroll' 6 { Wake
            [RdInput]::Move($P.listAt[0], $P.listAt[1], 'prep'); [RdInput]::Pause(400)
            [RdInput]::Wheels(40, -120, 35, 'phase'); [RdInput]::Pause(300) }
        $q.scroll = Motion $f 'scroll' $P.panelRoi
        $v.proc.Refresh(); $q.ram_private_mb = [math]::Round($v.proc.PrivateMemorySize64 / 1MB, 0)
        $Results.queue = $q
        } catch { $Results.queue = "skipped: $($_.Exception.Message)" } finally { Close-Marker }
        Stop-Vlc $v; $v = $null
    }
}
finally {
    Close-Marker
    if ($v) { Stop-Vlc $v }
    $Results | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $Out
    Write-Output ($Results | ConvertTo-Json -Depth 6)
}
