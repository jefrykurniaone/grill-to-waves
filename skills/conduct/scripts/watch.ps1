<#
.SYNOPSIS
Wait until one of several herdr agents settles after a known state change, then print its state.

.DESCRIPTION
Read-only. One process watches every session given as <name>:<after-seq>. Each poll reads
`herdr agent get <name>` for each of them. A session has settled when its state_change_seq is above
its <after-seq> and its status is idle, done, blocked or unknown. The watcher then prints
`settled <name>` and herdr's JSON for that session, and exits 0.

A pause is not a settle. When an idle or done session's last outcome line on screen is
`orchestrate: waiting on executors`, the watcher takes that sequence number as the session's new
baseline and keeps waiting, so the caller is not woken to do nothing.

A change that happened before the watcher started is caught on the first poll, so no settle is lost
between the caller's read and the watcher. Exits 1 with `gone <name>` and herdr's error when an agent
is gone, 2 on a malformed argument, and 3 with `timeout` when -TimeoutSeconds runs out (0 waits
indefinitely).

Runs under Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
powershell -NoProfile -File scripts/watch.ps1 -Sessions billing-service:41,portal:17
#>
param(
    [Parameter(Mandatory = $true)][string]$Sessions,
    [int]$IntervalSeconds = 60,
    [int]$TimeoutSeconds = 3600,
    [int]$Lines = 25
)

$settled = @('idle', 'done', 'blocked', 'unknown')
$outcome = 'orchestrate: (done|stopped|waiting on executors)'
$pause = 'orchestrate: waiting on executors'

# -File passes a,b as one string; a direct call passes it as an array, joined with spaces.
$names = @()
$after = @{}
foreach ($pair in ($Sessions -split '[,\s]+' | Where-Object { $_ })) {
    $cut = $pair.LastIndexOf(':')
    $seq = 0L
    if ($cut -lt 1 -or -not [long]::TryParse($pair.Substring($cut + 1), [ref]$seq)) {
        Write-Output "watch.ps1: '$pair' is not <name>:<after-seq>"
        exit 2
    }
    $name = $pair.Substring(0, $cut)
    $names += $name
    $after[$name] = $seq
}
if ($names.Count -eq 0) {
    Write-Output 'watch.ps1: no session given'
    exit 2
}

# True when the last outcome line on the session's screen is the pause line.
function Test-Paused([string]$Name) {
    $screen = & herdr agent read $Name --source recent-unwrapped --lines $Lines 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { return $false }
    $last = $null
    foreach ($line in $screen) {
        if ($line -match $outcome) { $last = $Matches[0] }
    }
    return ($last -eq $pause)
}

$deadline = if ($TimeoutSeconds -gt 0) { (Get-Date).AddSeconds($TimeoutSeconds) } else { $null }

while ($true) {
    foreach ($name in $names) {
        $text = (& herdr agent get $name 2>&1 | ForEach-Object { "$_" }) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            Write-Output "gone $name"
            Write-Output $text
            exit 1
        }
        $state = ($text | ConvertFrom-Json).result.agent
        if ($state.state_change_seq -le $after[$name] -or $settled -notcontains $state.agent_status) { continue }
        if (@('idle', 'done') -contains $state.agent_status -and (Test-Paused $name)) {
            $after[$name] = [long]$state.state_change_seq
            continue
        }
        Write-Output "settled $name"
        Write-Output $text
        exit 0
    }
    if ($deadline -and (Get-Date) -ge $deadline) {
        Write-Output 'timeout'
        exit 3
    }
    Start-Sleep -Seconds $IntervalSeconds
}
