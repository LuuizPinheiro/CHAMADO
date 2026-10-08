<p align="center">
  <h1 align="center">CHAMADO</h1>
  <p align="center"><strong>Central de Suporte Técnico</strong></p>
  <p align="center">
    <em>"Abre um CHAMADO!"</em> — A ferramenta open-source que resolve o que o TI pediu pra você abrir um chamado.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/plataforma-Windows%2010%2F11-blue?logo=windows" alt="Windows">
  <img src="https://img.shields.io/badge/linguagem-PowerShell-5391FE?logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/badge/licença-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/versão-v2.0-orange" alt="Version">
</p>

---

**🇧🇷 Português** | [🇺🇸 English](#english)

---

## O que é o CHAMADO?

O **CHAMADO** é uma ferramenta de terminal para Windows que funciona como um **canivete suíço** para técnicos de TI, gamers e usuários avançados. Ele roda direto de um `.bat` (pode ser de um pendrive!) e oferece:

- 🔍 **Diagnóstico automático** com sugestão de correções
- 🌐 **Ferramentas de rede** completas (ping, DNS, Wi-Fi, traceroute)
- 🔧 **Reparos** do Windows (SFC, DISM, Spooler, Windows Update)
- 🎮 **Otimização para jogos** (Modo Seguro/Agressivo, Instalação do DirectX Legacy)
- 🛡️ **Segurança** (Defender, Firewall, BitLocker, RDP)
- 🧹 **Limpeza profunda** com relatório de espaço liberado
- 💾 **Backup rápido** (Ninja Backup) com Robocopy
- 📦 **Pós-formatação avançada** com 13 pacotes e mais de 110 programas via Winget
- 🖨️ **Impressoras de Rede** com busca automática e instalação via IP/WSD
- 📊 **Analisador de Disco** ultrarrápido em C# para arquivos grandes
- 🧰 **Atalhos rápidos** para ferramentas do Windows
- 🎨 **Tema customizável** (6 cores)

## Como usar

### Opção 1: Executar no PC
1. Baixe ou clone este repositório
2. Clique com botão direito em `CHAMADO.bat` → **Executar como administrador**
3. Pronto! O menu principal aparecerá no terminal

### Opção 2: Executar de um Pendrive (Portátil)
1. Copie a pasta `CHAMADO` inteira para o pendrive
2. Conecte o pendrive no PC alvo
3. Execute `CHAMADO.bat` como administrador
4. Logs e configurações são salvos na própria pasta do projeto

### Requisitos
- Windows 10 ou 11
- PowerShell 5.1+ (já vem com o Windows)
- Winget (para instalar programas — já vem no Windows 11 e updates recentes do 10)
- Executar como **Administrador** (o .bat faz isso automaticamente)

## Estrutura do Projeto

```
CHAMADO/
├── CHAMADO.bat              # Inicializador com elevação de admin
├── CHAMADO.ps1              # Motor principal (menu + carrega módulos)
├── modules/
│   ├── auto-diagnostico.ps1 # Análise completa + correções automáticas
│   ├── diagnostico.ps1      # Diagnóstico detalhado do sistema
│   ├── rede.ps1             # Ferramentas de rede
│   ├── reparos.ps1          # Reparos e manutenção
│   ├── otimizacao-gaming.ps1# Otimizações para jogos
│   ├── desempenho.ps1       # Otimizações para computadores antigos
│   ├── seguranca.ps1        # Segurança e privacidade
│   ├── limpeza.ps1          # Limpeza profunda
│   ├── backup.ps1           # Ninja Backup
│   ├── pos-formatacao.ps1   # Instalação de programas
│   ├── analisador-disco.ps1 # Scanner C# para localizar arquivos gigantes
│   ├── impressoras.ps1      # Busca e instalação de impressoras de rede
│   ├── ferramentas.ps1      # Atalhos do técnico
│   └── tema.ps1             # Personalização visual
├── data/                    # Criado automaticamente (logs, config)
├── README.md
├── LICENSE
└── CHANGELOG.md
```

## Screenshots

*Em breve*

## Contribuindo

Contribuições são muito bem-vindas! Como o projeto é modular, você pode:
1. Fazer fork do repositório
2. Criar uma branch (`git checkout -b feature/minha-feature`)
3. Editar o módulo desejado na pasta `modules/`
4. Commit (`git commit -m 'Adiciona minha feature'`)
5. Push (`git push origin feature/minha-feature`)
6. Abrir um Pull Request

## Roadmap

- [x] v2.0 — Estrutura modular completa
- [ ] v2.5 — Speed test, cache de browsers, timer resolution
- [ ] v3.0 — Auto-update, GUI opcional, perfis salvos

---

<a name="english"></a>

## 🇺🇸 English

### What is CHAMADO?

**CHAMADO** (Portuguese for "ticket" / "service request") is an open-source Windows terminal tool that works as a **Swiss Army knife** for IT technicians, gamers, and power users. It runs directly from a `.bat` file (even from a USB drive!) and provides:

- 🔍 **Auto-diagnostic** with suggested fixes
- 🌐 **Network tools** (ping, DNS, Wi-Fi passwords, traceroute)
- 🔧 **Windows repairs** (SFC, DISM, Spooler, Windows Update)
- 🎮 **Gaming optimization** (Safe/Aggressive Mode, DirectX Legacy Installer)
- 🛡️ **Security** (Defender, Firewall, BitLocker, RDP)
- 🧹 **Deep cleanup** with freed space report
- 💾 **Quick backup** (Ninja Backup) with Robocopy
- 📦 **Advanced Post-format setup** with 13 packs and >110 programs via Winget
- 🖨️ **Network printers** with auto-discovery and IP/WSD installation
- 📊 **Disk analyzer** ultra-fast C#-based engine for large files
- 🧰 **Quick shortcuts** to Windows management tools
- 🎨 **Customizable theme** (6 colors)

### How to use

1. Download or clone this repository
2. Right-click `CHAMADO.bat` → **Run as administrator**
3. Done! The main menu will appear in the terminal

### Requirements
- Windows 10 or 11
- PowerShell 5.1+ (built into Windows)
- Winget (for installing programs)
- Run as **Administrator**

### Portable Mode (USB Drive)
Copy the entire `CHAMADO` folder to a USB drive and run `CHAMADO.bat` on any target PC. Logs and settings are stored locally within the project folder.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Author

Developed by **Pinea Code**
