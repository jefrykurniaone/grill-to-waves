<#
.SYNOPSIS
Run install.ps1 with the home directory pointed at a scratch directory, or not at all.

.DESCRIPTION
The tests never run the installer against the real home. This script is the only place they call
install.ps1 from, and it refuses unless the PowerShell session's $HOME is the scratch directory it
was handed, that directory carries the marker file the tests put there, and CODEX_HOME sits inside
it. The caller redirects $HOME by setting USERPROFILE (Windows) or HOME before starting the process.

Every parameter except -ScratchHome and -Installer is passed to the installer as given.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ScratchHome,

    # The install.ps1 to run: the tests hand over their own snapshot of the checkout.
    [Parameter(Mandatory = $true)]
    [string]$Installer,

    [string]$Target,
    [string]$Project,
    [switch]$NoBackup,
    [switch]$SkipMattPocock,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expected = [System.IO.Path]::GetFullPath($ScratchHome).TrimEnd('\', '/')
$actual = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
if ($actual -ne $expected) {
    throw "Refusing to run the installer: `$HOME is $actual, not the scratch directory $expected."
}
if (-not (Test-Path -LiteralPath (Join-Path $expected '.g2w-scratch') -PathType Leaf)) {
    throw "Refusing to run the installer: $expected has no .g2w-scratch marker, so it is not a test scratch directory."
}
$codexHome = if ($env:CODEX_HOME) { [System.IO.Path]::GetFullPath($env:CODEX_HOME) } else { '' }
if (-not $codexHome.StartsWith($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to run the installer: CODEX_HOME ($codexHome) is not inside $expected."
}

$forwarded = @{}
foreach ($entry in $PSBoundParameters.GetEnumerator()) {
    if (@('ScratchHome', 'Installer') -notcontains $entry.Key) { $forwarded[$entry.Key] = $entry.Value }
}

& $Installer @forwarded
