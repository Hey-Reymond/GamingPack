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
    Version: 1.1 (Baseado no ESSENTIALSPPACK v5.2)
    Author: Kaua
    LOGIC: Usa a função híbrida Install-Package com prioridade winget e fallback choco
           (o fallback só acontece quando o JSON informa o nome do pacote no choco).
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
    Write-Host "⊘ Já instalado / ignorado ($($Global:InstallSummary.Skipped.Count)):" -ForegroundColor Yellow
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
        ScriptVersion = "1.1"
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

# --- INSTALAÇÃO HÍBRIDA (winget -> choco) ---

# Códigos de saída tratados
$Script:WingetAlreadyInstalledCodes = @(
    -1978335189,  # 0x8A15002B: nenhuma atualização aplicável
    -1978335135   # 0x8A150061: pacote já instalado
)
$Script:InstallInProgressCodes = @(
    1618,         # MSI: outra instalação em andamento (ex.: Windows Update em paralelo)
    -1978334974   # 0x8A150102: winget - instalação em andamento
)
$Script:ChocoSuccessCodes = @(0, 1605, 1614, 1641, 3010)

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object -or $Object -is [string]) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function ConvertTo-PackageSpec {
    # Aceita "Winget.Id" (string) ou { "name": "...", "winget": "...", "choco": "..." }
    param($Entry, [switch]$ChocoOnly)
    if ($Entry -is [string]) {
        if ($ChocoOnly) { return [pscustomobject]@{ Name = $Entry; Winget = ""; Choco = $Entry } }
        return [pscustomobject]@{ Name = $Entry; Winget = $Entry; Choco = "" }
    }
    $winget = [string](Get-JsonProperty $Entry "winget")
    $choco  = [string](Get-JsonProperty $Entry "choco")
    $name   = [string](Get-JsonProperty $Entry "name")
    if (-not $name) { $name = if ($winget) { $winget } else { $choco } }
    return [pscustomobject]@{ Name = $name; Winget = $winget; Choco = $choco }
}

function Get-WingetInstalledIds {
    # 'winget list' corta IDs longos com "…"; 'winget export' devolve os IDs completos.
    $ErrorActionPreference = 'Continue'
    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $tmp = Join-Path $env:TEMP "winget-export-$PID.json"
    try {
        winget export -o $tmp --accept-source-agreements 2>&1 | Out-Null
        if (Test-Path $tmp) {
            $data = Get-Content $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($src in $data.Sources) {
                foreach ($pkg in $src.Packages) { [void]$ids.Add($pkg.PackageIdentifier) }
            }
        }
    } catch {
        Write-Host "  WARNING: Falha ao listar pacotes do winget: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    return ,$ids
}

function Get-ChocoInstalledNames {
    # Choco v2: 'list' já é local. Choco v1: precisa de '-lo' (sem ele lista o repositório remoto inteiro).
    $ErrorActionPreference = 'Continue'
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    try {
        $major = 0
        [void][int]::TryParse(((choco --version 2>$null | Select-Object -First 1) -split '\.')[0], [ref]$major)
        $lines = if ($major -ge 2) { choco list -r 2>$null } else { choco list -lo -r 2>$null }
        foreach ($line in $lines) {
            $pkgName = ($line -split '\|')[0].Trim()
            if ($pkgName) { [void]$names.Add($pkgName) }
        }
    } catch {
        Write-Host "  WARNING: Falha ao listar pacotes do Chocolatey: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return ,$names
}

function Invoke-WithInstallRetry {
    # Repete a instalação quando outro instalador (ex.: Windows Update) está ocupando o MSI.
    param([scriptblock]$Action, [string]$PackageName, [int]$MaxAttempts = 4, [int]$DelaySeconds = 45)
    $code = 0
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $code = & $Action
        if ($Script:InstallInProgressCodes -notcontains $code) { return $code }
        if ($attempt -lt $MaxAttempts) {
            Write-Host "    Outra instalação em andamento (código $code). Nova tentativa em $DelaySeconds s... ($attempt/$MaxAttempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $code
}

function Install-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName,
        [string]$WingetId = "",
        [string]$ChocoName = "",
        [scriptblock]$SpecialHandler = $null,
        $InstalledWinget = $null,
        $InstalledChoco = $null
    )

    # Comandos nativos escrevem em stderr; isso não pode virar exceção aqui.
    $ErrorActionPreference = 'Continue'

    Write-Host "  -> Instalando: $PackageName" -ForegroundColor Cyan

    if ($WingetId -and $InstalledWinget -and $InstalledWinget.Contains($WingetId)) {
        Write-Host "  ✓ $PackageName (já instalado via winget)" -ForegroundColor Green
        $Global:InstallSummary.Skipped += $PackageName
        return $true
    }
    if ($ChocoName -and $InstalledChoco -and $InstalledChoco.Contains($ChocoName)) {
        Write-Host "  ✓ $PackageName (já instalado via choco)" -ForegroundColor Green
        $Global:InstallSummary.Skipped += $PackageName
        return $true
    }

    if ($WingetId) {
        Write-Host "    Tentando winget..." -ForegroundColor Gray
        $wingetCode = Invoke-WithInstallRetry -PackageName $PackageName -Action {
            winget install --id $WingetId -e --accept-package-agreements --accept-source-agreements -h | Out-Host
            $LASTEXITCODE
        }

        if ($wingetCode -eq 0) {
            Write-Host "  ✓ $PackageName (instalado via winget)" -ForegroundColor Green
            $Global:InstallSummary.Succeeded += $PackageName
            return $true
        } elseif ($Script:WingetAlreadyInstalledCodes -contains $wingetCode) {
            Write-Host "  ✓ $PackageName (já instalado/atualizado via winget)" -ForegroundColor Green
            $Global:InstallSummary.Skipped += $PackageName
            return $true
        }

        if (-not $ChocoName) {
            Write-Host "  ✗ $PackageName (winget falhou, código $wingetCode; sem fallback no choco)" -ForegroundColor Yellow
            $Global:InstallSummary.Failed += @{
                Package  = $PackageName
                ExitCode = $wingetCode
                Error    = "winget install falhou e não há nome 'choco' definido no JSON"
            }
            return $false
        }
        Write-Host "    Winget falhou (código $wingetCode), tentando Chocolatey ($ChocoName)..." -ForegroundColor Yellow
    }

    $output = ""
    $Script:LastChocoOutput = ""
    $exitCode = Invoke-WithInstallRetry -PackageName $PackageName -Action {
        $Script:LastChocoOutput = choco upgrade $ChocoName -y --no-progress 2>&1 | Out-String
        $LASTEXITCODE
    }
    $output = $Script:LastChocoOutput

    if ($null -ne $SpecialHandler) {
        & $SpecialHandler -ExitCode $exitCode -Output $output -PackageName $PackageName
    }

    if ($Script:ChocoSuccessCodes -contains $exitCode) {
        if ($exitCode -in 1641, 3010) { $Global:RebootIsNeeded = $true }
        Write-Host "  ✓ $PackageName (instalado via choco)" -ForegroundColor Green
        $Global:InstallSummary.Succeeded += $PackageName
        return $true
    }

    Write-Host "  ✗ $PackageName (exit code: $exitCode)" -ForegroundColor Yellow
    $Global:InstallSummary.Failed += @{
        Package  = $PackageName
        ExitCode = $exitCode
        Error    = if ($output -match "error|failed") { ($output -split "`n" | Where-Object { $_ -match "error|failed" } | Select-Object -First 3) -join "; " } else { "Unknown error" }
    }
    return $false
}

function Show-ManualPackages {
    param($Entries)
    if (-not $Entries) { return }
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  INSTALAÇÃO MANUAL (sem pacote no winget/choco)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    foreach ($entry in $Entries) {
        $name = Get-JsonProperty $entry "name"
        $url  = Get-JsonProperty $entry "url"
        $note = Get-JsonProperty $entry "note"
        Write-Host "  - $name" -ForegroundColor Yellow -NoNewline
        if ($url)  { Write-Host "  ->  $url" -NoNewline }
        Write-Host ""
        if ($note) { Write-Host "      $note" -ForegroundColor Gray }
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

# --- CACHE DE PACOTES ---
Write-Host "Construindo cache de pacotes (pode levar um momento)..." -ForegroundColor Yellow
$installedWinget = Get-WingetInstalledIds
$installedChoco = Get-ChocoInstalledNames
Write-Host "Cache de pacotes construído ($($installedWinget.Count) winget / $($installedChoco.Count) choco)." -ForegroundColor Green

# --- CARREGAR DEFINIÇÕES DO JSON ---
$PackageJsonPath = Join-Path $PSScriptRoot "packages_windows.json"
if (-not (Test-Path $PackageJsonPath)) {
    Write-Host "ERROR: packages_windows.json não encontrado em: $PackageJsonPath" -ForegroundColor Red
    Read-Host "Pressione ENTER para sair..."
    exit
}
try {
    $PackageDefinitions = Get-Content $PackageJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Definições de pacotes carregadas do JSON." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Falha ao ler packages_windows.json (JSON inválido? Comentários // não são permitidos)" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host "Pressione ENTER para sair..."
    exit
}

# 5.1: INSTALAR PACOTES WINGET (fallback para choco quando o JSON informa o nome no choco)
Write-Host ">>> Iniciando pacotes Winget..." -ForegroundColor Yellow
foreach ($entry in @(Get-JsonProperty $PackageDefinitions "winget")) {
    if ($null -eq $entry) { continue }
    $spec = ConvertTo-PackageSpec $entry
    Install-Package -PackageName $spec.Name -WingetId $spec.Winget -ChocoName $spec.Choco -InstalledWinget $installedWinget -InstalledChoco $installedChoco | Out-Null
}

# 5.2: INSTALAR PACOTES CHOCO-ONLY
Write-Host ""
Write-Host ">>> Iniciando pacotes Chocolatey-only..." -ForegroundColor Yellow
foreach ($entry in @(Get-JsonProperty $PackageDefinitions "choco")) {
    if ($null -eq $entry) { continue }
    $spec = ConvertTo-PackageSpec $entry -ChocoOnly
    Install-Package -PackageName $spec.Name -ChocoName $spec.Choco -InstalledWinget $installedWinget -InstalledChoco $installedChoco | Out-Null
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

Write-Host "[+] Limpando cache do Chocolatey..." -ForegroundColor Cyan
choco cache remove --all 2>&1 | Out-Null

Write-Host "[+] Otimizando drive C:..." -ForegroundColor Cyan
Optimize-Volume -DriveLetter C -ErrorAction SilentlyContinue | Out-Null

Write-Host "Limpeza do sistema concluída." -ForegroundColor Green

# --- 9.1: RESUMO DA INSTALAÇÃO ---
Write-InstallSummary
Show-ManualPackages (Get-JsonProperty $PackageDefinitions "manual")

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
