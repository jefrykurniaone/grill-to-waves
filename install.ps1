<#
.SYNOPSIS
Install the grill-to-waves + orchestrate skills and their executor/scout agents for Claude Code
and/or Codex CLI.

.DESCRIPTION
Copies:
  skills/grill-to-waves  ->  <target>/skills/grill-to-waves
  skills/orchestrate     ->  <target>/skills/orchestrate
  agents/*.md            ->  <target>/agents            (Claude Code only)
                         ->  <target>/skills/grill-to-waves/agents  (Codex, as role briefs)

Targets:
  claude  ~/.claude            or <project>/.claude with -Project
  codex   ~/.codex             (user scope only; Codex has no project skill scope)

Any directory it is about to replace is first moved to <target>/backups/<name>-<timestamp>,
unless -NoBackup is given.

.EXAMPLE
./install.ps1
.EXAMPLE
./install.ps1 -Target claude -Project D:\WORK\PROJECT\my-repo
.EXAMPLE
irm https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex', 'both', 'auto')]
    [string]$Target = 'auto',

    # Install the skills into <path>/.claude instead of the user's home. Claude Code only.
    [string]$Project,

    # Skip the backup of a directory being replaced.
    [switch]$NoBackup,

    # Branch, tag or commit to fetch when the script is run without a local checkout.
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'https://github.com/jefrykurniaone/grill-to-waves.git'
$Skills = @('grill-to-waves', 'orchestrate')
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step([string]$Message) { Write-Host "==> $Message" }
function Write-Note([string]$Message) { Write-Host "    $Message" }

# --- 1. Locate the source tree -------------------------------------------------------------------
# Run from a clone: use the script's own directory. Run through `irm | iex`: clone to a temp dir.
$sourceRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills/grill-to-waves/SKILL.md'))) {
    $sourceRoot = $PSScriptRoot
    Write-Step "Source: local checkout at $sourceRoot"
}
else {
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

# --- 2. Decide the targets -----------------------------------------------------------------------
if ($Project -and -not (Test-Path $Project)) {
    throw "-Project path does not exist: $Project. Point it at an existing repository."
}
$claudeHome = if ($Project) { Join-Path (Resolve-Path $Project) '.claude' } else { Join-Path $HOME '.claude' }
$codexHome = Join-Path $HOME '.codex'

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
if ($Project -and $doCodex -and $Target -ne 'codex') {
    Write-Note 'Codex has no project skill scope; skipping Codex because -Project was given.'
    $doCodex = $false
}
if ($Project -and $Target -eq 'codex') {
    throw '-Project applies to Claude Code only. Drop -Project, or use -Target claude.'
}

# --- 3. Copy ------------------------------------------------------------------------------------
function Install-Directory([string]$From, [string]$To, [string]$BackupRoot) {
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

if ($doClaude) {
    Write-Step "Claude Code -> $claudeHome"
    $backups = Join-Path $claudeHome 'backups'
    foreach ($skill in $Skills) {
        Install-Directory (Join-Path $sourceRoot "skills/$skill") (Join-Path $claudeHome "skills/$skill") $backups
    }
    $agentsDir = Join-Path $claudeHome 'agents'
    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    $agents = Get-ChildItem (Join-Path $sourceRoot 'agents') -Filter '*.md'
    foreach ($agent in $agents) {
        $dest = Join-Path $agentsDir $agent.Name
        if ((Test-Path $dest) -and -not $NoBackup) {
            New-Item -ItemType Directory -Force -Path $backups | Out-Null
            Copy-Item -LiteralPath $dest -Destination (Join-Path $backups ("{0}-{1}" -f $agent.Name, $Stamp))
        }
        Copy-Item -LiteralPath $agent.FullName -Destination $dest -Force
    }
    Write-Note "installed $($agents.Count) agent definitions into $agentsDir"
}

if ($doCodex) {
    Write-Step "Codex CLI -> $codexHome"
    $backups = Join-Path $codexHome 'backups'
    foreach ($skill in $Skills) {
        Install-Directory (Join-Path $sourceRoot "skills/$skill") (Join-Path $codexHome "skills/$skill") $backups
    }
    # Codex has no subagent dispatch, so the definitions install beside the skill as role briefs.
    $agentsDir = Join-Path $codexHome 'skills/grill-to-waves/agents'
    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    Copy-Item (Join-Path $sourceRoot 'agents/*.md') -Destination $agentsDir -Force
    Write-Note "installed agent role briefs into $agentsDir"
}

# --- 4. Report ----------------------------------------------------------------------------------
Write-Step 'Done.'
if ($doClaude) {
    Write-Note 'Claude Code: restart the session, then run  /grill-to-waves  and later  /orchestrate'
}
if ($doCodex) {
    Write-Note 'Codex CLI: restart the session; the skills trigger by name (grill-to-waves, orchestrate).'
    Write-Note 'Codex has no subagent dispatch: the session executes tickets itself, one at a time.'
}

# The pipeline calls grilling and domain-modeling (Stage 1) and setup-matt-pocock-skills (Stage 0).
$mattpocockInstalled = @(
    Get-ChildItem (Join-Path $HOME '.claude/plugins/cache') -Directory -Filter 'mattpocock*' -ErrorAction SilentlyContinue
).Count -gt 0
if ($mattpocockInstalled) {
    Write-Note 'Required plugin mattpocock-skills: found.'
}
else {
    Write-Host ''
    Write-Step 'Required plugin missing: mattpocock-skills'
    Write-Note 'Stage 1 needs grilling and domain-modeling; Stage 0 needs setup-matt-pocock-skills.'
    Write-Note 'In Claude Code, run:'
    Write-Note '  /plugin marketplace add mattpocock/skills'
    Write-Note '  /plugin install mattpocock-skills@mattpocock'
    Write-Note 'The marketplace is named mattpocock, not skills. Restart the session afterwards.'
}
