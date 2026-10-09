<#
.SYNOPSIS
Install the grill-to-waves, orchestrate, ship-it-to, daily-recap and jira-comment skills and their
executor/scout/scribe agents for Claude Code and/or Codex CLI.

.DESCRIPTION
Claude Code:
  skills/grill-to-waves  ->  ~/.claude/skills/grill-to-waves      (or <project>/.claude/skills/...)
  skills/orchestrate     ->  ~/.claude/skills/orchestrate
  skills/ship-it-to      ->  ~/.claude/skills/ship-it-to
  skills/daily-recap     ->  ~/.claude/skills/daily-recap
  skills/jira-comment    ->  ~/.claude/skills/jira-comment
  agents/*.md            ->  ~/.claude/agents/
  statusline/statusline.js   ->  ~/.claude/statusline.js                   (always user scope)
  "attribution": { "commit": "", "pr": "" }  ->  ~/.claude/settings.json   (always user scope;
                            an existing attribution key is kept, and so is an existing statusLine)

Codex CLI:
  skills/grill-to-waves  ->  ~/.agents/skills/grill-to-waves      (or <project>/.agents/skills/...)
  skills/orchestrate     ->  ~/.agents/skills/orchestrate
  skills/ship-it-to      ->  ~/.agents/skills/ship-it-to
  skills/daily-recap     ->  ~/.agents/skills/daily-recap
  skills/jira-comment    ->  ~/.agents/skills/jira-comment
  agents/codex/*.toml    ->  ~/.codex/agents/                     (or <project>/.codex/agents/)

Both hosts, into the same skills directory as above:
  github.com/mattpocock/skills, cloned at its latest release  ->  one folder per skill that
  release ships (its .claude-plugin/plugin.json), minus -MattPocockExclude

The skill text is written in Claude Code's vocabulary. For Codex the installer rewrites, and only
rewrites: the skill invocation prefix (`/orchestrate` -> `$orchestrate`, including the setup skill
and the two grill skills), the agent directory (`.claude/worktrees`, `.claude/scratch` ->
`.codex/...`) and drops the `disable-model-invocation` frontmatter line, whose Codex equivalent is
the skill's `agents/openai.yaml` (`allow_implicit_invocation: false`), shipped in the repo.

Any directory it is about to replace is first moved to <backups>/<name>-<timestamp>, unless
-NoBackup is given. Backups: ~/.claude/backups for Claude Code, ~/.codex/backups for Codex.

-Status installs nothing. From a local checkout it lists every skill folder and agent file the
installer would install for the chosen target as `identical`, `differs` or `not installed`,
comparing byte for byte against what an install would write (for Codex, the rewritten skill text).
It reads no network and writes no file, leaves the Matt Pocock collection out, and exits 0 whatever
it finds: a copy that differs may be a private variant kept on purpose.

.EXAMPLE
./install.ps1
.EXAMPLE
./install.ps1 -Status -Target both
.EXAMPLE
./install.ps1 -Target codex
.EXAMPLE
./install.ps1 -Target claude -Project D:\WORK\PROJECT\my-repo
.EXAMPLE
irm https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Target,

    # Install into a project instead of the user's home: <path>/.claude for Claude Code,
    # <path>/.agents/skills and <path>/.codex/agents for Codex.
    [string]$Project,

    # Skip the backup of a directory or file being replaced.
    [switch]$NoBackup,

    # Branch, tag or commit to fetch when the script is run without a local checkout.
    [string]$Ref = 'main',

    # Do not fetch the Matt Pocock skill collection (offline, or installed some other way).
    [switch]$SkipMattPocock,

    # Matt Pocock skills left out of the install. `pr` dictates a pull request body template, and
    # this pipeline leaves the body to the repository's own convention.
    [string[]]$MattPocockExclude = @('pr'),

    # Install nothing: report how the installed copies relate to this checkout. Read-only, offline.
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'https://github.com/jefrykurniaone/grill-to-waves.git'
$Skills = @('grill-to-waves', 'orchestrate', 'ship-it-to', 'daily-recap', 'jira-comment')
$RequiredMattPocockSkills = @('grilling', 'domain-modeling', 'setup-matt-pocock-skills')
# Agent definitions this repo used to ship and no longer does. A copy left in the agent directory
# would keep registering a tier the skills no longer dispatch, so the installer removes it.
$RetiredAgents = @('executor-fable-five-one-medium', 'executor-fable-five-one-high', 'executor-fable-five-one-xhigh')
$MattPocockRepo = 'mattpocock/skills'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Step([string]$Message) { Write-Host "==> $Message" }
function Write-Note([string]$Message) { Write-Host "    $Message" }

function Select-InstallTarget {
    Write-Step 'Choose an install target:'
    Write-Note '[1] Claude Code'
    Write-Note '[2] Codex CLI'
    Write-Note '[3] Both'

    while ($true) {
        [string]$choice = Read-Host 'Enter 1, 2 or 3'
        switch ($choice.Trim().ToLowerInvariant()) {
            { $_ -in @('1', 'claude') } { return 'claude' }
            { $_ -in @('2', 'codex') } { return 'codex' }
            { $_ -in @('3', 'both') } { return 'both' }
            default { Write-Note 'Invalid choice. Enter 1, 2 or 3.' }
        }
    }
}

# Validate here instead of using [ValidateSet] on the parameter. Windows PowerShell 5.1 applies
# attributes to a null variable when a script is evaluated through `irm ... | iex`, which fails
# before the installer can prompt for an optional target.
$validTargets = @('claude', 'codex', 'both', 'auto')
if ($PSBoundParameters.ContainsKey('Target')) {
    if ($validTargets -notcontains $Target) {
        throw "-Target must be one of: $($validTargets -join ', ')."
    }
}
else {
    $Target = Select-InstallTarget
}
Write-Step "Install target: $Target"

# --- 1. Locate the source tree -------------------------------------------------------------------
# Run from a clone: use the script's own directory. Run through `irm | iex`: clone to a temp dir.
$sourceRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills/grill-to-waves/SKILL.md'))) {
    $sourceRoot = $PSScriptRoot
    Write-Step "Source: local checkout at $sourceRoot"
}
else {
    if ($Status) {
        throw '-Status compares the installed copies against a local checkout. Run it from a clone.'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git is required to fetch the skills when the script runs without a local checkout.'
    }
    $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) "grill-to-waves-$Stamp"
    Write-Step "Source: cloning $Repo ($Ref) to $sourceRoot"
    git clone --quiet --depth 1 --branch $Ref $Repo $sourceRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE." }
}

foreach ($skill in $Skills) {
    $manifest = Join-Path $sourceRoot "skills/$skill/SKILL.md"
    if (-not (Test-Path $manifest)) { throw "Source tree is incomplete: $manifest is missing." }
}
if (-not (Test-Path (Join-Path $sourceRoot 'agents/codex'))) {
    throw 'Source tree is incomplete: agents/codex is missing.'
}

# --- 2. Decide the targets -----------------------------------------------------------------------
if ($Project -and -not (Test-Path $Project)) {
    throw "-Project path does not exist: $Project. Point it at an existing repository."
}
$projectRoot = if ($Project) { (Resolve-Path $Project).Path } else { $null }
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }

$doClaude = $false
$doCodex = $false
switch ($Target) {
    'claude' { $doClaude = $true }
    'codex' { $doCodex = $true }
    'both' { $doClaude = $true; $doCodex = $true }
    'auto' {
        $doClaude = $true
        $doCodex = Test-Path $codexHome
    }
}

# Claude Code paths.
$claudeHome = if ($projectRoot) { Join-Path $projectRoot '.claude' } else { Join-Path $HOME '.claude' }
# Codex paths: skills follow the agent-skills standard (~/.agents/skills, <repo>/.agents/skills);
# custom agents live under the Codex home (~/.codex/agents) or the project's .codex/agents.
$codexSkillsRoot = if ($projectRoot) { Join-Path $projectRoot '.agents/skills' } else { Join-Path $HOME '.agents/skills' }
$codexAgentsDir = if ($projectRoot) { Join-Path $projectRoot '.codex/agents' } else { Join-Path $codexHome 'agents' }
$codexBackups = Join-Path $codexHome 'backups'

# --- 3. Helpers ---------------------------------------------------------------------------------
# A destination that is a junction or symlink - an `npx skills` install links <agent>/skills/<name>
# to ~/.agents/skills/<name> - is unlinked, never followed: a recursive delete through it would
# empty the link's target.
function Install-Directory([string]$From, [string]$To, [string]$BackupRoot) {
    $existing = Get-Item -LiteralPath $To -Force -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        $existing.Delete()
        Write-Note "unlinked $To"
    }
    if (Test-Path $To) {
        if ($NoBackup) {
            Write-Note "replacing $To (no backup)"
        }
        else {
            $backup = Join-Path $BackupRoot ("{0}-{1}" -f (Split-Path $To -Leaf), $Stamp)
            New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
            Move-Item -LiteralPath $To -Destination $backup
            Write-Note "backed up existing copy to $backup"
        }
        if (Test-Path $To) { Remove-Item -LiteralPath $To -Recurse -Force }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $To -Parent) | Out-Null
    Copy-Item -LiteralPath $From -Destination $To -Recurse
    Write-Note "installed $To"
}

# The latest release of the Matt Pocock collection: the tag GitHub names as latest, or the highest
# plain vX.Y.Z tag when the API cannot be reached (it rate-limits unauthenticated callers).
function Get-MattPocockReleaseTag {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$MattPocockRepo/releases/latest" `
            -Headers @{ 'User-Agent' = 'grill-to-waves-installer' }
        if ($release.tag_name) { return [string]$release.tag_name }
    }
    catch {
        Write-Note "GitHub API did not name a latest release ($($_.Exception.Message)); reading the tags instead."
    }
    $tags = @(git ls-remote --tags --refs "https://github.com/$MattPocockRepo.git" 'v*' |
            ForEach-Object { ($_ -split 'refs/tags/')[-1] } |
            Where-Object { $_ -match '^v\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Substring(1) })
    if ($tags.Count -eq 0) {
        throw "Could not find a release of $MattPocockRepo. Re-run with -SkipMattPocock to install without it."
    }
    return $tags[-1]
}

# Install the fetched Matt Pocock skills into one skills root. Install-Directory unlinks a
# destination that is a link, which is what an `npx skills` install leaves there.
function Install-MattPocockSkills([string]$SkillsRoot, [string]$BackupRoot) {
    foreach ($source in $mattPocockSkillDirs) {
        Install-Directory $source (Join-Path $SkillsRoot (Split-Path $source -Leaf)) $BackupRoot
    }
    Write-Note "installed $($mattPocockSkillDirs.Count) Matt Pocock skills ($mattPocockTag) into $SkillsRoot"
}

function Install-File([string]$From, [string]$To, [string]$BackupRoot) {
    if ((Test-Path $To) -and -not $NoBackup) {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        Copy-Item -LiteralPath $To -Destination (Join-Path $BackupRoot ("{0}-{1}" -f (Split-Path $To -Leaf), $Stamp))
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $To -Parent) | Out-Null
    Copy-Item -LiteralPath $From -Destination $To -Force
}

function Remove-RetiredAgents([string]$Dir, [string]$Extension, [string]$BackupRoot) {
    foreach ($name in $RetiredAgents) {
        $path = Join-Path $Dir "$name.$Extension"
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if (-not $NoBackup) {
            New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
            Copy-Item -LiteralPath $path -Destination (Join-Path $BackupRoot ("{0}.{1}-{2}" -f $name, $Extension, $Stamp))
        }
        Remove-Item -LiteralPath $path -Force
        Write-Note "removed retired agent $path"
    }
}

# Add one top-level key to settings.json as text right after the opening brace, so the rest of the
# file keeps its formatting. A key that is already there is the user's own choice and is left alone.
function Add-ClaudeSetting([string]$SettingsPath, [string]$BackupRoot, [string]$Key, [string]$Entry, [string]$Subject) {
    $text = if (Test-Path -LiteralPath $SettingsPath) { [System.IO.File]::ReadAllText($SettingsPath, $Utf8NoBom) } else { '' }
    if ([string]::IsNullOrWhiteSpace($text)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $SettingsPath -Parent) | Out-Null
        [System.IO.File]::WriteAllText($SettingsPath, "{`n  $Entry`n}`n", $Utf8NoBom)
        Write-Note "created $SettingsPath with $Subject"
        return
    }

    try { $settings = $text | ConvertFrom-Json }
    catch { $settings = $null }
    if ($settings -isnot [System.Management.Automation.PSCustomObject]) {
        Write-Note "WARNING: $SettingsPath is not a JSON object; add $Entry to it yourself."
        return
    }
    $keys = @($settings.PSObject.Properties | ForEach-Object Name)
    if ($keys -contains $Key) {
        Write-Note "kept the existing $Key setting in $SettingsPath"
        return
    }

    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $insert = if ($keys.Count -eq 0) { "$nl  $Entry$nl" } else { "$nl  $Entry," }
    $brace = $text.IndexOf('{')
    $updated = $text.Substring(0, $brace + 1) + $insert + $text.Substring($brace + 1)
    try { $check = $updated | ConvertFrom-Json }
    catch { $check = $null }
    if (-not $check -or @($check.PSObject.Properties | ForEach-Object Name) -notcontains $Key) {
        Write-Note "WARNING: could not add $Key to $SettingsPath safely; add $Entry to it yourself."
        return
    }

    if (-not $NoBackup) {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        Copy-Item -LiteralPath $SettingsPath -Destination (Join-Path $BackupRoot "settings.json-$Stamp")
    }
    [System.IO.File]::WriteAllText($SettingsPath, $updated, $Utf8NoBom)
    Write-Note "added $Subject to $SettingsPath"
}

# Claude Code writes a Co-Authored-By trailer into every commit and a "Generated with Claude Code"
# line into every pull request body unless `attribution` hides them.
function Hide-ClaudeAttribution([string]$SettingsPath, [string]$BackupRoot) {
    Add-ClaudeSetting $SettingsPath $BackupRoot 'attribution' '"attribution": { "commit": "", "pr": "" }' `
        'the attribution setting (no commit or pull request attribution)'
}

# The statusline renders  model | ctx% | 5h | 7d  from the hook JSON. The script is installed
# alongside the settings that point at it, and an existing `statusLine` is left alone.
function Install-ClaudeStatusLine([string]$Source, [string]$ClaudeUserHome, [string]$BackupRoot) {
    $dest = Join-Path $ClaudeUserHome 'statusline.js'
    Install-File $Source $dest $BackupRoot
    Write-Note "installed $dest"

    $windows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    $script = $dest.Replace('\', '/')
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-Note "WARNING: node was not found on PATH; $dest is installed but settings.json is untouched."
        return
    }
    # Windows: Claude Code runs the command through cmd, which cannot quote the way the script needs,
    # so it goes through PowerShell with node's full path. Elsewhere the command runs as written.
    $command = if ($windows) {
        $node = $nodeCmd.Source.Replace('\', '/')
        "powershell -NoProfile -NonInteractive -Command `"& '$node' '$script'`""
    }
    else {
        "node '$script'"
    }
    $entry = '"statusLine": { "type": "command", "command": ' + ($command | ConvertTo-Json) + ' }'
    Add-ClaudeSetting (Join-Path $ClaudeUserHome 'settings.json') $BackupRoot 'statusLine' $entry 'the statusline'
}

# Rewrite skill text from Claude Code's vocabulary to Codex's.
function ConvertTo-CodexSkillText([string]$Text) {
    # Slash commands -> Codex skill mentions.
    # A path segment (`../grill-to-waves/DEFAULTS.md`, `skills/grill-to-waves`) is left alone.
    $Text = [regex]::Replace($Text, '(?<![\w./\\-])/(orchestrate|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)(?![\w/-])', '$$$1')
    # The agent directory inside the repository.
    $Text = [regex]::Replace($Text, '\.claude([/\\])(worktrees|scratch)', '.codex$1$2')
    # Codex reads only `name` and `description` from the frontmatter; agents/openai.yaml carries the
    # user-invocation-only policy instead.
    return [regex]::Replace($Text, '(?m)^disable-model-invocation: true\r?\n', '')
}

# Rewrite one installed skill file for Codex. Byte-exact UTF-8 in and out (no BOM), so non-ASCII
# prose survives Windows PowerShell 5.1.
function Convert-SkillFileForCodex([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
    [System.IO.File]::WriteAllText($Path, (ConvertTo-CodexSkillText $text), $Utf8NoBom)
}

# The bytes an install would write for one source file: the file as it is, or the rewritten text
# for a Codex skill's own Markdown.
function Get-InstallBytes([string]$Path, [bool]$ForCodex) {
    if ($ForCodex) {
        return , $Utf8NoBom.GetBytes((ConvertTo-CodexSkillText ([System.IO.File]::ReadAllText($Path, $Utf8NoBom))))
    }
    return , [System.IO.File]::ReadAllBytes($Path)
}

function Test-InstalledFile([string]$From, [string]$To, [bool]$ForCodex) {
    $expected = [System.Convert]::ToBase64String((Get-InstallBytes $From $ForCodex))
    return $expected -ceq [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($To))
}

function Get-RelativeFiles([string]$Root) {
    $prefix = (Get-Item -LiteralPath $Root -Force).FullName.TrimEnd('\', '/').Length + 1
    return @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
            ForEach-Object { $_.FullName.Substring($prefix).Replace('\', '/') })
}

# `identical`, `not installed`, or `differs` with the files that are changed, missing or extra.
# Codex rewrites the Markdown at the top of a skill folder and nothing below it.
function Get-DirectoryStatus([string]$From, [string]$To, [bool]$ForCodex) {
    if (-not (Test-Path -LiteralPath $To -PathType Container)) { return 'not installed' }
    $expected = Get-RelativeFiles $From
    $installed = Get-RelativeFiles $To
    $changed = New-Object System.Collections.Generic.List[string]
    foreach ($file in $expected) {
        $rewritten = $ForCodex -and $file -notmatch '/' -and $file -like '*.md'
        if ($installed -cnotcontains $file) { $changed.Add($file) }
        elseif (-not (Test-InstalledFile (Join-Path $From $file) (Join-Path $To $file) $rewritten)) { $changed.Add($file) }
    }
    foreach ($file in $installed) {
        if ($expected -cnotcontains $file) { $changed.Add($file) }
    }
    if ($changed.Count -eq 0) { return 'identical' }
    $names = [string[]]$changed.ToArray()
    [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
    return "differs ($($names -join ', '))"
}

function Get-FileStatus([string]$From, [string]$To) {
    if (-not (Test-Path -LiteralPath $To -PathType Leaf)) { return 'not installed' }
    if (Test-InstalledFile $From $To $false) { return 'identical' }
    return 'differs'
}

# One status line: the state in a fixed column, then the item, then the files behind a `differs`.
function Write-Status([string]$State, [string]$Item) {
    $name = $State
    $detail = ''
    if ($State.StartsWith('differs ')) {
        $name = 'differs'
        $detail = '  ' + $State.Substring(8)
    }
    $script:statusCounts[$name]++
    Write-Note ('{0,-13}  {1}{2}' -f $name, $Item, $detail)
}

function Get-SortedFiles([string]$Dir, [string]$Filter) {
    $files = @(Get-ChildItem $Dir -Filter $Filter -File)
    $names = [string[]]@($files | ForEach-Object Name)
    [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
    return $names
}

# --- 4. Status ----------------------------------------------------------------------------------
# Compare, report and stop. Nothing below this section runs, so nothing is fetched or written.
if ($Status) {
    $statusCounts = @{ 'identical' = 0; 'differs' = 0; 'not installed' = 0 }
    if ($doClaude) {
        Write-Step "Status: Claude Code -> $claudeHome"
        foreach ($skill in $Skills) {
            Write-Status (Get-DirectoryStatus (Join-Path $sourceRoot "skills/$skill") (Join-Path $claudeHome "skills/$skill") $false) "skills/$skill"
        }
        foreach ($agent in (Get-SortedFiles (Join-Path $sourceRoot 'agents') '*.md')) {
            Write-Status (Get-FileStatus (Join-Path $sourceRoot "agents/$agent") (Join-Path $claudeHome "agents/$agent")) "agents/$agent"
        }
    }
    if ($doCodex) {
        Write-Step "Status: Codex CLI -> skills in $codexSkillsRoot, agents in $codexAgentsDir"
        foreach ($skill in $Skills) {
            Write-Status (Get-DirectoryStatus (Join-Path $sourceRoot "skills/$skill") (Join-Path $codexSkillsRoot $skill) $true) "skills/$skill"
        }
        foreach ($agent in (Get-SortedFiles (Join-Path $sourceRoot 'agents/codex') '*.toml')) {
            Write-Status (Get-FileStatus (Join-Path $sourceRoot "agents/codex/$agent") (Join-Path $codexAgentsDir $agent)) "agents/$agent"
        }
    }
    Write-Step "Status: $($statusCounts['identical']) identical, $($statusCounts['differs']) differs, $($statusCounts['not installed']) not installed."
    Write-Note 'Nothing was changed. A copy that differs stays as it is until the installer runs without -Status.'
    return
}

# --- 5. Fetch the Matt Pocock collection ---------------------------------------------------------
# Straight from its GitHub repository, at the latest release, before anything is installed - so a
# network failure stops the run with nothing half-replaced.
$mattPocockTag = $null
$mattPocockSkillDirs = @()
if (-not $SkipMattPocock) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required to fetch $MattPocockRepo. Re-run with -SkipMattPocock to install without it."
    }
    $mattPocockTag = Get-MattPocockReleaseTag
    $mattPocockRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mattpocock-skills-$Stamp"
    Write-Step "Matt Pocock skills: fetching $MattPocockRepo at its latest release, $mattPocockTag"
    # Fetch the tag rather than `clone --branch`: a shallow clone of an annotated tag works, but
    # warns that the tag "is not a commit!".
    git init --quiet $mattPocockRoot
    git -C $mattPocockRoot fetch --quiet --depth 1 "https://github.com/$MattPocockRepo.git" "refs/tags/$mattPocockTag"
    if ($LASTEXITCODE -eq 0) { git -C $mattPocockRoot -c advice.detachedHead=false checkout --quiet FETCH_HEAD }
    if ($LASTEXITCODE -ne 0) {
        throw "Fetching $MattPocockRepo $mattPocockTag failed with exit code $LASTEXITCODE. Re-run with -SkipMattPocock to install without it."
    }
    # The release's own manifest names the skills it ships; its in-progress and misc buckets are
    # not in it.
    $manifestPath = Join-Path $mattPocockRoot '.claude-plugin/plugin.json'
    if (-not (Test-Path $manifestPath)) {
        throw "$MattPocockRepo $mattPocockTag has no .claude-plugin/plugin.json to read the skill list from."
    }
    $manifest = [System.IO.File]::ReadAllText($manifestPath, $Utf8NoBom) | ConvertFrom-Json
    foreach ($relative in @($manifest.skills)) {
        $dir = [System.IO.Path]::GetFullPath((Join-Path $mattPocockRoot $relative))
        $name = Split-Path $dir -Leaf
        if ($MattPocockExclude -contains $name) {
            Write-Note "left out $name"
            continue
        }
        if (-not (Test-Path (Join-Path $dir 'SKILL.md'))) {
            throw "$MattPocockRepo $mattPocockTag lists $relative but ships no SKILL.md there."
        }
        $mattPocockSkillDirs += $dir
    }
    if ($mattPocockSkillDirs.Count -eq 0) { throw "$MattPocockRepo $mattPocockTag lists no skills to install." }
}

# --- 6. Claude Code ------------------------------------------------------------------------------
if ($doClaude) {
    Write-Step "Claude Code -> $claudeHome"
    $backups = Join-Path $claudeHome 'backups'
    foreach ($skill in $Skills) {
        Install-Directory (Join-Path $sourceRoot "skills/$skill") (Join-Path $claudeHome "skills/$skill") $backups
    }
    if (-not $SkipMattPocock) { Install-MattPocockSkills (Join-Path $claudeHome 'skills') $backups }
    $agentsDir = Join-Path $claudeHome 'agents'
    $agents = Get-ChildItem (Join-Path $sourceRoot 'agents') -Filter '*.md' -File
    foreach ($agent in $agents) {
        Install-File $agent.FullName (Join-Path $agentsDir $agent.Name) $backups
    }
    Write-Note "installed $($agents.Count) agent definitions into $agentsDir"
    Remove-RetiredAgents $agentsDir 'md' $backups
    # User scope even with -Project: attribution is a per-person preference, not a repository's.
    $userClaudeHome = Join-Path $HOME '.claude'
    Hide-ClaudeAttribution (Join-Path $userClaudeHome 'settings.json') (Join-Path $userClaudeHome 'backups')
    # The statusline is a per-person preference too, and its script is read from the user's home.
    Install-ClaudeStatusLine (Join-Path $sourceRoot 'statusline/statusline.js') $userClaudeHome (Join-Path $userClaudeHome 'backups')
}

# --- 7. Codex CLI --------------------------------------------------------------------------------
if ($doCodex) {
    Write-Step "Codex CLI -> skills in $codexSkillsRoot, agents in $codexAgentsDir"
    foreach ($skill in $Skills) {
        $dest = Join-Path $codexSkillsRoot $skill
        Install-Directory (Join-Path $sourceRoot "skills/$skill") $dest $codexBackups
        foreach ($file in (Get-ChildItem $dest -Filter '*.md' -File)) {
            Convert-SkillFileForCodex $file.FullName
        }
        Write-Note "rewrote $skill for Codex (`$-mentions and .codex/ paths)"
    }
    if (-not $SkipMattPocock) { Install-MattPocockSkills $codexSkillsRoot $codexBackups }

    $agents = Get-ChildItem (Join-Path $sourceRoot 'agents/codex') -Filter '*.toml' -File
    foreach ($agent in $agents) {
        Install-File $agent.FullName (Join-Path $codexAgentsDir $agent.Name) $codexBackups
    }
    Write-Note "installed $($agents.Count) custom agent definitions into $codexAgentsDir"
    Remove-RetiredAgents $codexAgentsDir 'toml' $codexBackups

    # A copy under the legacy root would register a second skill with the same name.
    foreach ($skill in $Skills) {
        $legacy = Join-Path $codexHome "skills/$skill"
        if (Test-Path $legacy) {
            Write-Note "WARNING: $legacy also exists. ~/.codex/skills is Codex's legacy root; remove that copy or both will be listed."
        }
    }

    # Multi-agent tools are on by default; say so if the user's config turns them off.
    $configPath = Join-Path $codexHome 'config.toml'
    if (Test-Path $configPath) {
        $config = [System.IO.File]::ReadAllText($configPath, $Utf8NoBom)
        if ($config -match '(?m)^\s*enabled\s*=\s*false' -and $config -match '(?m)^\s*\[agents\]') {
            Write-Note "WARNING: [agents] enabled = false in $configPath. /orchestrate needs spawn_agent; set it to true."
        }
        $ceiling = [regex]::Match($config, '(?m)^\s*max_concurrent_threads_per_session\s*=\s*(\d+)')
        if ($ceiling.Success) {
            Write-Note "agents.max_concurrent_threads_per_session = $($ceiling.Groups[1].Value); the map's in-flight ceiling must not exceed it."
        }
    }
}

# --- 8. Report ----------------------------------------------------------------------------------
Write-Step 'Done.'
if ($doClaude) {
    Write-Note 'Claude Code: restart the session, then run  /grill-to-waves , later  /orchestrate , and  /ship-it-to stg|prd  to promote'
    Write-Note 'Claude Code: end the day with  /daily-recap  for the team recap'
    Write-Note 'Claude Code: once a fix has moved, draft its ticket comment with  /jira-comment'
}
if ($doCodex) {
    Write-Note 'Codex CLI: restart Codex, then run  $grill-to-waves , later  $orchestrate , and  $ship-it-to stg|prd  to promote'
    Write-Note 'Codex CLI: end the day with  $daily-recap  for the team recap'
    Write-Note 'Codex CLI: once a fix has moved, draft its ticket comment with  $jira-comment'
    Write-Note 'Codex dispatches executors with spawn_agent; the custom agents pin model and reasoning effort per tier.'
}

# The pipeline requires setup-matt-pocock-skills (Stage 0), grilling and domain-modeling (Stage 1).
if ($doClaude) {
    $currentProjectSkillsRoot = Join-Path (Get-Location).Path '.claude/skills'
    $missing = @($RequiredMattPocockSkills | Where-Object {
        -not (Test-Path (Join-Path $claudeHome "skills/$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $HOME ".claude/skills/$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $currentProjectSkillsRoot "$_/SKILL.md"))
    })
    if ($missing.Count -eq 0) {
        Write-Note "Claude Code required skills found: $($RequiredMattPocockSkills -join ', ')."
    }
    else {
        Write-Host ''
        Write-Step "Claude Code required skills missing: $($missing -join ', ')"
        Write-Note 'Stage 0 suggests /setup-matt-pocock-skills; Stage 1 needs /grilling and /domain-modeling.'
        Write-Note "Re-run without -SkipMattPocock, and without excluding them, to fetch them from the latest release of $MattPocockRepo."
    }
    # The plugin registers every skill a second time, under a prefix the pipeline does not call.
    $installedPlugins = Join-Path $HOME '.claude/plugins/installed_plugins.json'
    if ((Test-Path $installedPlugins) -and
        [System.IO.File]::ReadAllText($installedPlugins, $Utf8NoBom).Contains('"mattpocock-skills@')) {
        Write-Note 'WARNING: the mattpocock-skills plugin is installed too, so each skill is listed twice. Remove it:  claude plugin uninstall mattpocock-skills@mattpocock'
    }
}
if ($doCodex) {
    $currentProjectSkillsRoot = Join-Path (Get-Location).Path '.agents/skills'
    $missing = @($RequiredMattPocockSkills | Where-Object {
        -not (Test-Path (Join-Path $codexSkillsRoot "$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $HOME ".agents/skills/$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $currentProjectSkillsRoot "$_/SKILL.md"))
    })
    if ($missing.Count -eq 0) {
        Write-Note "Codex required skills found: $($RequiredMattPocockSkills -join ', ')."
    }
    else {
        Write-Host ''
        Write-Step "Codex required skills missing: $($missing -join ', ')"
        Write-Note 'Stage 0 needs $setup-matt-pocock-skills; Stage 1 needs $grilling and $domain-modeling.'
        Write-Note "Re-run without -SkipMattPocock, and without excluding them, to fetch them from the latest release of $MattPocockRepo."
    }
}
