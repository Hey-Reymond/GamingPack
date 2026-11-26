<#
.SYNOPSIS
    Script to update all Winget applications, Chocolatey packages, and clean system.
.DESCRIPTION
    1. Guarantees Administrator privileges (re-launches via gsudo if needed).
    2. Updates all Winget packages.
    3. Updates all Chocolatey packages.
    4. Cleans all temporary files and optimizes the drive.
.NOTES
    Version: 3.1 (Fixed admin detection; Prefetch no longer cleared)
    Author: Kaua
#>

# --- 1. Administrator Check ---
# NOTE: 'gsudo -v' only prints gsudo's version (always succeeds), so it can't be used
# to detect elevation. Use the Windows principal check instead.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        Write-Host "Requesting Administrator privileges via gsudo..." -ForegroundColor Yellow
        # Re-launch this script as admin and exit the current one
        gsudo "$($PSCommandPath)"
        exit
    }
    Write-Host "ERROR: This script must be run as Administrator (or install 'gsudo')." -ForegroundColor Red
    Read-Host "Press ENTER to exit..."
    exit 1
}
Write-Host "Administrator privileges confirmed." -ForegroundColor Green


# --- 2. Winget Upgrade ---
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  STARTING APPLICATION UPGRADE (WINGET)"
Write-Host "===================================================="
    
winget upgrade --all --accept-package-agreements --accept-source-agreements

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  WINGET UPGRADE COMPLETE."
Write-Host "  STARTING PACKAGE UPGRADE (CHOCOLATEY)"
Write-Host "===================================================="
Write-Host ""

# --- 3. Chocolatey Upgrade ---
# The '-y' (or '--yes') flag accepts all choco-specific prompts.
choco upgrade all -y

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  CHOCO UPGRADE COMPLETE."
Write-Host "  STARTING SYSTEM CLEANUP & OPTIMIZATION"
Write-Host "===================================================="
Write-Host ""

# --- 4. System Cleanup (from setup.ps1) ---
Write-Host "[+] Cleaning up Windows temporary files (User & System)..." -ForegroundColor Cyan
# Clear User Temp Folder (%temp%)
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
# Clear Windows Temp Folder (temp)
Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
# Prefetch is intentionally NOT cleared: Windows uses it to speed up boot and app/game launches.

Write-Host "[+] Cleaning up Chocolatey package cache..." -ForegroundColor Cyan
choco cache remove --all

Write-Host "[+] Optimizing main drive (C:)... (TRIM or Defrag)" -ForegroundColor Cyan
Optimize-Volume -DriveLetter C -ErrorAction SilentlyContinue

Write-Host "System cleanup complete." -ForegroundColor Green
    
# --- 5. Finalization ---
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  SYSTEM FULLY UPDATED AND CLEANED"
Write-Host "===================================================="
Write-Host ""
Read-Host "Press ENTER to close..."
