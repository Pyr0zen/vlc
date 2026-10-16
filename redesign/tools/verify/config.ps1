# Harness settings for the PowerShell side: verify.example.json (committed placeholders)
# overlaid with verify.local.json (gitignored, the real paths of this PC).
function Get-VerifyConfig {
    $here = $PSScriptRoot
    $cfg = Get-Content -Raw -Encoding UTF8 (Join-Path $here 'verify.example.json') | ConvertFrom-Json
    $localPath = Join-Path $here 'verify.local.json'
    if (Test-Path $localPath) {
        $local = Get-Content -Raw -Encoding UTF8 $localPath | ConvertFrom-Json
        foreach ($p in $local.PSObject.Properties) {
            if ($cfg.PSObject.Properties[$p.Name]) { $cfg.($p.Name) = $p.Value } else { $cfg | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
        }
    }
    foreach ($k in 'testMediaDir', 'outRoot') { if ([string]$cfg.$k -like '*<*') { throw "set $k in $localPath (see README.md)" } }
    if ($cfg.guardRetrySec) { $script:GuardRetrySec = [int]$cfg.guardRetrySec }
    return $cfg
}
