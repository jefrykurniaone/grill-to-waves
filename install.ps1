<#
.SYNOPSIS
Install the grill-to-waves + orchestrate skills and their executor/scout agents for Claude Code
and/or Codex CLI.

.DESCRIPTION
Claude Code:
  skills/grill-to-waves  ->  ~/.claude/skills/grill-to-waves      (or <project>/.claude/skills/...)
  skills/orchestrate     ->  ~/.claude/skills/orchestrate
  agents/*.md            ->  ~/.claude/agents/

Codex CLI:
  skills/grill-to-waves  ->  ~/.agents/skills/grill-to-waves      (or <project>/.agents/skills/...)
  skills/orchestrate     ->  ~/.agents/skills/orchestrate
  agents/codex/*.toml    ->  ~/.codex/agents/                     (or <project>/.codex/agents/)

The skill text is written in Claude Code's vocabulary. For Codex the installer rewrites, and only
rewrites: the skill invocation prefix (`/orchestrate` -> `$orchestrate`), the agent directory
(`.claude/worktrees`, `.claude/scratch` -> `.codex/...`), the grill-skill names
(`mattpocock-skills:grilling` -> `$grilling`, likewise domain-modeling) and drops the
`disable-model-invocation` frontmatter line, whose Codex equivalent is the skill's
`agents/openai.yaml` (`allow_implicit_invocation: false`), shipped in the repo.

Any directory it is about to replace is first moved to <backups>/<name>-<timestamp>, unless
-NoBackup is given. Backups: ~/.claude/backups for Claude Code, ~/.codex/backups for Codex.

.EXAMPLE
./install.ps1
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
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'https://github.com/jefrykurniaone/grill-to-waves.git'
$Skills = @('grill-to-waves', 'orchestrate')
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

function Install-File([string]$From, [string]$To, [string]$BackupRoot) {
    if ((Test-Path $To) -and -not $NoBackup) {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        Copy-Item -LiteralPath $To -Destination (Join-Path $BackupRoot ("{0}-{1}" -f (Split-Path $To -Leaf), $Stamp))
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $To -Parent) | Out-Null
    Copy-Item -LiteralPath $From -Destination $To -Force
}

# Rewrite one installed skill file from Claude Code's vocabulary to Codex's. Byte-exact UTF-8 in
# and out (no BOM), so non-ASCII prose survives Windows PowerShell 5.1.
function Convert-SkillFileForCodex([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
    # `/orchestrate` and `/grill-to-waves` as commands -> `$orchestrate`, `$grill-to-waves`.
    # A path segment (`../grill-to-waves/DEFAULTS.md`, `skills/grill-to-waves`) is left alone.
    $text = [regex]::Replace($text, '(?<![\w./\\-])/(orchestrate|grill-to-waves)(?![\w/-])', '$$$1')
    # The agent directory inside the repository.
    $text = [regex]::Replace($text, '\.claude([/\\])(worktrees|scratch)', '.codex$1$2')
    # The two required grill skills, plugin-namespaced on Claude Code, plain skills on Codex.
    $text = $text.Replace('mattpocock-skills:grilling', '$grilling')
    $text = $text.Replace('mattpocock-skills:domain-modeling', '$domain-modeling')
    # Codex reads only `name` and `description` from the frontmatter; agents/openai.yaml carries the
    # user-invocation-only policy instead.
    $text = [regex]::Replace($text, '(?m)^disable-model-invocation: true\r?\n', '')
    [System.IO.File]::WriteAllText($Path, $text, $Utf8NoBom)
}

# --- 4. Claude Code ------------------------------------------------------------------------------
if ($doClaude) {
    Write-Step "Claude Code -> $claudeHome"
    $backups = Join-Path $claudeHome 'backups'
    foreach ($skill in $Skills) {
        Install-Directory (Join-Path $sourceRoot "skills/$skill") (Join-Path $claudeHome "skills/$skill") $backups
    }
    $agentsDir = Join-Path $claudeHome 'agents'
    $agents = Get-ChildItem (Join-Path $sourceRoot 'agents') -Filter '*.md' -File
    foreach ($agent in $agents) {
        Install-File $agent.FullName (Join-Path $agentsDir $agent.Name) $backups
    }
    Write-Note "installed $($agents.Count) agent definitions into $agentsDir"
}

# --- 5. Codex CLI --------------------------------------------------------------------------------
if ($doCodex) {
    Write-Step "Codex CLI -> skills in $codexSkillsRoot, agents in $codexAgentsDir"
    foreach ($skill in $Skills) {
        $dest = Join-Path $codexSkillsRoot $skill
        Install-Directory (Join-Path $sourceRoot "skills/$skill") $dest $codexBackups
        foreach ($file in (Get-ChildItem $dest -Filter '*.md' -File)) {
            Convert-SkillFileForCodex $file.FullName
        }
        Write-Note "rewrote $skill for Codex (`$-mentions, .codex/ paths, `$grilling / `$domain-modeling)"
    }

    $agents = Get-ChildItem (Join-Path $sourceRoot 'agents/codex') -Filter '*.toml' -File
    foreach ($agent in $agents) {
        Install-File $agent.FullName (Join-Path $codexAgentsDir $agent.Name) $codexBackups
    }
    Write-Note "installed $($agents.Count) custom agent definitions into $codexAgentsDir"

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

# --- 6. Report ----------------------------------------------------------------------------------
Write-Step 'Done.'
if ($doClaude) {
    Write-Note 'Claude Code: restart the session, then run  /grill-to-waves  and later  /orchestrate'
}
if ($doCodex) {
    Write-Note 'Codex CLI: restart Codex, then run  $grill-to-waves  and later  $orchestrate'
    Write-Note 'Codex dispatches executors with spawn_agent; the custom agents pin model and reasoning effort per tier.'
}

# The pipeline calls grilling and domain-modeling (Stage 1) and, on Claude Code, setup-matt-pocock-skills (Stage 0).
if ($doClaude) {
    $mattpocockInstalled = @(
        Get-ChildItem (Join-Path $HOME '.claude/plugins/cache') -Directory -Filter 'mattpocock*' -ErrorAction SilentlyContinue
    ).Count -gt 0
    if ($mattpocockInstalled) {
        Write-Note 'Claude Code required plugin mattpocock-skills: found.'
    }
    else {
        Write-Host ''
        Write-Step 'Claude Code required plugin missing: mattpocock-skills'
        Write-Note 'Stage 1 needs grilling and domain-modeling; Stage 0 suggests setup-matt-pocock-skills.'
        Write-Note 'In Claude Code, run:'
        Write-Note '  /plugin marketplace add mattpocock/skills'
        Write-Note '  /plugin install mattpocock-skills@mattpocock'
        Write-Note 'The marketplace is named mattpocock, not skills. Restart the session afterwards.'
    }
}
if ($doCodex) {
    $currentProjectSkillsRoot = Join-Path (Get-Location).Path '.agents/skills'
    $missing = @(@('grilling', 'domain-modeling') | Where-Object {
        -not (Test-Path (Join-Path $codexSkillsRoot "$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $HOME ".agents/skills/$_/SKILL.md")) -and
        -not (Test-Path (Join-Path $currentProjectSkillsRoot "$_/SKILL.md"))
    })
    if ($missing.Count -eq 0) {
        Write-Note 'Codex required skills grilling and domain-modeling: found.'
    }
    else {
        Write-Host ''
        Write-Step "Codex required skills missing: $($missing -join ', ')"
        Write-Note 'Stage 1 needs $grilling and $domain-modeling. From the project where you will run the pipeline, use:'
        Write-Note '  npx skills@latest add mattpocock/skills --skill grilling --skill domain-modeling -a codex'
        Write-Note 'Choose project scope if prompted, then restart Codex.'
    }
}
