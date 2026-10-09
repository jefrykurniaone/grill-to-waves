<#
.SYNOPSIS
Fail when a tracked Markdown or agent file names a Claude model with a version number.

.DESCRIPTION
  pwsh -NoProfile -File tests/check-docs.ps1
  powershell -NoProfile -File tests/check-docs.ps1

Claude Code tiers are named by alias only - fable, opus, sonnet - so each tier follows the current
generation without an edit. A tier name followed by a number, or a `claude-` model id, pins a
generation and goes stale. Codex model ids (the `gpt-` names in the Hosts table and the Codex
agents) are a different thing and are allowed: Codex has no aliases to follow.

Checked: every tracked *.md file, and every tracked file under agents/. Each hit is printed as
path:line: text, and the script exits 1 when there is one.

This file stays ASCII: Windows PowerShell 5.1 reads a script without a BOM in the ANSI codepage.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path $PSScriptRoot -Parent
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
$patterns = @(
    # A tier name with a version: a tier and a number, with a space, a hyphen or nothing between.
    (New-Object regex '\b(fable|opus|sonnet|haiku)[ -]?v?\d+([.-]\d+)*\b', $options),
    # A model id or name that leads with the version: claude-<number>..., Claude <number>.
    (New-Object regex '\bclaude[ -]v?\d+([.-]\d+)*', $options)
)

$tracked = @(git -C $repoRoot ls-files -- '*.md' 'agents')
if ($LASTEXITCODE -ne 0) { throw "git ls-files failed with exit code $LASTEXITCODE." }

$hits = 0
$checked = 0
foreach ($relative in $tracked) {
    $path = Join-Path $repoRoot $relative
    # Tracked but deleted in the working tree: nothing to read.
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $checked++
    $number = 0
    foreach ($line in ([System.IO.File]::ReadAllText($path, $utf8NoBom) -split "`r?`n")) {
        $number++
        foreach ($pattern in $patterns) {
            if ($pattern.IsMatch($line)) {
                $hits++
                Write-Host ("{0}:{1}: {2}" -f $relative, $number, $line.Trim())
                break
            }
        }
    }
}

if ($hits -gt 0) {
    Write-Host "docs check: $hits line(s) in $checked files name a Claude model with a version. Name the tier by its alias instead."
    exit 1
}
Write-Host "docs check: $checked files, no Claude model named with a version."
exit 0
