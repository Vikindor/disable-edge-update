# =========================================================
# disable_edgeupdate.ps1
# Disable Microsoft Edge/WebView2 auto-updater:
# - Stop & disable services (edgeupdate, edgeupdatem)
# - Terminate updater process
# - Remove scheduled tasks (GUID-safe, with existence re-check)
# - Set update policies (hard by default, soft with -SoftBlock)
# - Remove EdgeUpdate folders and recreate with ACL deny (W,X) for Everyone
# - Verify results; friendly logging with error handling
# =========================================================

param(
  [switch]$SoftBlock  # if set, only disable auto-checks; otherwise also set UpdateDefault=0
)

$ErrorActionPreference = 'Stop'

function Try-Run {
    param(
        [string]$Label,
        [ScriptBlock]$Action,
        [switch]$WarnOKIfMissing
    )
    try {
        & $Action
        Write-Host "OK: $Label" -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message
        if ($WarnOKIfMissing) {
            Write-Host "SKIP/INFO: $Label ($msg)" -ForegroundColor Yellow
        } else {
            Write-Host "ERROR: $Label ($msg)" -ForegroundColor Red
        }
    }
}

# [0] Warn if running 32-bit PowerShell on 64-bit Windows
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and [Environment]::Is64BitOperatingSystem) {
  Write-Host "WARN: 32-bit PowerShell detected on 64-bit OS. Prefer a 64-bit host (PowerShell 7 x64 or Windows PowerShell x64)." -ForegroundColor Yellow
}

Write-Host "[1/6] Stop and disable services..." -ForegroundColor Cyan
foreach ($svc in 'edgeupdate','edgeupdatem') {
    Try-Run "stop $svc"    { Stop-Service $svc -Force } -WarnOKIfMissing
    Try-Run "disable $svc" { Set-Service  $svc -StartupType Disabled } -WarnOKIfMissing
}

Write-Host "[2/6] Terminate running updater process..." -ForegroundColor Cyan
Try-Run "terminate MicrosoftEdgeUpdate.exe" {
    Get-Process MicrosoftEdgeUpdate -ErrorAction Stop | Stop-Process -Force
} -WarnOKIfMissing

Write-Host "[3/6] Delete scheduled tasks (GUID-safe, with re-check)..." -ForegroundColor Cyan
$pass = 0
do {
    $pass++
    $tasks = @()
    Try-Run "enumerate tasks (pass $pass)" {
        $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'MicrosoftEdgeUpdateTask*' }
    } -WarnOKIfMissing

    foreach ($t in $tasks) {
        # Re-check existence just before deleting (avoid race noise)
        $exists = Get-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction SilentlyContinue
        if (-not $exists) {
            Write-Host "SKIP/INFO: task already gone $($t.TaskPath)$($t.TaskName)" -ForegroundColor Yellow
            continue
        }

        Try-Run "stop task $($t.TaskPath)$($t.TaskName)" {
            Stop-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath
        } -WarnOKIfMissing

        Try-Run "delete task $($t.TaskPath)$($t.TaskName)" {
            Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false
        }
    }
} while ($tasks.Count -gt 0 -and $pass -lt 3)

Write-Host "[4/6] Set update policies..." -ForegroundColor Cyan
Try-Run "ensure policy key exists" {
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Force | Out-Null
}
Try-Run "set AutoUpdateCheckPeriodMinutes = 0" {
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'AutoUpdateCheckPeriodMinutes' -Value 0 -PropertyType DWord -Force | Out-Null
}
if (-not $SoftBlock) {
    Try-Run "set UpdateDefault = 0 (hard block)" {
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'UpdateDefault' -Value 0 -PropertyType DWord -Force | Out-Null
    }
} else {
    Write-Host "INFO: SoftBlock mode — leaving UpdateDefault untouched"
}

Write-Host "[5/6] Remove and block EdgeUpdate folders..." -ForegroundColor Cyan
$paths = @(
  "C:\Program Files (x86)\Microsoft\EdgeUpdate",
  "C:\Program Files\Microsoft\EdgeUpdate"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Try-Run "take ownership $p"         { Takeown /f "$p" /r /d y | Out-Null }
        Try-Run "grant Administrators:F $p" { Icacls "$p" /grant Administrators:F /t | Out-Null }
        Try-Run "remove folder $p"          { Remove-Item -LiteralPath $p -Recurse -Force }
    } else {
        Write-Host "INFO: folder not found (will create): $p"
    }
    Try-Run "create folder $p"              { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Try-Run "disable inheritance $p"        { Icacls "$p" /inheritance:r | Out-Null }
    Try-Run "grant Admins:F $p"             { Icacls "$p" /grant:r "Administrators:(OI)(CI)F" | Out-Null }
    Try-Run "deny Everyone (W,X) $p"        { Icacls "$p" /deny "*S-1-1-0:(OI)(CI)(W,X)" | Out-Null }
}

Write-Host "[6/6] Verify..." -ForegroundColor Cyan
Try-Run "services state edgeupdate"  { Get-Service edgeupdate  | Select-Object Name,StartType,Status | Format-Table -AutoSize } -WarnOKIfMissing
Try-Run "services state edgeupdatem" { Get-Service edgeupdatem | Select-Object Name,StartType,Status | Format-Table -AutoSize } -WarnOKIfMissing
Try-Run "remaining tasks" {
    $left = Get-ScheduledTask | Where-Object { $_.TaskName -like 'MicrosoftEdgeUpdateTask*' } | Select-Object TaskPath,TaskName
    if ($left) { $left | Format-Table -AutoSize } else { Write-Host "OK: no remaining tasks" -ForegroundColor Green }
}

Write-Host "`nDone. Auto-updates should be disabled."
Write-Host "Manual WebView2 updates: use the Evergreen Standalone installer from Microsoft."
Read-Host "Press ENTER to exit"
