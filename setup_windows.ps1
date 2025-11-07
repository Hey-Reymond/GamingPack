<#
.SYNOPSIS
    "Super" Master Script para configurar um ambiente Windows para Gaming.
.DESCRIPTION
    1. Garante privilégios de Administrador (usando gsudo se disponível).
    2. Instala Chocolatey (se não instalado).
    3. Habilita a autoconfirmação do Chocolatey.
    4. Instala/Atualiza TODAS as ferramentas de jogos (Seção 5) e Windows Updates (Seção 8) em paralelo.
    5. Limpa todos os arquivos temporários e otimiza o sistema.
.NOTES
    Version: 1.0 (Baseado no ESSENTIALSPPACK v5.2)
    Author: Kaua
    LOGIC: Usa a função híbrida Install-Package com prioridade winget e fallback choco.
#>

# --- 0. Helper Functions & Global Variables ---
$Global:RebootIsNeeded = $false
$Global:InstallSummary = @{
    Succeeded = @()
    Failed = @()
    Skipped = @()
}

function Test-RebootRequired {
    try {
        if (Get-Command Test-PendingReboot -ErrorAction SilentlyContinue) {
            if (Test-PendingReboot -ErrorAction SilentlyContinue) { return $true }
        }
    } catch {}
    
    $RegKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    )
    
    foreach ($key in $RegKeys) {
        if (Test-Path $key) { return $true }
    }
    
    if (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue) {
        return $true
    }
    
    return $false
}

function Install-PSModuleSafely {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Instalando módulo PowerShell: $Name..." -ForegroundColor Yellow
        try {
            Install-Module -Name $Name -Force -Scope AllUsers -AllowClobber -SkipPublisherCheck -ErrorAction Stop
        } catch {
            Write-Host "  WARNING: Falha ao instalar $Name - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Módulo PowerShell '$Name' já instalado." -ForegroundColor Green
    }
}

function Write-InstallSummary {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  RESUMO DA INSTALAÇÃO" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "✓ Sucesso ($($Global:InstallSummary.Succeeded.Count)):" -ForegroundColor Green
    if ($Global:InstallSummary.Succeeded.Count -gt 0) {
        foreach ($pkg in $Global:InstallSummary.Succeeded) {
            Write-Host "  - $pkg" -ForegroundColor Green
        }
    } else {
        Write-Host "  (nenhum)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "✗ Falha ($($Global:InstallSummary.Failed.Count)):" -ForegroundColor Red
    if ($Global:InstallSummary.Failed.Count -gt 0) {
        foreach ($pkg in $Global:InstallSummary.Failed) {
            if ($pkg -is [hashtable]) {
                Write-Host "  - $($pkg.Package) (Exit: $($pkg.ExitCode), Error: $($pkg.Error))" -ForegroundColor Red
            } else {
                Write-Host "  - $pkg" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  (nenhum)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "⊘ Ignorado ($($Global:InstallSummary.Skipped.Count)):" -ForegroundColor Yellow
    if ($Global:InstallSummary.Skipped.Count -gt 0) {
        foreach ($pkg in $Global:InstallSummary.Skipped) {
            Write-Host "  - $pkg" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  (nenhum)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    
    $logDir = Join-Path $env:LOCALAPPDATA "ESSENTIALSGAMINGPACK"
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = Join-Path $logDir "install-log-$timestamp.json"
    
    $summaryObject = @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        ScriptVersion = "1.0"
        Succeeded = $Global:InstallSummary.Succeeded
        Failed = $Global:InstallSummary.Failed
        Skipped = $Global:InstallSummary.Skipped
        Statistics = @{
            TotalSucceeded = $Global:InstallSummary.Succeeded.Count
            TotalFailed = $Global:InstallSummary.Failed.Count
            TotalSkipped = $Global:InstallSummary.Skipped.Count
        }
    }
    
    try {
        $summaryObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding UTF8
        Write-Host "Log de instalação salvo em: $logFile" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Falha ao escrever log: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- HYBRID INSTALLATION FUNCTION (DO SEU PACK ORIGINAL) ---
function Install-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName,
        [string]$WingetId = "",
        [scriptblock]$SpecialHandler = $null,
        
        # --- OTIMIZAÇÃO NÍVEL 2 ---
        [string[]]$InstalledWingetCache = @(),
        [string[]]$InstalledChocoCache = @()
    )
    
    Write-Host "  -> Instalando: $PackageName" -ForegroundColor Cyan
    
    if ($WingetId) {
        if ($InstalledWingetCache -match $WingetId) {
            Write-Host "  ✓ $PackageName (já instalado via winget)" -ForegroundColor Green
            $Global:InstallSummary.Succeeded += $PackageName
            return $true
        }
    }
    
    if ($InstalledChocoCache -match $PackageName) {
        Write-Host "  ✓ $PackageName (já instalado via choco)" -ForegroundColor Green
        $Global:InstallSummary.Succeeded += $PackageName
        return $true
    }
    
    if ($WingetId) {
        Write-Host "    Tentando winget..." -ForegroundColor Gray
        $installResult = Start-Process -FilePath winget -ArgumentList "install --id $WingetId --accept-package-agreements --accept-source-agreements -h" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        
        if ($null -ne $installResult -and $installResult.ExitCode -eq 0) {
            Write-Host "  ✓ $PackageName (instalado via winget)" -ForegroundColor Green
            $Global:InstallSummary.Succeeded += $PackageName
            return $true
        } elseif ($null -ne $installResult -and $installResult.ExitCode -eq -1978335189) {
            Write-Host "  ✓ $PackageName (já atualizado via winget)" -ForegroundColor Green
            $Global:InstallSummary.Succeeded += $PackageName
            return $true
        }
        
        Write-Host "    Winget falhou, tentando chocolatey..." -ForegroundColor Yellow
    }
    
    $output = ""
    $exitCode = 0
    
    try {
        $output = choco upgrade $PackageName -y --noprogress 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } catch {
        $output = $_.Exception.Message
        $exitCode = -1
    }
    
    if ($null -ne $SpecialHandler) {
        & $SpecialHandler -ExitCode $exitCode -Output $output -PackageName $PackageName
    }
    
    if ($exitCode -eq 0) {
        Write-Host "  ✓ $PackageName (instalado via choco)" -ForegroundColor Green
        $Global:InstallSummary.Succeeded += $PackageName
        return $true
    } elseif ($exitCode -eq 1605 -or $exitCode -eq 1614 -or $exitCode -eq 1641) {
        Write-Host "  ✓ $PackageName (já instalado ou requer reinicialização)" -ForegroundColor Green
        $Global:InstallSummary.Succeeded += $PackageName
        return $true
    } else {
        Write-Host "  ✗ $PackageName (exit code: $exitCode)" -ForegroundColor Yellow
        $Global:InstallSummary.Failed += @{
            Package = $PackageName
            ExitCode = $exitCode
            Error = if ($output -match "error|failed") { ($output -split "`n" | Select-Object -First 3) -join "; " } else { "Unknown error" }
        }
        return $false
    }
}

# --- 0.1. Check de Reboot Pendente ---
if (Test-RebootRequired) {
    Write-Host "WARNING: Reinicialização pendente detectada." -ForegroundColor Red
    Write-Host "Recomenda-se reiniciar antes de continuar." -ForegroundColor Yellow
    Read-Host "Pressione ENTER para continuar mesmo assim..."
}

# --- 1. Check de Administrador (gsudo fallback) ---
Write-Host "Checando privilégios de Administrador..." -ForegroundColor Yellow
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        Write-Host "Solicitando privilégios via gsudo..." -ForegroundColor Yellow
        gsudo "$PSCommandPath"
        exit
    } else {
        Write-Host "ERROR: Este script precisa ser executado como Administrador." -ForegroundColor Red
        Read-Host "Pressione ENTER para sair..."
        exit
    }
}
Write-Host "Privilégios de Administrador confirmados." -ForegroundColor Green

# --- 3. Check e Instalação do Chocolatey ---
Write-Host ""
Write-Host "Checando se o Chocolatey está instalado..."
$chocoPath = Get-Command choco -ErrorAction SilentlyContinue
if ($null -eq $chocoPath) {
    Write-Host "Chocolatey não encontrado. Instalando..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey instalado com sucesso!" -ForegroundColor Green
        $env:Path = "$($env:Path);$($env:ALLUSERSPROFILE)\chocolatey\bin"
    } catch {
        Write-Host "ERROR: Falha ao instalar Chocolatey." -ForegroundColor Red
        Read-Host "Pressione ENTER para sair..."
        exit
    }
} else {
    Write-Host "Chocolatey já está instalado." -ForegroundColor Green
}

# --- 4. Habilitando Autoconfirmação do Chocolatey ---
Write-Host ""
Write-Host "Habilitando confirmação automática do Chocolatey..." -ForegroundColor Yellow
try {
    choco feature enable -n=allowGlobalConfirmation | Out-Null
    Write-Host "Feature 'allowGlobalConfirmation' habilitada." -ForegroundColor Green
} catch {
    Write-Host "WARNING: Falha ao habilitar 'allowGlobalConfirmation'." -ForegroundColor Yellow
}


# --- INICIAR WINDOWS UPDATE EM BACKGROUND ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  INICIANDO JOB PARALELO (Windows Update)..." -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""

Write-Host "[+] Instalando 'PSWindowsUpdate' (necessário para o job)..." -ForegroundColor Cyan
Install-PSModuleSafely -Name "PSWindowsUpdate"

Write-Host "[+] Iniciando Job: Windows Update (em background)..." -ForegroundColor Cyan
$JobWinUpdate = Start-Job -Name "WinUpdate" -ScriptBlock {
    Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
    
    if (-not (Get-Command Install-WindowsUpdate -ErrorAction SilentlyContinue)) {
        Write-Host "JOB (WU) ERROR: Módulo PSWindowsUpdate não pôde ser importado." -ForegroundColor Red
        return $false
    }
    
    Write-Host "JOB (WU): Procurando e instalando updates..."
    try {
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction SilentlyContinue | Out-Null
        Write-Host "JOB (WU): Verificação de updates completa."
        if (Get-Command Test-PendingReboot -ErrorAction SilentlyContinue) {
            if (Test-PendingReboot -ErrorAction SilentlyContinue) { return $true }
        }
    } catch {
        Write-Host "JOB (WU) ERROR: Falha ao rodar Windows Update." -ForegroundColor Red
    }
    return $false
}

# --- 5. INICIANDO INSTALAÇÃO DAS FERRAMENTAS DE GAMING (THREAD PRINCIPAL) ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  INICIANDO INSTALAÇÃO/UPGRADE DE FERRAMENTAS DE GAMING"
Write-Host "  (Windows Update está rodando em paralelo...)"
Write-Host "============================================================"
Write-Host ""

# --- CACHE DE PACOTES (NÍVEL 2) ---
Write-Host "Construindo cache de pacotes (pode levar um momento)..." -ForegroundColor Yellow
$installedWinget = @()
$installedChoco = @()
try {
    $installedWinget = winget list 2>&1 | Out-String
} catch {
    Write-Host "  WARNING: Falha ao construir cache winget." -ForegroundColor Yellow
}
try {
    $installedChoco = choco list -lo --limitoutput 2>&1 | Out-String
} catch {
    Write-Host "  WARNING: Falha ao construir cache choco." -ForegroundColor Yellow
}
Write-Host "Cache de pacotes construído." -ForegroundColor Green

# --- CARREGAR DEFINIÇÕES DO JSON ---
$PackageJsonPath = Join-Path $PSScriptRoot "packages_windows.json"
if (-not (Test-Path $PackageJsonPath)) {
    Write-Host "ERROR: packages_windows.json não encontrado em: $PackageJsonPath" -ForegroundColor Red
    Read-Host "Pressione ENTER para sair..."
    exit
}
try {
    $PackageDefinitions = Get-Content $PackageJsonPath -Raw | ConvertFrom-Json
    Write-Host "Definições de pacotes carregadas do JSON." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Falha ao ler packages_windows.json" -ForegroundColor Red
    Read-Host "Pressione ENTER para sair..."
    exit
}

# 5.1: INSTALAR PACOTES WINGET
Write-Host ">>> Iniciando pacotes Winget (com fallback para Choco)..." -ForegroundColor Yellow
foreach ($packageId in $PackageDefinitions.winget) {
    Install-Package -PackageName $packageId -WingetId $packageId -InstalledWingetCache $installedWinget -InstalledChocoCache $installedChoco
}

# 5.2: INSTALAR PACOTES CHOCO-ONLY
Write-Host ""
Write-Host ">>> Iniciando pacotes Chocolatey-only..." -ForegroundColor Yellow
foreach ($packageName in $PackageDefinitions.choco) {
    Install-Package -PackageName $packageName -InstalledWingetCache $installedWinget -InstalledChocoCache $installedChoco
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  INSTALAÇÃO DE FERRAMENTAS CONCLUÍDA!" -ForegroundColor Green
Write-Host "================================================="
Write-Host ""

# --- 8. SINCRONIZAÇÃO DO WINDOWS UPDATE ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SINCRONIZANDO JOBS (Windows Update)..." -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""

Write-Host "Aguardando conclusão do Windows Update..." -ForegroundColor Yellow
$WinUpdateJobResult = Wait-Job -Name "WinUpdate"
$RebootNeededByUpdate = $WinUpdateJobResult | Receive-Job

Write-Host "[+] Log do Windows Update Job:" -ForegroundColor Cyan
Write-Host $RebootNeededByUpdate
Write-Host "Sincronização concluída." -ForegroundColor Green

if ($RebootNeededByUpdate -eq $true) {
    $Global:RebootIsNeeded = $true
}
Remove-Job -Name "WinUpdate" -ErrorAction SilentlyContinue


# --- 9. LIMPEZA DO SISTEMA ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  INICIANDO LIMPEZA E OTIMIZAÇÃO DO SISTEMA..." -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""

Write-Host "[+] Limpando arquivos temporários..." -ForegroundColor Cyan
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[+] Limpando cache do Chocolatey..." -ForegroundColor Cyan
choco cache remove --all 2>&1 | Out-Null

Write-Host "[+] Otimizando drive C:..." -ForegroundColor Cyan
Optimize-Volume -DriveLetter C -ErrorAction SilentlyContinue | Out-Null

Write-Host "Limpeza do sistema concluída." -ForegroundColor Green

# --- 9.1: RESUMO DA INSTALAÇÃO ---
Write-InstallSummary

# --- 10. Finalização ---
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  SETUP DE GAMING COMPLETO!" -ForegroundColor Green
Write-Host "================================================="
Write-Host ""

if (Test-RebootRequired) {
    $Global:RebootIsNeeded = $true
}

if ($Global:RebootIsNeeded) {
    Write-Host "****************** REINICIALIZAÇÃO NECESSÁRIA ******************" -ForegroundColor Red
    Write-Host "Uma reinicialização é necessária para finalizar o Windows Update."
    Write-Host "Por favor, reinicie seu computador."
    Write-Host "*****************************************************" -ForegroundColor Red
} else {
    Write-Host "Todas as tarefas concluídas." -ForegroundColor Green
    Write-Host "FECHE E REABRA seu terminal para que todas as"
    Write-Host "mudanças de PATH tenham efeito." -ForegroundColor Yellow
}

Read-Host "Pressione ENTER para fechar..."
