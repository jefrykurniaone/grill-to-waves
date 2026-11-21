<#
.SYNOPSIS
Tests for install.ps1, run under the PowerShell edition that starts this script.

.DESCRIPTION
  pwsh -NoProfile -File tests/test-install.ps1              # PowerShell 7
  powershell -NoProfile -File tests/test-install.ps1        # Windows PowerShell 5.1

Every installer run goes through tests/lib/guarded-install.ps1 with the home directory redirected
to a scratch directory under the system temp path, and works from a snapshot of the checkout taken
when the script starts. The last test compares the real ~/.claude, ~/.agents and ~/.codex against a
fingerprint taken before the first one.

gh, glab, claude and codex are stand-ins on every run (tests/lib/stub-cli.js, started with node), so
no test signs in to a forge or registers an MCP server for real. Without node each stand-in only
exits 1, and the tests that read their calls are skipped.

The parity test also runs install.sh, so it needs a bash: `bash` on macOS and Linux, Git Bash on
Windows, or the WSL distribution named by G2W_WSL_DISTRO. Without one it is skipped, unless
G2W_REQUIRE_PARITY is 1, which turns the skip into a failure.

This file stays ASCII: Windows PowerShell 5.1 reads a script without a BOM in the ANSI codepage.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path $PSScriptRoot -Parent
$guard = Join-Path $PSScriptRoot 'lib/guarded-install.ps1'
$bashGuard = Join-Path $PSScriptRoot 'lib/guarded-install.sh'
$shell = (Get-Process -Id $PID).Path
$onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$onLinux = ($PSVersionTable.PSVersion.Major -ge 6) -and $IsLinux
$realHome = $HOME
$realCodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('g2w-tests-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $scratchRoot 'source'
$installer = Join-Path $source 'install.ps1'
$bashInstaller = Join-Path $source 'install.sh'
$mention = '(orchestrate|conduct|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)'
$installedPaths = @('.claude/skills', '.claude/agents', '.claude/statusline.js', '.agents/skills', '.codex/agents')
$pathSeparator = [System.IO.Path]::PathSeparator
$stubScript = Join-Path $PSScriptRoot 'lib/stub-cli.js'
$stubLog = Join-Path $scratchRoot 'stub-calls.log'
$stubNames = @('gh', 'glab', 'claude', 'codex', 'npx', 'markitdown-mcp')
$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$defaultStubs = $null
$allMcpFlags = @('-WithPlaywrightMcp', '-WithContext7Mcp', '-WithMarkitdownMcp')
$scratchName = Split-Path $scratchRoot -Leaf
$chromePresent = Join-Path $scratchRoot 'chrome-present'
$flatpakChrome = 'app/com.google.Chrome/current/active/files/extra/chrome'
$playwrightAdd = 'playwright -- npx -y @playwright/mcp@latest'
$linkBoth = @('-Target', 'both', '-SkipMattPocock', '-Link')

$results = @{ passed = 0; failed = 0; skipped = 0 }
$skipReason = $null

# --- Harness -------------------------------------------------------------------------------------
function Test-Case([string]$Name, [scriptblock]$Body) {
    $script:skipReason = $null
    try {
        & $Body | Out-Null
        if ($script:skipReason) {
            $script:results.skipped++
            Write-Host "SKIP  $Name ($script:skipReason)"
        }
        else {
            $script:results.passed++
            Write-Host "PASS  $Name"
        }
    }
    catch {
        $script:results.failed++
        Write-Host "FAIL  $Name"
        foreach ($line in ("$($_.Exception.Message)" -split "`r?`n")) { Write-Host "      $line" }
    }
}

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -cne $Actual) { throw "$Message`nexpected: $Expected`nactual:   $Actual" }
}

function Assert-SameLines($Expected, $Actual, [string]$Message) {
    $want = @($Expected)
    $have = @($Actual)
    $missing = @($want | Where-Object { $have -cnotcontains $_ })
    $extra = @($have | Where-Object { $want -cnotcontains $_ })
    if ($missing.Count -eq 0 -and $extra.Count -eq 0 -and $want.Count -eq $have.Count) { return }
    $report = @($Message)
    $report += @($missing | Select-Object -First 5 | ForEach-Object { "only expected: $_" })
    $report += @($extra | Select-Object -First 5 | ForEach-Object { "only actual:   $_" })
    throw ($report -join "`n")
}

function Assert-Succeeded($Run, [string]$What) {
    if ($Run.ExitCode -ne 0) { throw "$What exited $($Run.ExitCode):`n$($Run.Output)" }
}

# --- Scratch directories and installer runs ------------------------------------------------------
function New-ScratchHome([string]$Name) {
    $path = Join-Path $scratchRoot $Name
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $path '.g2w-scratch'), "test scratch home`n", $utf8NoBom)
    return $path
}

# Run install.ps1 through the guard. -Environment sets more variables for the run, or replaces the
# default PATH, which puts the stand-ins first. Calls holds what the stand-ins logged, one per line.
function Invoke-Installer([string]$ScratchHome, [string[]]$Arguments, [hashtable]$Environment = @{}, [string]$InstallerPath = $installer) {
    $variables = @{
        USERPROFILE = $ScratchHome; HOME = $ScratchHome; CODEX_HOME = (Join-Path $ScratchHome '.codex')
        G2W_CHROME_ROOT = $chromePresent
    }
    if ($defaultStubs) {
        $variables.PATH = $defaultStubs + $pathSeparator + $env:PATH
        $variables.G2W_STUB_LOG = $stubLog
    }
    foreach ($key in $Environment.Keys) { $variables[$key] = $Environment[$key] }
    $saved = @{}
    foreach ($key in $variables.Keys) { $saved[$key] = [System.Environment]::GetEnvironmentVariable($key) }
    if (Test-Path -LiteralPath $stubLog) { [System.IO.File]::Delete($stubLog) }
    $preference = $ErrorActionPreference
    $shellArguments = @('-NoProfile', '-NonInteractive')
    if ($onWindows) { $shellArguments += @('-ExecutionPolicy', 'Bypass') }
    $shellArguments += @('-File', $guard, '-ScratchHome', $ScratchHome, '-Installer', $InstallerPath)
    try {
        foreach ($key in $variables.Keys) { [System.Environment]::SetEnvironmentVariable($key, $variables[$key]) }
        # Windows PowerShell 5.1 turns a native command's stderr into terminating errors under Stop.
        $ErrorActionPreference = 'Continue'
        $output = @(& $shell @shellArguments @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $preference
        foreach ($key in $saved.Keys) { [System.Environment]::SetEnvironmentVariable($key, $saved[$key]) }
    }
    $calls = if (Test-Path -LiteralPath $stubLog) { @([System.IO.File]::ReadAllLines($stubLog)) } else { @() }
    return New-Object psobject -Property @{ ExitCode = $code; Output = ($output -join "`n"); Calls = $calls }
}

# A directory of stand-ins for the named programs, each running stub-cli.js under its own name.
# Without node each one only exits 1, which still keeps the real program from running.
function New-StubDirectory([string]$Name, [string[]]$Programs) {
    $dir = Join-Path $scratchRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($program in $Programs) {
        if ($onWindows) {
            $text = if ($node) { "@`"$($node.Source)`" `"$stubScript`" $program %*`r`n@exit /b %ERRORLEVEL%`r`n" } else { "@exit /b 1`r`n" }
            [System.IO.File]::WriteAllText((Join-Path $dir "$program.cmd"), $text, $utf8NoBom)
            continue
        }
        $path = Join-Path $dir $program
        $text = if ($node) { "#!/bin/sh`nexec '$($node.Source)' '$stubScript' $program `"`$@`"`n" } else { "#!/bin/sh`nexit 1`n" }
        [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
        & chmod +x $path
    }
    return $dir
}

function Test-DirectoryHolds([string]$Dir, [string[]]$Programs) {
    $extensions = @('')
    if ($onWindows) { $extensions += @($env:PATHEXT -split ';' | Where-Object { $_ }) }
    # String concatenation and File.Exists, because Join-Path throws on a PATH entry whose drive is gone.
    $prefix = $Dir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    foreach ($program in $Programs) {
        foreach ($extension in $extensions) {
            if ([System.IO.File]::Exists($prefix + $program + $extension)) { return $true }
        }
    }
    return $false
}

# PATH less every directory that holds one of the named programs. The installer needs nothing that
# shares a directory with them, and PowerShell is started by its full path.
function Get-PathWithout([string[]]$Programs) {
    $kept = @($env:PATH -split $pathSeparator | Where-Object { $_ -and -not (Test-DirectoryHolds $_ $Programs) })
    return ($kept -join $pathSeparator)
}

# Each line, indented as a note, is a whole line of the output.
function Assert-OutputLines([string]$Output, [string[]]$Lines) {
    foreach ($line in $Lines) {
        Assert-True ($Output -match ('(?m)^    ' + [regex]::Escape($line) + '\r?$')) "no line '$line':`n$Output"
    }
}

# Where install.sh can run from here: bash itself, a WSL distribution, or Git Bash.
function Get-BashRunner {
    if (-not $onWindows) {
        if (Get-Command bash -ErrorAction SilentlyContinue) { return @{ Kind = 'native'; Exe = 'bash' } }
        return $null
    }
    if ($env:G2W_WSL_DISTRO) { return @{ Kind = 'wsl'; Exe = 'wsl.exe'; Distro = $env:G2W_WSL_DISTRO } }
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) { return $null }
    $dir = Split-Path $git.Source -Parent
    foreach ($level in 1..3) {
        if (-not $dir) { break }
        $candidate = Join-Path $dir 'bin\bash.exe'
        if (Test-Path -LiteralPath $candidate) { return @{ Kind = 'gitbash'; Exe = $candidate } }
        $dir = Split-Path $dir -Parent
    }
    return $null
}

function ConvertTo-BashPath($Runner, [string]$Path) {
    if ($Runner.Kind -eq 'native') { return $Path }
    $forward = $Path.Replace('\', '/')
    if ($Runner.Kind -eq 'gitbash') { return $forward }
    $converted = @(& $Runner.Exe -d $Runner.Distro -- wslpath -a $forward)
    if ($LASTEXITCODE -ne 0 -or $converted.Count -eq 0) { throw "wslpath could not convert $Path." }
    return "$($converted[0])".Trim()
}

function Invoke-BashInstaller($Runner, [string]$ScratchHome, [string[]]$Arguments) {
    $savedUtf8 = $env:WSL_UTF8
    $preference = $ErrorActionPreference
    try {
        $env:WSL_UTF8 = '1'
        $bashArguments = @(
            (ConvertTo-BashPath $Runner $bashGuard),
            (ConvertTo-BashPath $Runner $ScratchHome),
            (ConvertTo-BashPath $Runner $bashInstaller)
        ) + $Arguments
        if ($Runner.Kind -eq 'wsl') { $bashArguments = @('-d', $Runner.Distro, '--', 'bash') + $bashArguments }
        $ErrorActionPreference = 'Continue'
        $output = @(& $Runner.Exe @bashArguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $preference
        $env:WSL_UTF8 = $savedUtf8
    }
    return New-Object psobject -Property @{ ExitCode = $code; Output = ($output -join "`n") }
}

# --- Reading trees -------------------------------------------------------------------------------
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# One "relative/path  SHA256" line per file under a directory, in ordinal order.
function Get-FileMap([string]$Dir) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $Dir -PathType Container) {
        $prefix = (Get-Item -LiteralPath $Dir -Force).FullName.TrimEnd('\', '/').Length + 1
        foreach ($file in @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force)) {
            $lines.Add($file.FullName.Substring($prefix).Replace('\', '/') + '  ' + (Get-Sha256 $file.FullName))
        }
    }
    $sorted = [string[]]$lines.ToArray()
    [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
    return $sorted
}

# What a scratch home holds, less the AppData folder that PowerShell, either edition, creates for
# its own startup caches under whatever USERPROFILE it is started with.
function Get-HomeFileMap([string]$HomeDir) {
    return @(Get-FileMap $HomeDir | Where-Object { $_ -notmatch '^AppData/' })
}

function Get-HomeEntries([string]$HomeDir) {
    return @(Get-ChildItem -LiteralPath $HomeDir -Force | ForEach-Object Name | Where-Object { $_ -ne 'AppData' })
}

# The installed tree of one home: the skills, agents and statusline, not the settings (they carry
# absolute paths) and not the backups.
function Get-InstalledManifest([string]$HomeDir) {
    $lines = @()
    foreach ($relative in $installedPaths) {
        $full = Join-Path $HomeDir $relative
        if (Test-Path -LiteralPath $full -PathType Leaf) { $lines += "$relative  $(Get-Sha256 $full)" }
        else { $lines += @(Get-FileMap $full | ForEach-Object { "$relative/$_" }) }
    }
    return , $lines
}

function Get-StatusLines([string]$Output) {
    return , @($Output -split "`r?`n" | Where-Object { $_ -match '^    (identical|linked|differs|not installed)\s{2,}\S' })
}

function Get-MatchCount([string]$Text, [string]$Pattern) {
    return [regex]::Matches($Text, $Pattern).Count
}

function Test-Link([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return [bool]($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint))
}

function Remove-TestLink([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if ($onWindows) { $item.Delete() }
    else { [System.IO.File]::Delete($item.FullName) }
}

function Get-SourceRelativeTarget([string]$Path) {
    $target = [string](@((Get-Item -LiteralPath $Path -Force).Target)[0])
    $at = $target.IndexOf($scratchName, [System.StringComparison]::OrdinalIgnoreCase)
    if ($at -lt 0) { return $target }
    return $target.Substring($at + $scratchName.Length).Replace('\', '/')
}

function Get-InstalledLinks([string]$HomeDir) {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($relative in @('.claude/skills', '.claude/agents', '.codex/agents', '.agents/skills')) {
        $dir = Join-Path $HomeDir $relative
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force)) {
            if (Test-Link $item.FullName) { $lines.Add("$relative/$($item.Name) -> $(Get-SourceRelativeTarget $item.FullName)") }
        }
    }
    $statusline = Join-Path $HomeDir '.claude/statusline.js'
    if (Test-Link $statusline) { $lines.Add(".claude/statusline.js -> $(Get-SourceRelativeTarget $statusline)") }
    $sorted = [string[]]$lines.ToArray()
    [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
    return , $sorted
}

function Get-ExpectedLinks([bool]$WithCodex) {
    $lines = @($skills | ForEach-Object { ".claude/skills/$_ -> /source/skills/$_" })
    $lines += @($claudeAgents | ForEach-Object { ".claude/agents/$_ -> /source/agents/$_" })
    $lines += '.claude/statusline.js -> /source/statusline/statusline.js'
    if ($WithCodex) { $lines += @($codexAgents | ForEach-Object { ".codex/agents/$_ -> /source/agents/codex/$_" }) }
    $sorted = [string[]]$lines
    [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
    return , $sorted
}

function Get-ReplacedBackups([string]$HomeDir) {
    $backups = Join-Path $HomeDir '.claude/backups'
    if (-not (Test-Path -LiteralPath $backups)) { return , @() }
    return , @(Get-ChildItem -LiteralPath $backups -Force | Where-Object { $_.Name -notlike 'settings.json-*' } | ForEach-Object Name)
}

function New-EmptyFile([string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    [System.IO.File]::WriteAllText($Path, '', $utf8NoBom)
}

function Get-PlaywrightExpectation([string]$Scenario, [string]$Root, [string]$HomeDir) {
    $chrome = "$Root/opt/google/chrome/chrome"
    switch ($Scenario) {
        'opt' { return @{ Arguments = ''; Note = '' } }
        'system' { $arguments = "--executable-path $Root/var/lib/flatpak/$flatpakChrome" }
        'user' { $arguments = "--executable-path $HomeDir/.local/share/flatpak/$flatpakChrome" }
        default {
            $note = "no Chrome at $chrome or in a Flatpak, so playwright runs Playwright's Chromium (--browser chromium). Install it once:  npx playwright install chromium"
            return @{ Arguments = '--browser chromium'; Note = $note }
        }
    }
    return @{ Arguments = $arguments; Note = "$chrome is missing, so playwright runs the Flatpak Chrome:  $arguments" }
}

function Assert-PlaywrightScenario([string]$Scenario, [string]$Stubs) {
    $root = Join-Path $scratchRoot "chrome-$Scenario"
    $scratch = New-ScratchHome "playwright-$Scenario"
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    if ($Scenario -eq 'opt') { New-EmptyFile "$root/opt/google/chrome/chrome" }
    if (@('opt', 'system') -contains $Scenario) { New-EmptyFile "$root/var/lib/flatpak/$flatpakChrome" }
    if (@('opt', 'system', 'user') -contains $Scenario) { New-EmptyFile "$scratch/.local/share/flatpak/$flatpakChrome" }
    $expected = Get-PlaywrightExpectation $Scenario $root $scratch
    $environment = @{ PATH = $Stubs + $pathSeparator + $defaultStubs + $pathSeparator + $env:PATH; G2W_CHROME_ROOT = $root }
    $run = Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock', '-WithPlaywrightMcp') $environment
    Assert-Succeeded $run "install.ps1 ($Scenario)"
    $extra = if ($expected.Arguments) { ' ' + $expected.Arguments } else { '' }
    foreach ($call in @("claude mcp add --scope user $playwrightAdd$extra", "codex mcp add $playwrightAdd$extra")) {
        Assert-True ($run.Calls -ccontains $call) "install.ps1 ($Scenario) did not run '$call':`n$($run.Calls -join "`n")"
    }
    if ($expected.Note) { Assert-OutputLines $run.Output @($expected.Note) }
    else { Assert-True ($run.Output -notmatch "Playwright's browser") "install.ps1 ($Scenario) printed a browser note although Chrome is in place:`n$($run.Output)" }
}

function New-DirectoryLink([string]$Path, [string]$TargetPath) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    $type = if ($onWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $type -Path $Path -Value $TargetPath | Out-Null
}

# --- The real home -------------------------------------------------------------------------------
# Walk without following links: a junction is recorded as a link, and its target is another root.
function Add-TreeLines($Lines, [string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { $Lines.Add("missing  $Path"); return }
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $Lines.Add("link  $Path -> $($item.Target)")
        return
    }
    if ($item.PSIsContainer) {
        $Lines.Add("dir  $Path")
        foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force)) { Add-TreeLines $Lines $child.FullName }
        return
    }
    try { $Lines.Add("file  $Path  $(Get-Sha256 $Path)") }
    catch { $Lines.Add("file  $Path  unreadable") }
}

# Everything an install could write in the real home. The backups are compared by entry name: the
# installer only ever adds entries there, and Claude Code keeps its own .claude.json backups in
# ~/.claude/backups while it runs.
function Get-RealHomeFingerprint {
    $lines = New-Object System.Collections.Generic.List[string]
    $claude = Join-Path $realHome '.claude'
    foreach ($path in @(
            (Join-Path $claude 'skills'), (Join-Path $claude 'agents'), (Join-Path $claude 'settings.json'),
            (Join-Path $claude 'statusline.js'), (Join-Path $realHome '.agents'),
            (Join-Path $realCodexHome 'agents'), (Join-Path $realCodexHome 'skills'))) {
        Add-TreeLines $lines $path
    }
    foreach ($backups in @((Join-Path $claude 'backups'), (Join-Path $realCodexHome 'backups'))) {
        if (-not (Test-Path -LiteralPath $backups)) { $lines.Add("missing  $backups"); continue }
        foreach ($entry in @(Get-ChildItem -LiteralPath $backups -Force | Where-Object { $_.Name -notlike '.claude.json*' })) {
            $lines.Add("backup  $($entry.FullName)")
        }
    }
    return , [string[]]$lines.ToArray()
}

function Remove-Scratch([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    # Unlink before deleting, deepest first, so nothing is ever deleted through a link.
    $links = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending)
    foreach ($link in $links) {
        Remove-TestLink $link.FullName
    }
    [System.IO.Directory]::Delete($Path, $true)
}

# --- Run -----------------------------------------------------------------------------------------
Write-Host ("install.ps1 tests - PowerShell {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

$before = Get-RealHomeFingerprint
New-Item -ItemType Directory -Force -Path $source | Out-Null
foreach ($name in @('install.ps1', 'install.sh', 'skills', 'agents', 'statusline')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination (Join-Path $source $name) -Recurse
}
$defaultStubs = New-StubDirectory 'stubs' @('gh', 'glab', 'claude', 'codex')
New-EmptyFile (Join-Path $chromePresent 'opt/google/chrome/chrome')
$skills = @(Get-ChildItem -LiteralPath (Join-Path $source 'skills') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object Name)
$claudeAgents = @(Get-ChildItem -LiteralPath (Join-Path $source 'agents') -Filter '*.md' -File | ForEach-Object Name)
$codexAgents = @(Get-ChildItem -LiteralPath (Join-Path $source 'agents/codex') -Filter '*.toml' -File | ForEach-Object Name)
$expectedStatusCount = (2 * $skills.Count) + $claudeAgents.Count + $codexAgents.Count

try {
    Test-Case 'guard: refuses a home that is not a marked scratch directory' {
        $unmarked = Join-Path $scratchRoot 'unmarked'
        New-Item -ItemType Directory -Force -Path $unmarked | Out-Null
        $run = Invoke-Installer $unmarked @('-Target', 'both', '-SkipMattPocock')
        Assert-True ($run.ExitCode -ne 0) 'the guard let an unmarked directory through'
        Assert-True ($run.Output -match 'Refusing to run the installer') "unexpected output:`n$($run.Output)"
        Assert-Equal '' ((Get-HomeEntries $unmarked) -join ', ') 'the unmarked directory was written to'
    }

    Test-Case 'end to end: -Target both installs every skill and agent into the scratch home' {
        $scratch = New-ScratchHome 'e2e'
        # A retired agent left by an earlier release has to go.
        foreach ($retired in @('.claude/agents/executor-fable-five-one-high.md', '.codex/agents/executor-fable-five-one-high.toml',
                '.claude/agents/scout-sonnet-medium.md', '.codex/agents/scout-sonnet-medium.toml')) {
            New-Item -ItemType Directory -Force -Path (Split-Path (Join-Path $scratch $retired) -Parent) | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $scratch $retired), "retired`n", $utf8NoBom)
        }
        $run = Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock')
        Assert-Succeeded $run 'install.ps1 -Target both'
        Assert-True ($run.Output -match '==> Done\.') "no Done line:`n$($run.Output)"
        Assert-True ($skills.Count -ge 5) "expected at least 5 skills in the checkout, found $($skills.Count)"

        foreach ($skill in $skills) {
            Assert-SameLines (Get-FileMap (Join-Path $source "skills/$skill")) (Get-FileMap (Join-Path $scratch ".claude/skills/$skill")) `
                "Claude Code copy of $skill is not the checkout's"
            # Codex rewrites only the Markdown at the top of the skill folder.
            $below = { $_ -notmatch '^[^/]+\.md  ' }
            Assert-SameLines @(Get-FileMap (Join-Path $source "skills/$skill") | Where-Object $below) `
                @(Get-FileMap (Join-Path $scratch ".agents/skills/$skill") | Where-Object $below) `
                "Codex copy of $skill differs outside its top-level Markdown"
            Assert-True (Test-Path -LiteralPath (Join-Path $scratch ".agents/skills/$skill/SKILL.md")) "Codex copy of $skill has no SKILL.md"
        }
        Assert-SameLines @(Get-FileMap (Join-Path $source 'agents') | Where-Object { $_ -match '^[^/]+\.md  ' }) `
            (Get-FileMap (Join-Path $scratch '.claude/agents')) 'Claude Code agents are not the checkout''s'
        Assert-SameLines (Get-FileMap (Join-Path $source 'agents/codex')) (Get-FileMap (Join-Path $scratch '.codex/agents')) `
            'Codex agents are not the checkout''s'
        Assert-Equal (Get-Sha256 (Join-Path $source 'statusline/statusline.js')) (Get-Sha256 (Join-Path $scratch '.claude/statusline.js')) `
            'statusline.js is not the checkout''s'

        $settingsPath = Join-Path $scratch '.claude/settings.json'
        $settings = [System.IO.File]::ReadAllText($settingsPath, $utf8NoBom) | ConvertFrom-Json
        $keys = @($settings.PSObject.Properties | ForEach-Object Name)
        Assert-True ($keys -contains 'attribution') 'settings.json has no attribution key'
        Assert-Equal '' $settings.attribution.commit 'attribution.commit is not empty'
        Assert-Equal '' $settings.attribution.pr 'attribution.pr is not empty'
        if (Get-Command node -ErrorAction SilentlyContinue) {
            Assert-True ($keys -contains 'statusLine') 'settings.json has no statusLine key although node is on PATH'
            Assert-True ($settings.statusLine.command -match 'statusline\.js') 'statusLine does not point at statusline.js'
        }

        Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.claude/agents/executor-fable-five-one-high.md'))) 'retired Claude Code agent was kept'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.codex/agents/executor-fable-five-one-high.toml'))) 'retired Codex agent was kept'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.claude/agents/scout-sonnet-medium.md'))) 'retired Claude Code scout was kept'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.codex/agents/scout-sonnet-medium.toml'))) 'retired Codex scout was kept'
        Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $scratch '.claude/backups') -Filter 'executor-fable-five-one-high.md-*').Count -eq 1) `
            'retired Claude Code agent was not backed up'

        $unexpected = @(Get-HomeEntries $scratch | Where-Object { @('.g2w-scratch', '.claude', '.agents', '.codex') -notcontains $_ })
        Assert-Equal '' ($unexpected -join ', ') 'the install wrote outside .claude, .agents and .codex'
    }

    Test-Case 'end to end: a second install moves the replaced skill to backups' {
        $scratch = New-ScratchHome 'reinstall'
        Assert-Succeeded (Invoke-Installer $scratch @('-Target', 'claude', '-SkipMattPocock')) 'first install'
        $private = Join-Path $scratch '.claude/skills/orchestrate/PRIVATE.md'
        [System.IO.File]::WriteAllText($private, "a private note`n", $utf8NoBom)
        $run = Invoke-Installer $scratch @('-Target', 'claude', '-SkipMattPocock')
        Assert-Succeeded $run 'second install'
        Assert-True ($run.Output -match 'backed up existing copy') "no backup note:`n$($run.Output)"
        Assert-True (-not (Test-Path -LiteralPath $private)) 'the replaced copy was merged into, not replaced'
        $kept = @(Get-ChildItem -LiteralPath (Join-Path $scratch '.claude/backups') -Directory -Filter 'orchestrate-*')
        Assert-Equal 1 $kept.Count 'expected one backup of orchestrate'
        Assert-True (Test-Path -LiteralPath (Join-Path $kept[0].FullName 'PRIVATE.md')) 'the backup lost the private file'
    }

    Test-Case 'end to end: -Project puts skills and agents in the project, settings in the home' {
        $scratch = New-ScratchHome 'project-home'
        $project = Join-Path $scratchRoot 'project-repo'
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        $run = Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock', '-Project', $project)
        Assert-Succeeded $run 'install.ps1 -Project'
        foreach ($expected in @('.claude/skills/orchestrate/SKILL.md', '.agents/skills/orchestrate/SKILL.md',
                ".claude/agents/$($claudeAgents[0])", ".codex/agents/$($codexAgents[0])")) {
            Assert-True (Test-Path -LiteralPath (Join-Path $project $expected)) "missing in the project: $expected"
        }
        foreach ($expected in @('.claude/settings.json', '.claude/statusline.js')) {
            Assert-True (Test-Path -LiteralPath (Join-Path $scratch $expected)) "missing in the home: $expected"
        }
        foreach ($absent in @('.claude/skills', '.claude/agents', '.agents', '.codex')) {
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch $absent))) "written to the home despite -Project: $absent"
        }
    }

    Test-Case 'codex conversion: mentions, agent directory and frontmatter are rewritten, nothing else' {
        $scratch = New-ScratchHome 'codex'
        Assert-Succeeded (Invoke-Installer $scratch @('-Target', 'codex', '-SkipMattPocock')) 'install.ps1 -Target codex'
        $slash = '(?m)(?<=^|[\s`(*])/' + $mention + '(?=$|[\s`).,;:*])'
        $dollar = '\$' + $mention + '(?![\w/-])'
        $segment = '(?<=[\w.])/' + $mention
        $frontmatter = '(?m)^disable-model-invocation: true\r?\n'
        $totals = @{ slash = 0; directory = 0; frontmatter = 0 }
        foreach ($skill in $skills) {
            foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $source "skills/$skill") -Filter '*.md' -File)) {
                $label = "$skill/$($file.Name)"
                $installedPath = Join-Path $scratch ".agents/skills/$skill/$($file.Name)"
                $bytes = [System.IO.File]::ReadAllBytes($installedPath)
                Assert-True (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) "$label gained a BOM"
                $from = [System.IO.File]::ReadAllText($file.FullName, $utf8NoBom)
                $to = [System.IO.File]::ReadAllText($installedPath, $utf8NoBom)

                $mentions = Get-MatchCount $from $slash
                $directories = Get-MatchCount $from '\.claude[/\\](worktrees|scratch)'
                $dropped = [regex]::Matches($from, $frontmatter)
                $totals.slash += $mentions
                $totals.directory += $directories
                $totals.frontmatter += $dropped.Count

                Assert-Equal 0 (Get-MatchCount $to $slash) "$label still has slash mentions"
                Assert-True (((Get-MatchCount $to $dollar) - (Get-MatchCount $from $dollar)) -ge $mentions) "$label gained fewer `$ mentions than it had slash mentions"
                Assert-Equal 0 (Get-MatchCount $to '\.claude[/\\](worktrees|scratch)') "$label still names .claude/worktrees or .claude/scratch"
                Assert-Equal ($directories + (Get-MatchCount $from '\.codex[/\\](worktrees|scratch)')) (Get-MatchCount $to '\.codex[/\\](worktrees|scratch)') `
                    "$label has the wrong number of .codex/ paths"
                Assert-Equal 0 (Get-MatchCount $to '(?m)^disable-model-invocation:') "$label kept the disable-model-invocation line"
                Assert-Equal (Get-MatchCount $from $segment) (Get-MatchCount $to $segment) "$label had a path segment rewritten"
                Assert-Equal (Get-MatchCount $from '[^\x00-\x7F]') (Get-MatchCount $to '[^\x00-\x7F]') "$label lost or gained non-ASCII characters"
                # `/name` -> `$name` keeps the length, `.claude` -> `.codex` drops one character, and
                # the frontmatter line goes whole. Any other edit breaks this sum.
                $droppedLength = 0
                foreach ($match in $dropped) { $droppedLength += $match.Length }
                Assert-Equal ($from.Length - $directories - $droppedLength) $to.Length "$label changed by more than the three rewrites"
            }
        }
        Assert-True ($totals.slash -gt 0) 'no skill in the checkout has a slash mention, so the test proves nothing'
        Assert-True ($totals.directory -gt 0) 'no skill in the checkout names .claude/worktrees or .claude/scratch'
        Assert-True ($totals.frontmatter -ge $skills.Count) 'a skill in the checkout has no disable-model-invocation line'

        $orchestrate = [System.IO.File]::ReadAllText((Join-Path $scratch '.agents/skills/orchestrate/SKILL.md'), $utf8NoBom)
        Assert-True ($orchestrate.Contains('$grill-to-waves')) 'orchestrate/SKILL.md does not mention $grill-to-waves'
        Assert-True ($orchestrate.Contains('.codex/worktrees')) 'orchestrate/SKILL.md does not name .codex/worktrees'
        Assert-True ($orchestrate.Contains('../grill-to-waves/')) 'orchestrate/SKILL.md lost its ../grill-to-waves/ links'
    }

    foreach ($noBackup in @($false, $true)) {
        $variant = if ($noBackup) { 'with -NoBackup' } else { 'with a backup' }
        Test-Case "link destination: the link is removed and its target is left alone ($variant)" {
            $scratch = New-ScratchHome "link-$noBackup"
            $targets = @{}
            foreach ($root in @('.claude/skills', '.agents/skills')) {
                $target = Join-Path $scratchRoot ("link-target-$noBackup-" + $root.Replace('/', '-').TrimStart('.'))
                New-Item -ItemType Directory -Force -Path (Join-Path $target 'nested') | Out-Null
                [System.IO.File]::WriteAllText((Join-Path $target 'keep.txt'), "keep me`n", $utf8NoBom)
                [System.IO.File]::WriteAllText((Join-Path $target 'nested/keep.txt'), "keep me too`n", $utf8NoBom)
                New-DirectoryLink (Join-Path $scratch "$root/orchestrate") $target
                Assert-True (Test-Link (Join-Path $scratch "$root/orchestrate")) "could not create a link at $root/orchestrate"
                $targets[$root] = @{ Path = $target; Before = (Get-FileMap $target) }
            }
            $arguments = @('-Target', 'both', '-SkipMattPocock')
            if ($noBackup) { $arguments += '-NoBackup' }
            $run = Invoke-Installer $scratch $arguments
            Assert-Succeeded $run 'install over a link'
            foreach ($root in $targets.Keys) {
                $dest = Join-Path $scratch "$root/orchestrate"
                Assert-True (-not (Test-Link $dest)) "$root/orchestrate is still a link"
                Assert-True (Test-Path -LiteralPath (Join-Path $dest 'SKILL.md')) "$root/orchestrate has no SKILL.md"
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $dest 'keep.txt'))) "$root/orchestrate was installed into the link's target"
                Assert-SameLines $targets[$root].Before (Get-FileMap $targets[$root].Path) "the target of $root/orchestrate was changed through the link"
            }
            Assert-Equal 2 (Get-MatchCount $run.Output '(?m)^    unlinked ') "expected two unlinked notes:`n$($run.Output)"
        }
    }

    Test-Case 'status: not installed, then identical, then differs, and it never writes' {
        $scratch = New-ScratchHome 'status'
        $empty = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $empty '-Status on an empty home'
        $lines = Get-StatusLines $empty.Output
        Assert-Equal $expectedStatusCount $lines.Count "wrong number of status lines:`n$($empty.Output)"
        Assert-Equal 0 (@($lines | Where-Object { $_ -notmatch '^    not installed  ' }).Count) "an empty home reported something installed:`n$($empty.Output)"
        Assert-Equal '.g2w-scratch' ((Get-HomeEntries $scratch) -join ', ') '-Status wrote to an empty home'
        Assert-OutputLines $empty.Output @('gh (GitHub): installed', 'glab (GitLab): installed')
        Assert-Equal '' ($empty.Calls -join ' | ') '-Status ran a forge CLI, so it did not stay offline'

        Assert-Succeeded (Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock')) 'install before -Status'
        $installed = Get-HomeFileMap $scratch
        $clean = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $clean '-Status after an install'
        $lines = Get-StatusLines $clean.Output
        Assert-Equal $expectedStatusCount $lines.Count "wrong number of status lines:`n$($clean.Output)"
        Assert-Equal 0 (@($lines | Where-Object { $_ -notmatch '^    identical      \S+$' }).Count) "a fresh install is not identical:`n$($clean.Output)"
        Assert-True ($clean.Output -match "==> Status: $expectedStatusCount identical, 0 linked, 0 differs, 0 not installed\.") "wrong summary:`n$($clean.Output)"
        Assert-SameLines $installed (Get-HomeFileMap $scratch) '-Status changed the installed tree'

        # A private variant, an extra file, a changed agent and a deleted agent.
        $variant = Join-Path $scratch '.claude/skills/orchestrate/SKILL.md'
        [System.IO.File]::AppendAllText($variant, "`nA private rule.`n", $utf8NoBom)
        [System.IO.File]::WriteAllText((Join-Path $scratch '.agents/skills/ship-it-to/extra.txt'), "extra`n", $utf8NoBom)
        [System.IO.File]::AppendAllText((Join-Path $scratch ".claude/agents/$($claudeAgents[0])"), "`nchanged`n", $utf8NoBom)
        [System.IO.File]::Delete((Join-Path $scratch ".codex/agents/$($codexAgents[0])"))
        $changed = Get-HomeFileMap $scratch
        $drift = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $drift '-Status with a private variant (differs is not an error)'
        $parts = $drift.Output -split '==> Status: Codex CLI'
        Assert-Equal 2 $parts.Count "no Codex section:`n$($drift.Output)"
        Assert-True ($parts[0] -match '(?m)^    differs        skills/orchestrate  \(SKILL\.md\)\r?$') "Claude Code orchestrate not reported as differs:`n$($drift.Output)"
        Assert-True ($parts[0] -match ('(?m)^    differs        agents/' + [regex]::Escape($claudeAgents[0]) + '\r?$')) "changed agent not reported as differs:`n$($drift.Output)"
        Assert-True ($parts[1] -match '(?m)^    differs        skills/ship-it-to  \(extra\.txt\)\r?$') "Codex ship-it-to not reported as differs:`n$($drift.Output)"
        Assert-True ($parts[1] -match ('(?m)^    not installed  agents/' + [regex]::Escape($codexAgents[0]) + '\r?$')) "deleted agent not reported as not installed:`n$($drift.Output)"
        Assert-True ($drift.Output -match "==> Status: $($expectedStatusCount - 4) identical, 0 linked, 3 differs, 1 not installed\.") "wrong summary:`n$($drift.Output)"
        Assert-SameLines $changed (Get-HomeFileMap $scratch) '-Status changed a tree that differs'
    }

    Test-Case 'forge CLIs and MCP servers: reported, registered through the host CLIs, an existing name kept' {
        if (-not $node) { $script:skipReason = 'no node found to run the CLI stand-ins'; return }
        $scratch = New-ScratchHome 'mcp'
        $stubs = New-StubDirectory 'stubs-all' $stubNames
        $environment = @{
            PATH = $stubs + $pathSeparator + $env:PATH; G2W_STUB_SIGNED_IN = 'gh'
            G2W_STUB_CLAUDE_SERVERS = 'playwright'; G2W_STUB_CODEX_SERVERS = 'markitdown'
        }
        $plain = Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock') $environment
        Assert-Succeeded $plain 'install without an MCP flag'
        Assert-Equal 'gh auth status | glab auth status' ($plain.Calls -join ' | ') 'an install without an MCP flag ran more than the sign-in checks'
        Assert-OutputLines $plain.Output @('gh (GitHub): signed in', 'glab (GitLab): installed, not signed in - run  glab auth login')
        Assert-True ($plain.Output -notmatch 'neither gh nor glab') "warned about missing forge CLIs:`n$($plain.Output)"

        $run = Invoke-Installer $scratch (@('-Target', 'both', '-SkipMattPocock') + $allMcpFlags) $environment
        Assert-Succeeded $run 'install with every MCP flag'
        $markitdown = Join-Path $stubs $(if ($onWindows) { 'markitdown-mcp.cmd' } else { 'markitdown-mcp' })
        $expected = @(
            'claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest',
            'claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp',
            "claude mcp add --scope user markitdown -- $markitdown",
            'codex mcp get playwright', 'codex mcp add playwright -- npx -y @playwright/mcp@latest',
            'codex mcp get context7', 'codex mcp add context7 -- npx -y @upstash/context7-mcp',
            'codex mcp get markitdown', 'gh auth status', 'glab auth status')
        Assert-Equal ($expected -join "`n") ($run.Calls -join "`n") 'the installer made the wrong host CLI calls'
        Assert-OutputLines $run.Output @(
            'kept the existing playwright MCP server for Claude Code',
            'registered context7 for Claude Code:  claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp',
            "registered markitdown for Claude Code:  claude mcp add --scope user markitdown -- $markitdown",
            'registered playwright for Codex CLI:  codex mcp add playwright -- npx -y @playwright/mcp@latest',
            'registered context7 for Codex CLI:  codex mcp add context7 -- npx -y @upstash/context7-mcp',
            'kept the existing markitdown MCP server for Codex CLI')
    }

    Test-Case 'forge CLIs and MCP servers: what is not on PATH is reported, and a server the host has is kept' {
        if (-not $node) { $script:skipReason = 'no node found to run the CLI stand-ins'; return }
        $scratch = New-ScratchHome 'mcp-missing'
        $bare = Get-PathWithout $stubNames
        $arguments = @('-Target', 'both', '-SkipMattPocock') + $allMcpFlags

        $run = Invoke-Installer $scratch $arguments @{ PATH = $bare }
        Assert-Succeeded $run 'install with every MCP flag and nothing on PATH'
        Assert-Equal '' ($run.Calls -join ' | ') 'a CLI ran although none was on PATH'
        Assert-OutputLines $run.Output @('gh (GitHub): not installed', 'glab (GitLab): not installed')
        Assert-True ($run.Output -match '(?m)^    WARNING: neither gh nor glab is installed, so the pipeline falls back to local Markdown under \.scratch/\.') `
            "no warning about the missing forge CLIs:`n$($run.Output)"
        foreach ($cli in @('claude mcp add --scope user', 'codex mcp add')) {
            $name = $cli.Split(' ')[0]
            $hostName = if ($name -eq 'claude') { 'Claude Code' } else { 'Codex CLI' }
            foreach ($server in @('playwright', 'context7', 'markitdown')) {
                Assert-True ($run.Output -match "(?m)^    WARNING: $name is not on PATH, so $server was not registered for $hostName\. Run:  $cli ") `
                    "no warning about $name for ${server}:`n$($run.Output)"
            }
        }

        # The host CLIs are there, npx and markitdown-mcp are not, and each host already has one server.
        $stubs = New-StubDirectory 'stubs-hosts' @('claude', 'codex')
        $environment = @{ PATH = $stubs + $pathSeparator + $bare; G2W_STUB_CLAUDE_SERVERS = 'playwright'; G2W_STUB_CODEX_SERVERS = 'context7' }
        $run = Invoke-Installer $scratch $arguments $environment
        Assert-Succeeded $run 'install with every MCP flag and no npx or markitdown-mcp'
        $expected = @(
            'claude mcp get playwright',
            'claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp',
            'claude mcp get markitdown', 'codex mcp get playwright', 'codex mcp get context7', 'codex mcp get markitdown')
        Assert-Equal ($expected -join "`n") ($run.Calls -join "`n") 'the installer made the wrong host CLI calls'
        Assert-OutputLines $run.Output @(
            'kept the existing playwright MCP server for Claude Code',
            'registered context7 for Claude Code:  claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp',
            'WARNING: markitdown-mcp is not on PATH, so markitdown was not registered for Claude Code. Install it with  pip install markitdown-mcp , then run the installer again.',
            'WARNING: npx is not on PATH, so playwright was not registered for Codex CLI. Install Node.js, which ships npx, then run the installer again.',
            'kept the existing context7 MCP server for Codex CLI',
            'WARNING: markitdown-mcp is not on PATH, so markitdown was not registered for Codex CLI. Install it with  pip install markitdown-mcp , then run the installer again.')
    }

    Test-Case 'parity: install.ps1 and install.sh produce the same tree for -Target both' {
        $runner = Get-BashRunner
        if (-not $runner) {
            if ($env:G2W_REQUIRE_PARITY -eq '1') { throw 'G2W_REQUIRE_PARITY is 1 and no bash was found to run install.sh.' }
            $script:skipReason = 'no bash found; set G2W_WSL_DISTRO or install Git Bash'
            return
        }
        $fromPs1 = New-ScratchHome 'parity-ps1'
        $fromSh = New-ScratchHome 'parity-sh'
        Assert-Succeeded (Invoke-Installer $fromPs1 @('-Target', 'both', '-SkipMattPocock')) 'install.ps1'
        Assert-Succeeded (Invoke-BashInstaller $runner $fromSh @('--target', 'both', '--skip-mattpocock')) "install.sh ($($runner.Kind))"
        $manifest = Get-InstalledManifest $fromPs1
        Assert-True ($manifest.Count -gt $expectedStatusCount) 'the install.ps1 tree is suspiciously small'
        Assert-SameLines $manifest (Get-InstalledManifest $fromSh) 'install.ps1 and install.sh produced different trees'

        # Each installer's status mode agrees that the other's install is what it would write.
        $crossSh = Invoke-BashInstaller $runner $fromPs1 @('--target', 'both', '--status')
        Assert-Succeeded $crossSh 'install.sh --status on the install.ps1 tree'
        $crossPs1 = Invoke-Installer $fromSh @('-Status', '-Target', 'both')
        Assert-Succeeded $crossPs1 'install.ps1 -Status on the install.sh tree'
        foreach ($cross in @($crossSh, $crossPs1)) {
            $lines = Get-StatusLines $cross.Output
            Assert-Equal $expectedStatusCount $lines.Count "wrong number of status lines:`n$($cross.Output)"
            Assert-Equal 0 (@($lines | Where-Object { $_ -notmatch '^    identical      \S+$' }).Count) "status across installers is not identical:`n$($cross.Output)"
        }
        Assert-SameLines (Get-StatusLines $crossPs1.Output) (Get-StatusLines $crossSh.Output) 'the two status reports differ'
    }

    Test-Case 'link mode: -Link links every skill, agent and statusline.js to the checkout; a second run keeps them' {
        $scratch = New-ScratchHome 'link-mode'
        $sourceBefore = Get-FileMap $source
        $run = Invoke-Installer $scratch $linkBoth
        Assert-Succeeded $run 'install.ps1 -Link'
        Assert-SameLines (Get-ExpectedLinks $true) (Get-InstalledLinks $scratch) 'the links are not the checkout''s'
        foreach ($skill in $skills) {
            Assert-True (-not (Test-Link (Join-Path $scratch ".agents/skills/$skill"))) "Codex $skill is a link, so it was not rewritten"
            Assert-True (Test-Path -LiteralPath (Join-Path $scratch ".agents/skills/$skill/SKILL.md")) "Codex $skill was not installed"
        }
        $orchestrate = [System.IO.File]::ReadAllText((Join-Path $scratch '.agents/skills/orchestrate/SKILL.md'), $utf8NoBom)
        Assert-True ($orchestrate.Contains('$grill-to-waves')) 'Codex orchestrate was not rewritten'
        Assert-Equal '' ((Get-ReplacedBackups $scratch) -join ', ') 'a link install into an empty home made a backup'
        Assert-OutputLines $run.Output @('Codex skills are copied, not linked: the installer rewrites them for Codex.')

        $links = Get-InstalledLinks $scratch
        $again = Invoke-Installer $scratch $linkBoth
        Assert-Succeeded $again 'a second install.ps1 -Link'
        Assert-Equal ((Get-ExpectedLinks $true).Count) (Get-MatchCount $again.Output '(?m)^    already linked ') "a second run did not leave every link alone:`n$($again.Output)"
        Assert-Equal 0 (Get-MatchCount $again.Output '(?m)^    (linked .* -> |unlinked )') "a second run replaced a link:`n$($again.Output)"
        Assert-Equal '' ((Get-ReplacedBackups $scratch) -join ', ') 'a second run backed up a link'
        Assert-SameLines $links (Get-InstalledLinks $scratch) 'a second run changed the links'
        Assert-SameLines $sourceBefore (Get-FileMap $source) 'the install wrote into the checkout'
    }

    foreach ($noBackup in @($false, $true)) {
        $variant = if ($noBackup) { 'with -NoBackup, without a backup' } else { 'moved to backups first' }
        Test-Case "link mode: -Link replaces an existing copy ($variant)" {
            $scratch = New-ScratchHome "link-over-copy-$noBackup"
            Assert-Succeeded (Invoke-Installer $scratch @('-Target', 'claude', '-SkipMattPocock')) 'the copy install'
            [System.IO.File]::WriteAllText((Join-Path $scratch '.claude/skills/orchestrate/PRIVATE.md'), "a private note`n", $utf8NoBom)
            $arguments = @('-Target', 'claude', '-SkipMattPocock', '-Link')
            if ($noBackup) { $arguments += '-NoBackup' }
            $run = Invoke-Installer $scratch $arguments
            Assert-Succeeded $run 'install.ps1 -Link over a copy'
            Assert-SameLines (Get-ExpectedLinks $false) (Get-InstalledLinks $scratch) 'the copies were not replaced by links'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $source 'skills/orchestrate/PRIVATE.md'))) 'the replaced copy was merged into the checkout'
            $replaced = (Get-ExpectedLinks $false).Count
            if ($noBackup) {
                Assert-Equal $replaced (Get-MatchCount $run.Output '(?m)^    replacing .* \(no backup\)\r?$') "expected $replaced replacements:`n$($run.Output)"
                Assert-Equal '' ((Get-ReplacedBackups $scratch) -join ', ') '-NoBackup made a backup'
                return
            }
            Assert-Equal $replaced (Get-MatchCount $run.Output '(?m)^    backed up existing copy to ') "expected $replaced backups:`n$($run.Output)"
            $backups = Join-Path $scratch '.claude/backups'
            $kept = @(Get-ChildItem -LiteralPath $backups -Directory -Filter 'orchestrate-*')
            Assert-Equal 1 $kept.Count 'expected one backup of orchestrate'
            Assert-True (Test-Path -LiteralPath (Join-Path $kept[0].FullName 'PRIVATE.md')) 'the backup of orchestrate lost the private file'
            Assert-Equal 1 (@(Get-ChildItem -LiteralPath $backups -Filter "$($claudeAgents[0])-*").Count) 'the agent copy was not backed up'
            Assert-Equal 1 (@(Get-ChildItem -LiteralPath $backups -Filter 'statusline.js-*').Count) 'statusline.js was not backed up'
        }
    }

    Test-Case 'link mode: -Status reports a link to the checkout as linked, a link elsewhere as differs' {
        $scratch = New-ScratchHome 'link-status'
        Assert-Succeeded (Invoke-Installer $scratch $linkBoth) 'install.ps1 -Link'
        $linked = $skills.Count + $claudeAgents.Count + $codexAgents.Count
        $run = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $run '-Status after a link install'
        $lines = Get-StatusLines $run.Output
        Assert-Equal $expectedStatusCount $lines.Count "wrong number of status lines:`n$($run.Output)"
        Assert-Equal $linked (@($lines | Where-Object { $_ -match '^    linked         \S+$' }).Count) "expected $linked linked lines:`n$($run.Output)"
        Assert-True ($run.Output -match "==> Status: $($skills.Count) identical, $linked linked, 0 differs, 0 not installed\.") "wrong summary:`n$($run.Output)"

        $elsewhere = Join-Path $scratch ".claude/agents/$($claudeAgents[0])"
        Remove-TestLink $elsewhere
        New-Item -ItemType SymbolicLink -Path $elsewhere -Value ([System.IO.Path]::GetFullPath((Join-Path $source "agents/$($claudeAgents[1])"))) | Out-Null
        $run = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $run '-Status with a link elsewhere'
        Assert-True ($run.Output -match ('(?m)^    differs        agents/' + [regex]::Escape($claudeAgents[0]) + '  \(links elsewhere\)\r?$')) "a link elsewhere was not reported as differs:`n$($run.Output)"
        Assert-True ($run.Output -match "==> Status: $($skills.Count) identical, $($linked - 1) linked, 1 differs, 0 not installed\.") "wrong summary:`n$($run.Output)"
    }

    Test-Case 'link mode: an install without -Link replaces the links with copies and leaves the checkout alone' {
        $scratch = New-ScratchHome 'link-back'
        $sourceBefore = Get-FileMap $source
        Assert-Succeeded (Invoke-Installer $scratch $linkBoth) 'install.ps1 -Link'
        $run = Invoke-Installer $scratch @('-Target', 'both', '-SkipMattPocock')
        Assert-Succeeded $run 'a copy install over links'
        Assert-Equal '' ((Get-InstalledLinks $scratch) -join ', ') 'links were left'
        Assert-Equal ((Get-ExpectedLinks $true).Count) (Get-MatchCount $run.Output '(?m)^    unlinked ') "expected every link to be unlinked:`n$($run.Output)"
        Assert-SameLines $sourceBefore (Get-FileMap $source) 'the copy install wrote into the checkout through a link'
        $status = Invoke-Installer $scratch @('-Status', '-Target', 'both')
        Assert-Succeeded $status '-Status'
        Assert-True ($status.Output -match "==> Status: $expectedStatusCount identical, 0 linked, 0 differs, 0 not installed\.") "the copies are not the checkout's:`n$($status.Output)"
    }

    Test-Case 'link mode: -Link without a local checkout stops before any change' {
        $scratch = New-ScratchHome 'link-no-checkout'
        $lone = Join-Path $scratchRoot 'lone'
        New-Item -ItemType Directory -Force -Path $lone | Out-Null
        Copy-Item -LiteralPath $installer -Destination $lone
        $run = Invoke-Installer $scratch @('-Target', 'both', '-Link') @{} (Join-Path $lone 'install.ps1')
        Assert-True ($run.ExitCode -ne 0) "install.ps1 -Link without a checkout succeeded:`n$($run.Output)"
        $squeezed = $run.Output -replace '[\s|+]', ''
        Assert-True ($squeezed -match '-Linklinkstheinstalledcopiestoalocalcheckout\.Runitfromaclone\.') "no refusal:`n$($run.Output)"
        Assert-Equal '.g2w-scratch' ((Get-HomeEntries $scratch) -join ', ') 'install.ps1 -Link without a checkout wrote to the home'
    }

    Test-Case 'playwright: Chrome in /opt as is, else a Flatpak Chrome, else Playwright''s Chromium' {
        if (-not $node) { $script:skipReason = 'no node found to run the CLI stand-ins'; return }
        if (-not $onLinux) { $script:skipReason = 'the Chrome lookup runs on Linux only'; return }
        $stubs = New-StubDirectory 'stubs-playwright' @('claude', 'codex', 'npx')
        foreach ($scenario in @('opt', 'system', 'user', 'none')) { Assert-PlaywrightScenario $scenario $stubs }
    }
}
finally {
    Remove-Scratch $scratchRoot
}

Test-Case 'real home: ~/.claude, ~/.agents and ~/.codex are what they were before the run' {
    Assert-SameLines $before (Get-RealHomeFingerprint) "the real home under $realHome changed during the run"
}

Write-Host ("{0} passed, {1} failed, {2} skipped" -f $results.passed, $results.failed, $results.skipped)
if ($results.failed -gt 0) { exit 1 }
exit 0
