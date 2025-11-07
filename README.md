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
| **🎮 Launchers** | Steam, Epic Games, GOG Galaxy, Discord, HydraLauncher, Heroic |
| **⚡ Otimização** | Microsoft PC Manager, Razer Cortex, DnsJumper, TimerResolution, FilterKeysSetter |
| **📊 Monitoramento & Captura** | MSI Afterburner, OBS Studio, NVIDIA GeForce Experience, Parsec |
| **🕹️ Dependências Essenciais** | VCRedist (All-in-One), DirectX |
| **🧰 Utilitários de Terminal** | gsudo, Oh My Posh, Bat, Eza |

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
