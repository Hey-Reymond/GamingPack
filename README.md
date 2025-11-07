# 💻 Essentials Gaming Pack

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Project Status](https://img.shields.io/badge/status-Active%20%7C%20v1.0-brightgreen.svg)]()
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue.svg)]()
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-orange.svg)]()

> **Transforme seu Windows novo em uma estação de batalha totalmente equipada em minutos!**

Uma suíte de automação de código aberto que configura um ambiente de jogos completo, instalando todos os seus launchers, ferramentas de otimização e dependências essenciais com um único comando.

---

## ✨ Recursos Principais

- 🚀 **Setup em Um Clique** - Instale todos os seus apps de jogos de uma vez.
- 📦 **Configuração via JSON** - Adicione ou remova aplicativos facilmente editando o `packages_windows.json`.
- 🔄 **Instalação Híbrida Inteligente** - Usa Winget (preferencial) e Chocolatey (fallback) para máxima confiabilidade.
- ✅ **Verificação de Existência** - Roda rapidamente e só instala o que está faltando.
- 🧹 **Manutenção Fácil** - Inclui um script `update_windows.ps1` para manter tudo atualizado e limpo.

---

## 🛠️ Arsenal de Ferramentas

Este pack instala as seguintes categorias de software, definidas no `packages_windows.json`:

| Categoria | Ferramentas e Tecnologias |
|----------|----------------------|
| **🎮 Launchers e Unificação** | Steam, Epic Games, GOG, EA App, Ubisoft Connect, Riot Client, HydraLauncher, Heroic, Playnite |
| **⚡ Otimização Avançada** | Process Lasso, DDU, WizTree, BleachBit, Revo Uninstaller, Razer Cortex, TimerResolution, DnsJumper, FilterKeysSetter, TCPOptimizer |
| **🕹️ Runtimes de Compatibilidade** | VCRedist (All-in-One), DirectX (Legacy), .NET Framework (Legacy), .NET Desktop Runtime (Modern), JRE (Java 17) |
| **📊 Monitoramento e Hardware** | MSI Afterburner, HWMonitor, GPU-Z, CrystalDiskInfo |
| **🎙️ Comunicação e Input** | Discord, TeamSpeak, DS4Windows, EarTrumpet |
| **📡 Rede e Utilitários** | Cloudflare WARP, Parsec, ShareX, OBS Studio, OP AutoClicker, Microsoft PC Manager |
| **🧰 Utilitários Essenciais** | 7-Zip, WinRAR, gsudo, PowerShell, Oh My Posh, VLC |

---

## 📥 Instalação e Uso

### Pré-requisitos
- Um PC com **Windows 10** ou **Windows 11**
- **Git** instalado (irônico, você pode adicioná-lo ao JSON!)
- Privilégios de Administrador

### 🪟 Windows Setup

**Passo 1: Clonar o Repositório**
```bash
git clone https://github.com/reireymond/GamingPack
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

--

Para adicionar ou remover programas, basta editar o packages_windows.json:

* winget: IDs de pacotes do Windows Package Manager (preferencial).

* choco: Nomes de pacotes do Chocolatey (para dependências como vcredist-all ou apps que não estão no winget).

Exemplo:

```json
{
  "winget": [
    "Valve.Steam",
    "MSI.Afterburner"
  ],
  "choco": [
    "vcredist-all"
  ]
}
```

## 🔄 Manutenção e Updates

--

Para manter seus aplicativos atualizados e o sistema limpo:

```powershell
# Rode como Administrador
.\update_windows.ps1
```

O que ele faz:

* Atualiza todos os pacotes Winget (`winget upgrade --all`).

* Atualiza todos os pacotes Chocolatey (`choco upgrade all -y`).

* Limpa caches de pacotes e arquivos temporários do sistema.

## 📄 Licença

==

Este projeto é licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.
