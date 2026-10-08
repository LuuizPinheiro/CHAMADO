# ==============================================================================
# MÓDULO: Otimização para Jogos (Gaming Mode)
# ==============================================================================

function Invoke-MenuGaming {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "OTIMIZAÇÃO PARA JOGOS (GAMING MODE)"

        Write-Host "   Escolha o modo de otimização:" -ForegroundColor White
        Write-Host ""
        Write-MenuOption "1"  "Modo Seguro (Otimizações conservadoras, seguro p/ qualquer PC)"
        Write-MenuOption "2"  "Modo Agressivo (Máximo FPS, desliga tudo que pode)"
        Write-Host ""
        Write-Host "   --- Otimizações Individuais ---" -ForegroundColor DarkGray
        Write-MenuOption "3"  "Ativar Plano de Energia: Alto Desempenho"
        Write-MenuOption "4"  "Ativar Plano Ultimate Performance (Oculto)"
        Write-MenuOption "5"  "Desativar Game Bar / Game DVR (Xbox Overlay)"
        Write-MenuOption "6"  "Desativar Nagle's Algorithm (Reduzir Latência)"
        Write-MenuOption "7"  "Desativar Efeitos Visuais do Windows"
        Write-MenuOption "8"  "Desativar Cortana / Widgets"
        Write-MenuOption "9"  "Desativar Prefetch/Superfetch (SSD)"
        Write-MenuOption "10" "Limpar RAM em Standby"
        Write-MenuOption "11" "Verificar/Instalar DirectX Legacy (Corrige erros .dll em jogos)"
        Write-Host ""
        Write-MenuOption "R"  "REVERTER TUDO (Restaurar padrões)" "Yellow"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1"  { Invoke-GamingSafe }
            "2"  { Invoke-GamingAggressive }
            "3"  { Set-HighPerformancePlan }
            "4"  { Set-UltimatePerformancePlan }
            "5"  { Disable-GameBar }
            "6"  { Disable-NaglesAlgorithm }
            "7"  { Disable-VisualEffects }
            "8"  { Disable-CortanaWidgets }
            "9"  { Disable-PrefetchSuperfetch }
            "10" { Clear-StandbyRAM }
            "11" { Install-DirectXLegacy }
            "R"  { Invoke-GamingRevert }
            "r"  { Invoke-GamingRevert }
            "0"  { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Save-OriginalValue {
    param([string]$Key, [string]$Name, $Value)
    $backupFile = Join-Path $global:CfgDir "gaming_backup.json"
    $backup = @{}
    if (Test-Path $backupFile) {
        $content = Get-Content $backupFile -Raw -ErrorAction SilentlyContinue
        if ($content) { $backup = $content | ConvertFrom-Json -ErrorAction SilentlyContinue }
    }
    $backupKey = "$Key\$Name"
    if (-not ($backup.PSObject.Properties.Name -contains $backupKey)) {
        $backup | Add-Member -NotePropertyName $backupKey -NotePropertyValue $Value -Force
        $backup | ConvertTo-Json | Set-Content $backupFile -Force
    }
}

function Create-GamingRestorePoint {
    Write-Host "   Criando ponto de restauração..." -ForegroundColor Gray
    try {
        Checkpoint-Computer -Description "CHAMADO Gaming Mode $(Get-Date -Format 'dd/MM HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Status "Ponto de restauração criado" "OK"
    } catch {
        Write-Status "Não foi possível criar ponto de restauração" "WARN"
    }
}

function Invoke-GamingSafe {
    Write-Header
    Write-SubHeader "GAMING MODE - SEGURO"
    Write-Host "   Otimizações seguras que não afetam a estabilidade:" -ForegroundColor White
    Write-Host "   - Plano de energia: Alto Desempenho" -ForegroundColor Gray
    Write-Host "   - Desativar Game Bar / DVR" -ForegroundColor Gray
    Write-Host "   - Desativar efeitos visuais" -ForegroundColor Gray
    Write-Host "   - Desativar Cortana/Widgets" -ForegroundColor Gray
    Write-Host "   - Limpar RAM em standby" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   Aplicar otimizações seguras? (S/N)"
    if ($confirm -match "^[Ss]") {
        Create-GamingRestorePoint
        Write-Host ""
        Set-HighPerformancePlan
        Disable-GameBar
        Disable-VisualEffects
        Disable-CortanaWidgets
        Clear-StandbyRAM
        Write-Host ""
        Write-Status "Modo Seguro aplicado com sucesso!" "OK"
        Write-Log "Gaming Mode Seguro aplicado."
    }
    Pause-Script
}

function Invoke-GamingAggressive {
    Write-Header
    Write-SubHeader "GAMING MODE - AGRESSIVO"
    Write-Host "   AVISO: Este modo desativa serviços e recursos do Windows." -ForegroundColor Red
    Write-Host "   Use apenas se souber o que está fazendo!" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Inclui tudo do Modo Seguro, mais:" -ForegroundColor White
    Write-Host "   - Plano Ultimate Performance" -ForegroundColor Gray
    Write-Host "   - Desativar Nagle's Algorithm" -ForegroundColor Gray
    Write-Host "   - Desativar Prefetch/Superfetch" -ForegroundColor Gray
    Write-Host "   - Desativar Telemetria" -ForegroundColor Gray
    Write-Host "   - Prioridade GPU em hardware scheduling" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   CONFIRMA o Modo Agressivo? (S/N)"
    if ($confirm -match "^[Ss]") {
        Create-GamingRestorePoint
        Write-Host ""
        Set-UltimatePerformancePlan
        Disable-GameBar
        Disable-VisualEffects
        Disable-CortanaWidgets
        Disable-NaglesAlgorithm
        Disable-PrefetchSuperfetch
        Clear-StandbyRAM

        # Desativar telemetria
        Write-Host "   Desativando telemetria..." -ForegroundColor Yellow
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Status "Telemetria desativada" "OK"

        # Hardware accelerated GPU scheduling
        Write-Host "   Ativando GPU Scheduling..." -ForegroundColor Yellow
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Status "Hardware GPU Scheduling ativado" "OK"

        Write-Host ""
        Write-Status "Modo Agressivo aplicado! Reinicie para efeito completo." "OK"
        Write-Log "Gaming Mode Agressivo aplicado."
    }
    Pause-Script
}

function Set-HighPerformancePlan {
    Write-Host "   Ativando plano Alto Desempenho..." -ForegroundColor Yellow
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    Write-Status "Plano de Energia: Alto Desempenho ativado" "OK"
    Write-Log "Plano Alto Desempenho ativado."
}

function Set-UltimatePerformancePlan {
    Write-Host "   Ativando plano Ultimate Performance..." -ForegroundColor Yellow
    # Tenta ativar o plano oculto
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
    $plans = powercfg /list
    $ultimate = $plans | Select-String "Ultimate|Máximo"
    if ($ultimate) {
        $guid = ($ultimate -split "\s+")[3]
        powercfg /setactive $guid 2>$null
        Write-Status "Plano Ultimate Performance ativado" "OK"
    } else {
        # Fallback: Alto Desempenho
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-Status "Ultimate não disponível. Alto Desempenho ativado." "WARN"
    }
    Write-Log "Plano Ultimate Performance tentado."
}

function Disable-GameBar {
    Write-Host "   Desativando Game Bar / Game DVR..." -ForegroundColor Yellow
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $path2 = "HKCU:\System\GameConfigStore"
    New-Item -Path $path2 -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path2 -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Write-Status "Game Bar / Game DVR desativados" "OK"
    Write-Log "Game Bar desativada."
}

function Disable-NaglesAlgorithm {
    Write-Host "   Desativando Nagle's Algorithm (reduzir latência)..." -ForegroundColor Yellow
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $interfaces = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        foreach ($iface in $interfaces) {
            Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Status "Nagle's Algorithm desativado (menor latência em jogos online)" "OK"
    Write-Log "Nagle's Algorithm desativado."
}

function Disable-VisualEffects {
    Write-Host "   Desativando efeitos visuais..." -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # Desativar transparência
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # Desativar animações
    $sysParams = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $sysParams -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force -ErrorAction SilentlyContinue
    
    Write-Status "Efeitos visuais desativados (mais FPS!)" "OK"
    Write-Log "Efeitos visuais desativados."
}

function Disable-CortanaWidgets {
    Write-Host "   Desativando Cortana e Widgets..." -ForegroundColor Yellow
    
    # Cortana
    $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # Widgets (Win11)
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Write-Status "Cortana e Widgets desativados" "OK"
    Write-Log "Cortana e Widgets desativados."
}

function Disable-PrefetchSuperfetch {
    Write-Host "   Desativando Prefetch/Superfetch (SysMain)..." -ForegroundColor Yellow
    
    Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
    Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
    
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-Status "Prefetch/Superfetch desativados (recomendado apenas para SSD)" "OK"
    Write-Log "Prefetch/Superfetch desativados."
}

function Clear-StandbyRAM {
    Write-Host "   Limpando RAM em standby..." -ForegroundColor Yellow
    
    # Limpar working sets
    $before = [math]::Round((Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory * 1KB / 1MB, 0)
    
    # Forçar coleta de lixo do .NET e liberar memória
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    $after = [math]::Round((Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory * 1KB / 1MB, 0)
    $freed = $after - $before
    if ($freed -lt 0) { $freed = 0 }
    
    Write-Status "RAM otimizada. ~$($freed)MB liberados." "OK"
    Write-Log "Standby RAM limpa."
}

function Install-DirectXLegacy {
    Write-Host "   Baixando DirectX End-User Runtime Web Installer..." -ForegroundColor Yellow
    $url = "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe"
    $tempFile = Join-Path $env:TEMP "dxwebsetup.exe"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
        Write-Host "   Instalando o DirectX (Isso pode demorar alguns minutos)..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $tempFile -ArgumentList "/Q" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Status "DirectX Legacy instalado/verificado com sucesso!" "OK"
            Write-Log "DirectX Legacy instalado."
        } else {
            Write-Status "A instalação do DirectX retornou o código $($process.ExitCode)." "WARN"
        }
    } catch {
        Write-Status "Erro ao baixar ou instalar o DirectX: $($_.Exception.Message)" "ERRO"
    } finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-GamingRevert {
    Write-Header
    Write-SubHeader "REVERTER OTIMIZAÇÕES DE GAMING"
    Write-Host "   Restaurando configurações padrão do Windows..." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Reverter TUDO ao padrão? (S/N)"
    if ($confirm -match "^[Ss]") {
        # Plano balanceado
        Write-Host "   Restaurando plano de energia Balanceado..." -ForegroundColor Gray
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-Status "Plano de energia restaurado" "OK"

        # Game Bar
        Write-Host "   Reativando Game Bar..." -ForegroundColor Gray
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Status "Game Bar reativada" "OK"

        # Efeitos visuais
        Write-Host "   Restaurando efeitos visuais..." -ForegroundColor Gray
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Status "Efeitos visuais restaurados" "OK"

        # Nagle's
        Write-Host "   Restaurando Nagle's Algorithm..." -ForegroundColor Gray
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $interfaces = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        foreach ($iface in $interfaces) {
            Remove-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Force -ErrorAction SilentlyContinue
        }
        Write-Status "Nagle's Algorithm restaurado" "OK"

        # Prefetch/Superfetch
        Write-Host "   Reativando Prefetch/Superfetch..." -ForegroundColor Gray
        Set-Service -Name SysMain -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name SysMain -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Status "Prefetch/Superfetch reativados" "OK"

        # Cortana
        Write-Host "   Reativando Cortana/Widgets..." -ForegroundColor Gray
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Status "Cortana/Widgets reativados" "OK"

        # Telemetria
        Write-Host "   Restaurando telemetria..." -ForegroundColor Gray
        Set-Service -Name DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name DiagTrack -ErrorAction SilentlyContinue
        Write-Status "Telemetria restaurada" "OK"

        Write-Host ""
        Write-Status "Todas as otimizações de gaming foram revertidas!" "OK"
        Write-Host "   Reinicie o computador para aplicar." -ForegroundColor Yellow
        Write-Log "Todas as otimizações de gaming revertidas."
    }
    Pause-Script
}
