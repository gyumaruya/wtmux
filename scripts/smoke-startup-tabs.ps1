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

    [ValidateRange(1, 2)]
    [int]$TabCount = 2,

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
        [string]$MarkerDir,
        [int]$RequestedTabCount
    )

    $cmdTabs = @(
        @{
            Name = "server"
            Marker = (Join-Path $MarkerDir "tab1.txt")
            Expected = "tab1-startup"
            CommandTemplate = 'echo tab1-startup>"{0}" && exit'
        },
        @{
            Name = "tests"
            Marker = (Join-Path $MarkerDir "tab2.txt")
            Expected = "tab2-startup"
            CommandTemplate = 'echo tab2-startup>"{0}" && exit'
        }
    )

    $pwshTabs = @(
        @{
            Name = "server"
            Marker = (Join-Path $MarkerDir "tab1.txt")
            Expected = "tab1-startup"
            CommandTemplate = 'Set-Content -Path "{0}" -Value "tab1-startup"; exit'
        },
        @{
            Name = "tests"
            Marker = (Join-Path $MarkerDir "tab2.txt")
            Expected = "tab2-startup"
            CommandTemplate = 'Set-Content -Path "{0}" -Value "tab2-startup"; exit'
        }
    )

    switch ($ShellName) {
        "cmd" {
            $shellCommand = "cmd.exe"
            $tabTemplates = $cmdTabs
        }
        "pwsh" {
            $shellCommand = "pwsh.exe"
            $tabTemplates = $pwshTabs
        }
        default {
            throw "Unsupported shell: $ShellName"
        }
    }

    $tabs = @()
    foreach ($tabTemplate in ($tabTemplates | Select-Object -First $RequestedTabCount)) {
        $tabs += @{
            Name = $tabTemplate.Name
            Marker = $tabTemplate.Marker
            Expected = $tabTemplate.Expected
            Command = [string]::Format($tabTemplate.CommandTemplate, $tabTemplate.Marker)
        }
    }

    return @{
        ShellCommand = $shellCommand
        Tabs = $tabs
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

$commands = New-CommandSet -ShellName $Shell -MarkerDir $MarkerDir -RequestedTabCount $TabCount

$configLines = @(
    "shell = ""$(Escape-TomlString $commands.ShellCommand)""",
    'color_scheme = "default"',
    ""
)

foreach ($tab in $commands.Tabs) {
    $configLines += '[[startup.tabs]]'
    $configLines += "name = ""$(Escape-TomlString $tab.Name)"""
    $configLines += "command = ""$(Escape-TomlString $tab.Command)"""
    $configLines += ""
}

$config = [string]::Join([Environment]::NewLine, $configLines)

Set-Content -Path $ConfigPath -Value $config -Encoding UTF8

$wtmuxArgs = @()
if ($EnableVtTrace) {
    $wtmuxArgs += "--vt-trace"
}

$previousLocalAppData = $env:LOCALAPPDATA
$previousHeadless = $env:WTMUX_HEADLESS
$env:LOCALAPPDATA = $LocalAppDataRoot
$env:WTMUX_HEADLESS = "1"

try {
    $process = Start-Process -FilePath $WtmuxExe `
        -ArgumentList $wtmuxArgs `
        -WorkingDirectory (Split-Path -Parent $WtmuxExe) `
        -PassThru
    $finished = $process.WaitForExit($TimeoutSec * 1000)
}
finally {
    if ($null -ne $previousLocalAppData) {
        $env:LOCALAPPDATA = $previousLocalAppData
    }
    else {
        Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
    }

    if ($null -ne $previousHeadless) {
        $env:WTMUX_HEADLESS = $previousHeadless
    }
    else {
        Remove-Item Env:WTMUX_HEADLESS -ErrorAction SilentlyContinue
    }
}

$timedOut = $false
if (-not $finished) {
    $timedOut = $true
    Stop-Process -Id $process.Id -Force
}

$tabResults = @()
foreach ($tab in $commands.Tabs) {
    $exists = Test-Path $tab.Marker
    $content = if ($exists) { (Get-Content -Path $tab.Marker -Raw).Trim() } else { $null }

    $tabResults += [ordered]@{
        name = $tab.Name
        marker = $tab.Marker
        expected = $tab.Expected
        exists = $exists
        content = $content
        passed = $exists -and ($content -eq $tab.Expected)
    }
}

$vtTracePath = Join-Path $ConfigDir "vt_trace.log"

$passed = -not $timedOut
foreach ($tabResult in $tabResults) {
    $passed = $passed -and $tabResult.passed
}

$report = [ordered]@{
    shell = $Shell
    tabCount = $TabCount
    wtmuxExe = (Resolve-Path $WtmuxExe).Path
    runRoot = $RunRoot
    localAppData = $LocalAppDataRoot
    configPath = $ConfigPath
    markerDir = $MarkerDir
    tab1Marker = if ($tabResults.Count -ge 1) { $tabResults[0].marker } else { $null }
    tab2Marker = if ($tabResults.Count -ge 2) { $tabResults[1].marker } else { $null }
    timedOut = $timedOut
    exitCode = if ($finished) { $process.ExitCode } else { $null }
    tab1Exists = if ($tabResults.Count -ge 1) { $tabResults[0].exists } else { $null }
    tab2Exists = if ($tabResults.Count -ge 2) { $tabResults[1].exists } else { $null }
    tab1Content = if ($tabResults.Count -ge 1) { $tabResults[0].content } else { $null }
    tab2Content = if ($tabResults.Count -ge 2) { $tabResults[1].content } else { $null }
    tabs = $tabResults
    vtTraceEnabled = [bool]$EnableVtTrace
    vtTracePath = if (Test-Path $vtTracePath) { $vtTracePath } else { $null }
    passed = $passed
}

$report | ConvertTo-Json -Depth 4 | Set-Content -Path $ReportPath -Encoding UTF8
$report | ConvertTo-Json -Depth 4

if (-not $report.passed) {
    throw "startup-tabs smoke test failed"
}

Write-Host "Artifacts kept at: $RunRoot"
