<#
Collects the raw evidence for a daily work recap: the day's commits, and what each of that day's
coding-agent sessions was asked to do and reported back.

Read-only. It writes nothing and changes no repository state.

  .\collect-evidence.ps1                                   # today, repositories under the current directory
  .\collect-evidence.ps1 -Date yesterday
  .\collect-evidence.ps1 -Date 2026-09-22 -Root 'D:\WORK\PROJECT','C:\src'
#>
[CmdletBinding()]
param(
    [string]$Date = 'today',
    [string[]]$Root = @((Get-Location).Path),
    [int]$PromptChars = 400,
    [int]$SummaryChars = 1500
)

$ErrorActionPreference = 'Continue'

$day = switch ($Date) {
    'today'     { (Get-Date).Date }
    'yesterday' { (Get-Date).Date.AddDays(-1) }
    default     { ([datetime]::Parse($Date)).Date }
}
$next = $day.AddDays(1)
$since = $day.ToString('yyyy-MM-dd 00:00')
$until = $next.ToString('yyyy-MM-dd 00:00')

"# Evidence for $($day.ToString('yyyy-MM-dd'))"
""

# --- Commits ----------------------------------------------------------------
"## Commits"
""
$repos = foreach ($r in $Root) {
    if (-not (Test-Path $r)) { continue }
    if (Test-Path (Join-Path $r '.git')) { Get-Item $r }
    Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName '.git') }
}

$found = $false
foreach ($repo in $repos) {
    $p = $repo.FullName
    $log = git -C $p log --all --since="$since" --until="$until" --format="%h|%ad|%an|%s" --date=format:'%H:%M' 2>$null
    if (-not $log) { continue }
    $found = $true
    $branch = git -C $p branch --show-current 2>$null
    $me = git -C $p config user.name 2>$null
    "### $($repo.Name)  (on $branch, this machine commits as '$me')"
    foreach ($line in $log) {
        $f = $line -split '\|', 4
        $mine = if ($f[2] -eq $me) { '*' } else { ' ' }
        "$mine $($f[1]) $($f[2].PadRight(14)) $($f[3])"
    }
    $dirty = git -C $p status --short 2>$null
    if ($dirty) { "  (uncommitted changes present: $(@($dirty).Count) paths)" }
    ""
}
if (-not $found) { "No commits in the window under: $($Root -join ', ')"; "" }
"Lines marked * are this machine's own commits. Everything else is a teammate or upstream."
""

# --- Sessions ---------------------------------------------------------------
"## Sessions"
""

$skip  = '^(<task-notification|<system-reminder|<local-command|<user_instructions|<environment_context|<app-context|<recommended_plugins|<command-message>\s*</|\[Request interrupted)'
# Housekeeping commands carry no work: "/clear clear", "/model model", "/compact", ...
$noise = '^(clear|model|compact|cost|status|resume|exit|help|config|context|login|logout|init)\s+\1?\s*$'

function Write-Session {
    param([string]$Label, [System.Collections.Generic.List[string]]$Prompts, [string]$Closing)
    if ($Prompts.Count -eq 0 -and -not $Closing) { return }
    "### $Label"
    "**Asked for:**"
    $Prompts
    if ($Closing) {
        $s = $Closing
        if ($s.Length -gt $SummaryChars) { $s = $s.Substring(0, $SummaryChars) + '...' }
        ""
        "**Closing report:**"
        $s
    }
    ""
}

function Add-Prompt {
    param([System.Collections.Generic.List[string]]$Prompts, [string]$Text, [datetime]$Stamp)
    if (-not $Text) { return }
    if ($Text -match $skip) { return }
    $t = (($Text -replace '</?command-(name|message|args)>', ' ') -replace '\s+', ' ').Trim()
    $t = $t -replace '^/', ''
    if (-not $t -or $t -match $noise) { return }
    if ($t.Length -gt $PromptChars) { $t = $t.Substring(0, $PromptChars) + '...' }
    $Prompts.Add("[$($Stamp.ToString('HH:mm'))] $t")
}

# Claude Code: ~/.claude/projects/<project>/<session>.jsonl
$claudeRoot = Join-Path $HOME '.claude/projects'
if (Test-Path $claudeRoot) {
    $files = Get-ChildItem $claudeRoot -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $day -and $_.LastWriteTime -lt $next -and $_.FullName -notmatch '[\\/]subagents[\\/]' }
    foreach ($f in $files) {
        $project = Split-Path (Split-Path $f.FullName -Parent) -Leaf
        $prompts = New-Object System.Collections.Generic.List[string]
        $closing = $null
        foreach ($line in [System.IO.File]::ReadLines($f.FullName, [System.Text.Encoding]::UTF8)) {
            try { $o = $line | ConvertFrom-Json } catch { continue }
            if ($o.isSidechain) { continue }
            if (-not $o.timestamp) { continue }
            $stamp = ([datetime]$o.timestamp).ToLocalTime()
            if ($stamp -lt $day -or $stamp -ge $next) { continue }
            if ($o.type -eq 'user' -and -not $o.isMeta) {
                $c = $o.message.content
                $t = if ($c -is [string]) { $c } else { ($c | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' ' }
                Add-Prompt $prompts $t $stamp
            }
            elseif ($o.type -eq 'assistant') {
                $t = ($o.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n"
                if ($t.Trim()) { $closing = $t.Trim() }
            }
        }
        Write-Session "Claude Code - $project - $($f.BaseName.Substring(0,8)) (last active $($f.LastWriteTime.ToString('HH:mm')))" $prompts $closing
    }
}

# Codex CLI: ~/.codex/sessions/<yyyy>/<MM>/<dd>/rollout-*.jsonl
$codexRoot = Join-Path $HOME '.codex/sessions'
if (Test-Path $codexRoot) {
    $dayDir = Join-Path $codexRoot $day.ToString('yyyy/MM/dd')
    $files = @()
    if (Test-Path $dayDir) { $files += Get-ChildItem $dayDir -Filter *.jsonl -File -ErrorAction SilentlyContinue }
    # A session that started the day before and ran past midnight still holds this day's turns.
    $prevDir = Join-Path $codexRoot $day.AddDays(-1).ToString('yyyy/MM/dd')
    if (Test-Path $prevDir) {
        $files += Get-ChildItem $prevDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $day }
    }
    foreach ($f in $files) {
        $prompts = New-Object System.Collections.Generic.List[string]
        $closing = $null
        $cwd = $null
        foreach ($line in [System.IO.File]::ReadLines($f.FullName, [System.Text.Encoding]::UTF8)) {
            try { $o = $line | ConvertFrom-Json } catch { continue }
            if ($o.type -eq 'session_meta' -and $o.payload.cwd) { $cwd = Split-Path $o.payload.cwd -Leaf; continue }
            if ($o.type -ne 'response_item' -or $o.payload.type -ne 'message') { continue }
            if (-not $o.timestamp) { continue }
            $stamp = ([datetime]$o.timestamp).ToLocalTime()
            if ($stamp -lt $day -or $stamp -ge $next) { continue }
            $t = ($o.payload.content | Where-Object { $_.text } | ForEach-Object { $_.text }) -join "`n"
            if (-not $t.Trim()) { continue }
            switch ($o.payload.role) {
                'user'      { Add-Prompt $prompts $t.Trim() $stamp }
                'assistant' { $closing = $t.Trim() }
            }
        }
        $label = if ($cwd) { $cwd } else { 'session' }
        Write-Session "Codex - $label - $($f.BaseName) (last active $($f.LastWriteTime.ToString('HH:mm')))" $prompts $closing
    }
}
