# Changelog

Todas as mudanças notáveis do projeto serão documentadas neste arquivo.

## [2.1.0] - 2026-10-08

### Adicionado
- **DirectX Legacy**: Nova opção na otimização de jogos para baixar e instalar silenciosamente dlls do DX9/10 (ex: d3dx9_43.dll) para corrigir crashes em jogos clássicos.
- **Analisador de Disco em C#**: Módulo ultrarrápido que supera as limitações do PowerShell (caminhos longos, Access Denied) para mapear os maiores arquivos.
- **Impressoras de Rede**: Novo módulo integrado ao menu que escaneia a rede (Ping/ARP), localiza portas (9100/515) e instala portas TCP/IP padrão.
- **Pós-Formatação Avançada**: Expandido para 13 categorias e mais de 110 programas mapeados via Gerenciador de Pacotes do Windows (Winget), incluindo pacotes automáticos.

## [2.0.0] - 2026-09-28

### Adicionado
- **Arquitetura modular**: Cada funcionalidade separada em módulos independentes (`modules/`)
- **Auto-Diagnóstico**: Análise completa do PC com correções automáticas sugeridas
- **Ferramentas de Rede**: Info completa, ping, traceroute, troca de DNS, senhas Wi-Fi
- **Gaming Mode**: Modo Seguro e Modo Agressivo com opção de reverter tudo
- **Segurança**: Status do Defender, scans, Firewall, BitLocker, RDP, usuários
- **Limpeza Profunda**: 7 tipos de limpeza + Modo Turbo com relatório de espaço
- **Ninja Backup**: Backup de pastas, drivers, Wi-Fi e lista de programas
- **Pós-Formatação**: 7 packs de programas (Essenciais, Runtimes, Gamer, etc)
- **Ferramentas do Técnico**: 15 atalhos rápidos para painéis do Windows
- **Personalização de Tema**: 6 cores com persistência
- **Modo Portátil**: Funciona direto de pendrive
- **README bilíngue**: PT-BR + English
- **Sistema de logs** com timestamps

### Melhorado
- Logo ASCII legível
- Menu principal reorganizado com 12 opções
- Funções utilitárias globais (Write-Status, Write-MenuOption, Write-ProgressBar)

## [1.5.0] - 2026-09-28

### Adicionado
- Troca de cor do tema
- Verificação de BitLocker e Defender
- Ferramentas do Técnico (4 atalhos)

## [1.2.0] - 2026-09-28

### Inicial
- Menu básico com análise, reparos e instalação de programas
- Coleta de informações para chamado
