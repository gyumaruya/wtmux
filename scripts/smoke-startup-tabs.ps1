# smoke-startup-tabs.ps1
# Run an isolated startup-tabs smoke test on Windows.
#
# This script does not touch the user's existing %LOCALAPPDATA%\wtmux config.
# It creates a temporary LOCALAPPDATA tree, writes a temporary config.toml,
# launches wtmux, and validates marker files written by each startup tab.
#
# Example:
#   powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 `
#     -WtmuxExe .\target\release\wtmux.exe -Shell cmd
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 `
#     -WtmuxExe .\target\release\wtmux.exe -Shell pwsh -EnableVtTrace

param(
    [Parameter(Mandatory = $true)]
    [string]$WtmuxExe,

    [ValidateSet("cmd", "pwsh")]
    [string]$Shell = "cmd",

    [int]$TimeoutSec = 30,

    [string]$RunRoot = "",

    [switch]$EnableVtTrace
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Escape-TomlString {
    param([string]$Value)

    return $Value.Replace("\", "\\").Replace('"', '\"')
}

function New-IsolatedRunRoot {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $root = Join-Path $env:TEMP "wtmux-startup-tabs-$stamp"
    New-Item -ItemType Directory -Path $root | Out-Null
    return $root
}

function New-CommandSet {
    param(
        [string]$ShellName,
        [string]$MarkerDir
    )

    $tab1Marker = Join-Path $MarkerDir "tab1.txt"
    $tab2Marker = Join-Path $MarkerDir "tab2.txt"

    switch ($ShellName) {
        "cmd" {
            return @{
                ShellCommand = "cmd.exe"
                Tab1 = "echo tab1-startup>""$tab1Marker"" && exit"
                Tab2 = "echo tab2-startup>""$tab2Marker"" && exit"
                Tab1Expected = "tab1-startup"
                Tab2Expected = "tab2-startup"
                Tab1Marker = $tab1Marker
                Tab2Marker = $tab2Marker
            }
        }
        "pwsh" {
            return @{
                ShellCommand = "pwsh.exe"
                Tab1 = "Set-Content -Path ""$tab1Marker"" -Value ""tab1-startup""; exit"
                Tab2 = "Set-Content -Path ""$tab2Marker"" -Value ""tab2-startup""; exit"
                Tab1Expected = "tab1-startup"
                Tab2Expected = "tab2-startup"
                Tab1Marker = $tab1Marker
                Tab2Marker = $tab2Marker
            }
        }
        default {
            throw "Unsupported shell: $ShellName"
        }
    }
}

if (-not (Test-Path $WtmuxExe)) {
    throw "wtmux.exe not found: $WtmuxExe"
}

if (-not $RunRoot) {
    $RunRoot = New-IsolatedRunRoot
} elseif (-not (Test-Path $RunRoot)) {
    New-Item -ItemType Directory -Path $RunRoot | Out-Null
}

$RunRoot = (Resolve-Path $RunRoot).Path
$LocalAppDataRoot = Join-Path $RunRoot "localappdata"
$ConfigDir = Join-Path $LocalAppDataRoot "wtmux"
$MarkerDir = Join-Path $RunRoot "markers"
$ReportPath = Join-Path $RunRoot "report.json"
$ConfigPath = Join-Path $ConfigDir "config.toml"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $MarkerDir | Out-Null

$commands = New-CommandSet -ShellName $Shell -MarkerDir $MarkerDir

$config = @"
shell = "$(Escape-TomlString $commands.ShellCommand)"
color_scheme = "default"

[[startup.tabs]]
name = "server"
command = "$(Escape-TomlString $commands.Tab1)"

[[startup.tabs]]
name = "tests"
command = "$(Escape-TomlString $commands.Tab2)"
"@

Set-Content -Path $ConfigPath -Value $config -Encoding UTF8

$wtmuxArgs = @()
if ($EnableVtTrace) {
    $wtmuxArgs += "--vt-trace"
}

$argSuffix = if ($wtmuxArgs.Count -gt 0) {
    " " + ($wtmuxArgs -join " ")
} else {
    ""
}

$commandLine = 'set "LOCALAPPDATA={0}" && "{1}"{2}' -f $LocalAppDataRoot, $WtmuxExe, $argSuffix
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $commandLine -NoNewWindow -PassThru
$finished = $process.WaitForExit($TimeoutSec * 1000)

$timedOut = $false
if (-not $finished) {
    $timedOut = $true
    Stop-Process -Id $process.Id -Force
}

$tab1Exists = Test-Path $commands.Tab1Marker
$tab2Exists = Test-Path $commands.Tab2Marker
$tab1Content = if ($tab1Exists) { (Get-Content -Path $commands.Tab1Marker -Raw).Trim() } else { $null }
$tab2Content = if ($tab2Exists) { (Get-Content -Path $commands.Tab2Marker -Raw).Trim() } else { $null }
$vtTracePath = Join-Path $ConfigDir "vt_trace.log"

$report = [ordered]@{
    shell = $Shell
    wtmuxExe = (Resolve-Path $WtmuxExe).Path
    runRoot = $RunRoot
    localAppData = $LocalAppDataRoot
    configPath = $ConfigPath
    markerDir = $MarkerDir
    tab1Marker = $commands.Tab1Marker
    tab2Marker = $commands.Tab2Marker
    timedOut = $timedOut
    exitCode = if ($finished) { $process.ExitCode } else { $null }
    tab1Exists = $tab1Exists
    tab2Exists = $tab2Exists
    tab1Content = $tab1Content
    tab2Content = $tab2Content
    vtTraceEnabled = [bool]$EnableVtTrace
    vtTracePath = if (Test-Path $vtTracePath) { $vtTracePath } else { $null }
    passed = (-not $timedOut) -and $tab1Exists -and $tab2Exists `
        -and ($tab1Content -eq $commands.Tab1Expected) `
        -and ($tab2Content -eq $commands.Tab2Expected)
}

$report | ConvertTo-Json -Depth 4 | Set-Content -Path $ReportPath -Encoding UTF8
$report | ConvertTo-Json -Depth 4

if (-not $report.passed) {
    throw "startup-tabs smoke test failed"
}

Write-Host "Artifacts kept at: $RunRoot"
