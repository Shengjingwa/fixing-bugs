param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$Transcript = '',
    [int]$PollSeconds = 15,
    [int]$HeartbeatMinutes = 20,
    [int]$StallMinutes = 10
)

$progress = Join-Path $Worktree 'progress.md'

function Get-Head {
    $h = git --no-optional-locks -C $Worktree rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { return "$h".Trim() }
    return ''
}

# Wake only for commits A must look at now: Flow: step / fix, or no Flow trailer.
# wip, docs and anchored-adapt-only commits are picked up on the next wake.
function Test-NeedsReview([string]$From, [string]$To) {
    $shas = git --no-optional-locks -C $Worktree rev-list "$From..$To" 2>$null
    if ($LASTEXITCODE -ne 0) { return $true }
    foreach ($sha in @($shas)) {
        $body = (git --no-optional-locks -C $Worktree log -1 --format=%B $sha 2>$null) -join "`n"
        $flows = @([regex]::Matches($body, '(?m)^Flow:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
        if ($flows.Count -eq 0 -or ($flows -contains 'step') -or ($flows -contains 'fix')) { return $true }
    }
    return $false
}

function Get-RequestCount {
    if (-not (Test-Path -LiteralPath $progress)) { return 0 }
    return @(Select-String -LiteralPath $progress -Pattern '^### R-' -ErrorAction SilentlyContinue).Count
}

function Get-TranscriptState {
    if (-not $Transcript -or -not (Test-Path -LiteralPath $Transcript)) { return $null }
    $last = Get-Content -LiteralPath $Transcript -Tail 1 -ErrorAction SilentlyContinue
    return @{
        Length = (Get-Item -LiteralPath $Transcript).Length
        Idle   = ("$last" -match '"type"\s*:\s*"turn_ended"')
    }
}

$head = Get-Head
$requests = Get-RequestCount
$lastEvent = Get-Date
$ts = Get-TranscriptState
$tsLength = if ($ts) { $ts.Length } else { -1 }
$tsGrewAt = Get-Date
$stallReported = $false
Write-Output "DUO_READY_$Tag head=$head requests=$requests transcript=$([bool]$ts)"

while ($true) {
    Start-Sleep -Seconds $PollSeconds
    $now = Get-Date

    $h = Get-Head
    if ($h -and $h -ne $head) {
        if (-not $head -or (Test-NeedsReview $head $h)) {
            Write-Output "DUO_WAKE_$Tag commit $h"
            $lastEvent = $now
        }
        $head = $h
    }

    $r = Get-RequestCount
    if ($r -ne $requests) {
        Write-Output "DUO_WAKE_$Tag request $r"
        $requests = $r
        $lastEvent = $now
    }

    $ts = Get-TranscriptState
    if ($ts) {
        if ($ts.Length -ne $tsLength) {
            $tsLength = $ts.Length
            $tsGrewAt = $now
            $stallReported = $false
        }
        elseif (-not $ts.Idle -and -not $stallReported -and ($now - $tsGrewAt).TotalMinutes -ge $StallMinutes) {
            Write-Output "DUO_WAKE_$Tag stall"
            $stallReported = $true
            $lastEvent = $now
        }
    }

    if (($now - $lastEvent).TotalMinutes -ge $HeartbeatMinutes) {
        Write-Output "DUO_WAKE_$Tag heartbeat"
        $lastEvent = $now
    }
}
