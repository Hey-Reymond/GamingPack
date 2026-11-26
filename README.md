# 🎮 Gaming Pack

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Project Status](https://img.shields.io/badge/status-Active%20%7C%20v1.1-brightgreen.svg)](https://github.com/Hey-Reymond/GamingPack)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue.svg)](#pré-requisitos)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-orange.svg)](https://github.com/Hey-Reymond/GamingPack/issues)

> **Transforme seu Windows novo em uma estação de batalha totalmente equipada em minutos!**

Uma suíte de automação de código aberto que configura um ambiente de jogos completo, instalando todos os seus launchers, ferramentas de otimização e dependências essenciais com um único comando.

---

## ✨ Recursos Principais

- 🚀 **Setup em Um Clique** - Instale todos os seus apps de jogos de uma vez.
- 📦 **Configuração via JSON** - Adicione ou remova aplicativos facilmente editando o `packages_windows.json`.
- 🔄 **Instalação Híbrida** - Usa Winget (preferencial) e Chocolatey (pacotes exclusivos ou fallback configurado no JSON).
- 🔁 **Resistente a conflitos** - Repete a instalação quando o Windows Update está ocupando o instalador (erro 1618).
- ✅ **Verificação de Existência** - Roda rapidamente e só instala o que está faltando.
- 🧹 **Manutenção Fácil** - Inclui um script `update_windows.ps1` para manter tudo atualizado e limpo.

---

## 🛠️ Arsenal de Ferramentas

Este pack instala as seguintes categorias de software, definidas no `packages_windows.json`:

| Categoria | Ferramentas e Tecnologias |
|----------|----------------------|
| **🎮 Launchers e Unificação** | Steam, Epic Games, GOG, EA App, Ubisoft Connect, Hydra Launcher, Heroic, Playnite |
| **⚡ Otimização Avançada** | Process Lasso, DDU, WizTree, BleachBit, Revo Uninstaller, DnsJumper, FilterKeysSetter |
| **🕹️ Runtimes de Compatibilidade** | VCRedist (All-in-One), DirectX (Legacy), .NET Framework (Legacy), .NET Desktop Runtime (Modern), JRE (Java 17) |
| **📊 Monitoramento e Hardware** | MSI Afterburner, HWMonitor, GPU-Z, CrystalDiskInfo |
| **🎙️ Comunicação e Input** | Discord, TeamSpeak, DS4Windows (via choco), EarTrumpet |
| **📡 Rede e Utilitários** | Cloudflare WARP, Parsec, ShareX, OBS Studio |
| **🧰 Utilitários Essenciais** | 7-Zip, WinRAR, gsudo, PowerShell, Oh My Posh, VLC |

**Instalação manual** (sem pacote no winget/choco — o script lista os links no final): Riot Client, Razer Cortex, Microsoft PC Manager, TCP Optimizer, OP AutoClicker e TimerResolution.

> ⚠️ **Atenção:** auto-clickers e ferramentas que alteram o sistema podem ser detectados por anti-cheats (Vanguard, EAC, BattlEye) e causar banimento. Use por sua conta e risco.

---

## 📥 Instalação e Uso

### Pré-requisitos
- Um PC com **Windows 10** ou **Windows 11**
- **Git** instalado (irônico, você pode adicioná-lo ao JSON!)
- Privilégios de Administrador

### 🪟 Windows Setup

**Passo 1: Clonar o Repositório**
```bash
git clone https://github.com/Hey-Reymond/GamingPack
cd GamingPack
```

**Passo 2: Executar o Script de Setup Abra o PowerShell como Administrador:**
```powershell
# Desbloqueia o script para execução
Set-ExecutionPolicy Bypass -Scope Process -Force

# Executa o setup
.\setup_windows.ps1
```

**Passo 3: Relaxar**

* O script irá instalar o Chocolatey (se necessário), baixar o Windows Update em background, e instalar todos os apps do `packages_windows.json`.

* Reinicie o PC no final, se solicitado.

---

## ⚙️ Configuração de Pacotes

Para adicionar ou remover programas, basta editar o `packages_windows.json`:

* `winget`: IDs de pacotes do Windows Package Manager (preferencial). Confira o ID exato com `winget search <nome>`.
* `choco`: nomes de pacotes do Chocolatey (dependências como `vcredist-all` ou apps que não estão no winget).
* `manual`: apps sem pacote; o script só mostra o nome e o link no final.

> ⚠️ O arquivo precisa ser **JSON puro** — comentários `//` quebram a leitura no Windows PowerShell 5.1. Para anotações, use uma chave como `"_info"`.

Exemplo:

```json
{
  "winget": [
    "Valve.Steam",
    "Guru3D.Afterburner",
    { "name": "Discord", "winget": "Discord.Discord", "choco": "discord" }
  ],
  "choco": [
    "vcredist-all"
  ],
  "manual": [
    { "name": "Razer Cortex", "url": "https://www.razer.com/cortex" }
  ]
}
```

Uma entrada no formato objeto (`{ "winget": ..., "choco": ... }`) ativa o **fallback**: se o winget falhar, o script tenta o nome informado no Chocolatey.

## 🔄 Manutenção e Updates

Para manter seus aplicativos atualizados e o sistema limpo:

```powershell
# Rode como Administrador
.\update_windows.ps1
```

O que ele faz:

* Atualiza todos os pacotes Winget (`winget upgrade --all`).

* Atualiza todos os pacotes Chocolatey (`choco upgrade all -y`).

* Limpa caches de pacotes e arquivos temporários do sistema (a pasta Prefetch é preservada, pois acelera a abertura de jogos e apps).

## 📄 Licença

Este projeto é licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.
