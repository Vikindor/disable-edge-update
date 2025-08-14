# =========================================================
# restore_edgeupdate.ps1
# Restore Microsoft Edge/WebView2 updater behavior:
# - Remove folder ACL restrictions
# - Clear update policies
# - Set services to Manual and start them
# - Verify; friendly logging (OK / SKIP/INFO / ERROR)
# =========================================================

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

Write-Host "[1/5] Remove folder ACL restrictions..." -ForegroundColor Cyan
$paths = @(
  "C:\Program Files (x86)\Microsoft\EdgeUpdate",
  "C:\Program Files\Microsoft\EdgeUpdate"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Try-Run "take ownership $p"           { Takeown /f "$p" /r /d y | Out-Null }
        Try-Run "grant Administrators:F $p"   { Icacls "$p" /grant Administrators:F /t | Out-Null }
        Try-Run "enable inheritance $p"       { Icacls "$p" /inheritance:e | Out-Null }
        Try-Run "remove DENY Everyone on $p"  { Icacls "$p" /remove:d "*S-1-1-0" | Out-Null } -WarnOKIfMissing
    } else {
        Write-Host "SKIP/INFO: folder not found $p" -ForegroundColor Yellow
    }
}

Write-Host "[2/5] Remove registry policies..." -ForegroundColor Cyan
Try-Run "delete HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" {
    Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Recurse -Force
} -WarnOKIfMissing

Write-Host "[3/5] Set services to Manual..." -ForegroundColor Cyan
foreach ($svc in 'edgeupdate','edgeupdatem') {
    Try-Run "set $svc startup to Manual" { Set-Service $svc -StartupType Manual } -WarnOKIfMissing
}

Write-Host "[4/5] Start services..." -ForegroundColor Cyan
foreach ($svc in 'edgeupdate','edgeupdatem') {
    Try-Run "start $svc service" { Start-Service $svc } -WarnOKIfMissing
}

Write-Host "[5/5] Verify..." -ForegroundColor Cyan
Try-Run "services state edgeupdate"  { Get-Service edgeupdate  | Select-Object Name,StartType,Status | Format-Table -AutoSize } -WarnOKIfMissing
Try-Run "services state edgeupdatem" { Get-Service edgeupdatem | Select-Object Name,StartType,Status | Format-Table -AutoSize } -WarnOKIfMissing
Write-Host "INFO: Scheduled tasks will be recreated by Edge/WebView2 during next update or by the Evergreen installer."

Write-Host "`nRestore complete."
Read-Host "Press ENTER to exit"
