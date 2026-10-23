<#
.SYNOPSIS
Wait until a herdr agent settles after a known state change, then print its state.

.DESCRIPTION
Read-only. Polls `herdr agent get <Agent>` until its state_change_seq is above -AfterSeq and its
status is idle, done, blocked or unknown, then prints herdr's JSON and exits 0. A change that
happened before the watcher started is caught on the first poll, so no settle is lost between the
caller's read and the watcher. Exits 1 with herdr's error when the agent is gone, and 3 when
-TimeoutSeconds (0, the default, waits indefinitely) runs out.

Runs under Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
powershell -NoProfile -File scripts/watch.ps1 -Agent billing-service -AfterSeq 41
#>
param(
    [Parameter(Mandatory = $true)][string]$Agent,
    [Parameter(Mandatory = $true)][long]$AfterSeq,
    [int]$IntervalSeconds = 20,
    [int]$TimeoutSeconds = 0
)

$settled = @('idle', 'done', 'blocked', 'unknown')
$deadline = if ($TimeoutSeconds -gt 0) { (Get-Date).AddSeconds($TimeoutSeconds) } else { $null }

while ($true) {
    $text = (& herdr agent get $Agent 2>&1 | ForEach-Object { "$_" }) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        Write-Output $text
        exit 1
    }
    $state = ($text | ConvertFrom-Json).result.agent
    if ($state.state_change_seq -gt $AfterSeq -and $settled -contains $state.agent_status) {
        Write-Output $text
        exit 0
    }
    if ($deadline -and (Get-Date) -ge $deadline) {
        Write-Output $text
        exit 3
    }
    Start-Sleep -Seconds $IntervalSeconds
}
