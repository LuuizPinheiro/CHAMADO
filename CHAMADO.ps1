<#
.SYNOPSIS
    CHAMADO v2.0 - Central de Suporte Técnico
.DESCRIPTION
    Ferramenta open-source de diagnóstico, reparo e otimização de
    sistemas Windows. Desenvolvido por Pinea Code.
    GitHub: https://github.com/seu-usuario/CHAMADO
#>

# ==============================================================================
# INICIALIZAÇÃO GLOBAL
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"

$global:AppVersion  = "v2.0"
$global:AppName     = "CHAMADO"
$global:AppAuthor   = "Pinea Code"
$global:ScriptRoot  = $PSScriptRoot

# Detecta se está rodando de pendrive (portátil) ou PC local
$global:DataDir = Join-Path $global:ScriptRoot "data"
$global:LogDir  = Join-Path $global:DataDir "logs"
$global:CfgDir  = Join-Path $global:DataDir "config"
$global:CfgFile = Join-Path $global:CfgDir "theme.cfg"

# Cria diretórios se não existem
foreach ($dir in @($global:DataDir, $global:LogDir, $global:CfgDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$global:LogFile = Join-Path $global:LogDir "chamado_$(Get-Date -Format 'yyyyMMdd').log"

# Carrega tema salvo ou usa padrão
$global:ThemeColor = "Green"
if (Test-Path $global:CfgFile) {
    $saved = Get-Content $global:CfgFile -ErrorAction SilentlyContinue
    if ($saved) { $global:ThemeColor = $saved.Trim() }
}

# ==============================================================================
# FUNÇÕES GLOBAIS (usadas por todos os módulos)
# ==============================================================================

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $global:LogFile -Value "[$ts] [$Type] $Message"
}

function Write-Header {
    [Console]::ResetColor()
    Clear-Host
    $c = $global:ThemeColor
    Write-Host ""
    Write-Host "  ======================================================================" -ForegroundColor $c
    Write-Host ""
    Write-Host "   ██████╗██╗  ██╗ █████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗ " -ForegroundColor $c
    Write-Host "  ██╔════╝██║  ██║██╔══██╗████╗ ████║██╔══██╗██╔══██╗██╔═══██╗" -ForegroundColor $c
    Write-Host "  ██║     ███████║███████║██╔████╔██║███████║██║  ██║██║   ██║" -ForegroundColor $c
    Write-Host "  ██║     ██╔══██║██╔══██║██║╚██╔╝██║██╔══██║██║  ██║██║   ██║" -ForegroundColor $c
    Write-Host "  ╚██████╗██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║██████╔╝╚██████╔╝" -ForegroundColor $c
    Write-Host "   ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝ " -ForegroundColor $c
    Write-Host ""
    Write-Host "   CENTRAL DE SUPORTE TÉCNICO" -ForegroundColor White
    Write-Host "   Desenvolvido por $($global:AppAuthor) | $($global:AppVersion)" -ForegroundColor DarkGray
    Write-Host "  ======================================================================" -ForegroundColor $c
    Write-Host ""
}

function Write-SubHeader {
    param([string]$Title)
    $c = $global:ThemeColor
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   $Title" -ForegroundColor $c
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("OK","WARN","ERRO","INFO","CRIT")]
        [string]$Level = "INFO"
    )
    $icon = switch ($Level) {
        "OK"   { "[  OK  ]"; }
        "WARN" { "[ AVISO]"; }
        "ERRO" { "[ ERRO ]"; }
        "INFO" { "[ INFO ]"; }
        "CRIT" { "[CRITICO]"; }
    }
    $color = switch ($Level) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "ERRO" { "Red" }
        "INFO" { "Cyan" }
        "CRIT" { "Red" }
    }
    Write-Host "   $icon " -ForegroundColor $color -NoNewline
    Write-Host "$Message" -ForegroundColor White
}

function Write-MenuOption {
    param([string]$Key, [string]$Text, [string]$Color = "White")
    Write-Host "   [$Key] " -ForegroundColor $global:ThemeColor -NoNewline
    Write-Host "$Text" -ForegroundColor $Color
}

function Pause-Script {
    Write-Host ""
    Write-Host "   Pressione qualquer tecla para continuar..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-Choice {
    param([string]$Prompt = "   Opção")
    Write-Host ""
    $r = Read-Host "   $Prompt"
    return $r
}

function Write-ProgressBar {
    param([int]$Percent, [int]$Width = 30)
    $filled = [math]::Round($Width * $Percent / 100)
    $empty  = $Width - $filled
    $bar    = ("$([char]9608)" * $filled) + ("$([char]9617)" * $empty)
    $color  = if ($Percent -lt 25) { "Red" } elseif ($Percent -lt 50) { "Yellow" } else { "Green" }
    Write-Host "   [$bar] $($Percent)%" -ForegroundColor $color
}

# ==============================================================================
# CARREGA MÓDULOS
# ==============================================================================
$modulesPath = Join-Path $global:ScriptRoot "modules"

$moduleFiles = @(
    "tema.ps1",
    "diagnostico.ps1",
    "rede.ps1",
    "reparos.ps1",
    "otimizacao-gaming.ps1",
    "seguranca.ps1",
    "limpeza.ps1",
    "backup.ps1",
    "pos-formatacao.ps1",
    "ferramentas.ps1",
    "auto-diagnostico.ps1",
    "analisador-disco.ps1",
    "desempenho.ps1"
)

foreach ($mod in $moduleFiles) {
    $modPath = Join-Path $modulesPath $mod
    if (Test-Path $modPath) {
        . $modPath
    } else {
        Write-Host "  [AVISO] Módulo não encontrado: $mod" -ForegroundColor Yellow
    }
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================
function Show-MainMenu {
    $running = $true
    while ($running) {
        Write-Header

        Write-Host "   MENU PRINCIPAL" -ForegroundColor White
        Write-Host ""
        Write-MenuOption "1"  "Auto-Diagnostico (Analise Completa + Correcoes)"
        Write-MenuOption "2"  "Diagnostico Detalhado do Sistema"
        Write-MenuOption "3"  "Ferramentas de Rede"
        Write-MenuOption "4"  "Reparos e Manutencao"
        Write-MenuOption "5"  "Otimizacao para Jogos (Gaming Mode)"
        Write-MenuOption "6"  "Reviver PC Antigo (Desempenho)"
        Write-MenuOption "7"  "Seguranca e Privacidade"
        Write-MenuOption "8"  "Limpeza Profunda"
        Write-MenuOption "9"  "Backup Rapido (Ninja Backup)"
        Write-MenuOption "10" "Pos-Formatacao: Instalar Programas"
        Write-MenuOption "11" "Ferramentas do Tecnico (Atalhos)"
        Write-MenuOption "12" "Coleta Rapida (Info p/ Chamado)"
        Write-MenuOption "13" "Analisador de Disco (Espaco e Arquivos)"
        Write-MenuOption "14" "Personalizar Tema" $global:ThemeColor
        Write-MenuOption "0"  "Sair" "DarkGray"

        $choice = Get-Choice "Digite a opção desejada"

        switch ($choice) {
            "1"  { Invoke-AutoDiagnostico }
            "2"  { Invoke-DiagnosticoDetalhado }
            "3"  { Invoke-MenuRede }
            "4"  { Invoke-MenuReparos }
            "5"  { Invoke-MenuGaming }
            "6"  { Invoke-MenuDesempenho }
            "7"  { Invoke-MenuSeguranca }
            "8"  { Invoke-MenuLimpeza }
            "9"  { Invoke-MenuBackup }
            "10" { Invoke-MenuPosFormatacao }
            "11" { Invoke-MenuFerramentas }
            "12" { Invoke-ColetaRapida }
            "13" { Invoke-MenuAnalisadorDisco }
            "14" { Invoke-MenuTema }
            "0"  {
                Write-Log "CHAMADO encerrado pelo usuário."
                Write-Host ""
                Write-Host "   Obrigado por usar o CHAMADO! Até a próxima." -ForegroundColor $global:ThemeColor
                Write-Host ""
                $running = $false
            }
            default {
                Write-Host "   Opção inválida!" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ==============================================================================
# INICIA O PROGRAMA
# ==============================================================================
Write-Log "========== CHAMADO $($global:AppVersion) iniciado =========="
Write-Log "Executando de: $($global:ScriptRoot)"
Show-MainMenu
