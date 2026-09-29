# ==============================================================================
# MÓDULO: Reviver PC Antigo (Desempenho)
# ==============================================================================

function Invoke-MenuDesempenho {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "REVIVER PC ANTIGO (DESEMPENHO)"

        Write-Host "   Este modulo foca em desligar recursos pesados para melhorar o uso" -ForegroundColor Gray
        Write-Host "   de processador, disco e memoria RAM em computadores antigos." -ForegroundColor Gray
        Write-Host ""

        Write-MenuOption "1"  "Desativar Aplicativos em Segundo Plano (Background Apps)"
        Write-MenuOption "2"  "Desativar Efeitos Visuais e Animacoes"
        Write-MenuOption "3"  "Desativar Indexacao de Arquivos (Windows Search) - Salva Disco (HDD)"
        Write-MenuOption "4"  "Desativar Servicos de Telemetria e Diagnosticos"
        Write-MenuOption "5"  "Desativar Superfetch / SysMain (Para quem usa HD mecanico)"
        Write-MenuOption "6"  "Otimizacao Completa (Aplicar todos de uma vez)"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Disable-BackgroundApps }
            "2" { Disable-VisualEffectsDesempenho }
            "3" { Disable-WindowsSearch }
            "4" { Disable-Telemetry }
            "5" { Disable-SysMain }
            "6" { Invoke-FullOptimization }
            "0" { $loop = $false }
            default { Write-Host "   Opcao invalida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Disable-BackgroundApps {
    Write-Header
    Write-SubHeader "DESATIVAR APLICATIVOS EM SEGUNDO PLANO"
    Write-Host "   Desativando permissao para apps rodarem no fundo..." -ForegroundColor Yellow
    
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $path2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    New-Item -Path $path2 -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path2 -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-Status "Aplicativos em segundo plano desativados!" "OK"
    Write-Log "Background Apps desativados."
    Pause-Script
}

function Disable-VisualEffectsDesempenho {
    Write-Header
    Write-SubHeader "DESATIVAR EFEITOS VISUAIS"
    Write-Host "   Ajustando para Melhor Desempenho..." -ForegroundColor Yellow

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $sysParams = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $sysParams -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String -Force -ErrorAction SilentlyContinue

    Write-Status "Efeitos visuais desativados! (Mais velocidade de janela)" "OK"
    Write-Log "Efeitos visuais desativados (Modo Desempenho)."
    Pause-Script
}

function Disable-WindowsSearch {
    Write-Header
    Write-SubHeader "DESATIVAR INDEXACAO (WINDOWS SEARCH)"
    Write-Host "   AVISO: A busca do Menu Iniciar vai ficar mais lenta," -ForegroundColor Yellow
    Write-Host "   mas o HD ira parar de ficar em 100% de uso o tempo todo." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "   Confirmar desativacao? (S/N)"
    if ($confirm -match "^[Ss]") {
        Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
        Set-Service -Name WSearch -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Status "Servico Windows Search desativado!" "OK"
        Write-Log "Windows Search desativado."
    }
    Pause-Script
}

function Disable-Telemetry {
    Write-Header
    Write-SubHeader "DESATIVAR TELEMETRIA"
    Write-Host "   Parando envio de dados de diagnostico para a Microsoft..." -ForegroundColor Yellow

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
    Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name dmwappushservice -Force -ErrorAction SilentlyContinue
    Set-Service -Name dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue

    Write-Status "Telemetria e rastreamento desativados!" "OK"
    Write-Log "Telemetria desativada."
    Pause-Script
}

function Disable-SysMain {
    Write-Header
    Write-SubHeader "DESATIVAR SYSMAIN (SUPERFETCH)"
    Write-Host "   Ideal para HDDs antigos que ficam em 100% de uso." -ForegroundColor Yellow
    
    Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
    Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
    
    Write-Status "SysMain desativado!" "OK"
    Write-Log "SysMain desativado."
    Pause-Script
}

function Invoke-FullOptimization {
    Write-Header
    Write-SubHeader "OTIMIZACAO COMPLETA (REVIVER PC)"
    Write-Host "   Isso ira aplicar TODAS as correcoes de desempenho de uma vez." -ForegroundColor Yellow
    Write-Host "   (Criaremos um ponto de restauracao por seguranca)" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   Aplicar otimizacao total? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host "   Criando ponto de restauracao..." -ForegroundColor Gray
        Checkpoint-Computer -Description "CHAMADO - Reviver PC" -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue
        
        Write-Host "   1. Aplicativos em 2o Plano..." -ForegroundColor Yellow
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $path -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        Write-Host "   2. Efeitos Visuais..." -ForegroundColor Yellow
        $pathfx = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        Set-ItemProperty -Path $pathfx -Name "VisualFXSetting" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        Write-Host "   3. Desativando SysMain (Superfetch)..." -ForegroundColor Yellow
        Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
        Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue

        Write-Host "   4. Desativando Telemetria..." -ForegroundColor Yellow
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Status "Otimizacao completa finalizada! Recomendado reiniciar o PC." "OK"
        Write-Log "Otimizacao total (Reviver PC) aplicada."
    }
    Pause-Script
}
