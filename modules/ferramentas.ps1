# ==============================================================================
# MÓDULO: Ferramentas do Técnico (Atalhos Rápidos)
# ==============================================================================

function Invoke-MenuFerramentas {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "FERRAMENTAS DO TÉCNICO - ATALHOS RÁPIDOS"

        Write-Host "   --- Painel & Configurações ---" -ForegroundColor DarkGray
        Write-MenuOption "1"  "Painel de Controle"
        Write-MenuOption "2"  "Conexões de Rede (ncpa.cpl)"
        Write-MenuOption "3"  "Gerenciador de Dispositivos"
        Write-MenuOption "4"  "Gerenciador de Discos"
        Write-MenuOption "5"  "Programas e Recursos"
        Write-Host ""
        Write-Host "   --- Ferramentas Avançadas ---" -ForegroundColor DarkGray
        Write-MenuOption "6"  "Editor de Registro (regedit)"
        Write-MenuOption "7"  "Serviços do Windows"
        Write-MenuOption "8"  "Visualizador de Eventos"
        Write-MenuOption "9"  "Agendador de Tarefas"
        Write-MenuOption "10" "Gerenciador de Tarefas"
        Write-Host ""
        Write-Host "   --- Monitoramento ---" -ForegroundColor DarkGray
        Write-MenuOption "11" "Monitor de Recursos"
        Write-MenuOption "12" "Informações do Sistema (msinfo32)"
        Write-Host ""
        Write-Host "   --- Relatórios ---" -ForegroundColor DarkGray
        Write-MenuOption "13" "Gerar Relatório de Bateria (HTML)"
        Write-MenuOption "14" "Gerar Relatório de Energia (HTML)"
        Write-MenuOption "15" "Verificar Ativação do Windows"
        Write-Host ""
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1"  { Start-Process control; Write-Log "Aberto: Painel de Controle" }
            "2"  { Start-Process ncpa.cpl; Write-Log "Aberto: ncpa.cpl" }
            "3"  { Start-Process devmgmt.msc; Write-Log "Aberto: devmgmt.msc" }
            "4"  { Start-Process diskmgmt.msc; Write-Log "Aberto: diskmgmt.msc" }
            "5"  { Start-Process appwiz.cpl; Write-Log "Aberto: appwiz.cpl" }
            "6"  { Start-Process regedit; Write-Log "Aberto: regedit" }
            "7"  { Start-Process services.msc; Write-Log "Aberto: services.msc" }
            "8"  { Start-Process eventvwr.msc; Write-Log "Aberto: eventvwr.msc" }
            "9"  { Start-Process taskschd.msc; Write-Log "Aberto: taskschd.msc" }
            "10" { Start-Process taskmgr; Write-Log "Aberto: taskmgr" }
            "11" { Start-Process resmon; Write-Log "Aberto: resmon" }
            "12" { Start-Process msinfo32; Write-Log "Aberto: msinfo32" }
            "13" { Generate-BatteryReport }
            "14" { Generate-EnergyReport }
            "15" { Check-WindowsActivation }
            "0"  { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Generate-BatteryReport {
    Write-Header
    Write-SubHeader "RELATÓRIO DE BATERIA"

    $reportPath = Join-Path $env:USERPROFILE "Desktop\CHAMADO_battery_report.html"
    Write-Host "   Gerando relatório de bateria..." -ForegroundColor Yellow
    $result = Start-Process powercfg -ArgumentList "/batteryreport /output `"$reportPath`"" -Wait -NoNewWindow -PassThru

    if (Test-Path $reportPath) {
        Write-Status "Relatório salvo na Área de Trabalho: CHAMADO_battery_report.html" "OK"
        $open = Read-Host "   Abrir no navegador? (S/N)"
        if ($open -match "^[Ss]") {
            Start-Process $reportPath
        }
    } else {
        Write-Status "Não foi possível gerar o relatório (sem bateria?)" "WARN"
    }
    Write-Log "Relatório de bateria gerado."
    Pause-Script
}

function Generate-EnergyReport {
    Write-Header
    Write-SubHeader "RELATÓRIO DE ENERGIA"

    Write-Host "   Monitorando consumo de energia por 60 segundos..." -ForegroundColor Yellow
    Write-Host "   Não mexa no computador durante a análise." -ForegroundColor Gray
    Write-Host ""

    $reportDir = Join-Path $env:USERPROFILE "Desktop"
    $result = Start-Process powercfg -ArgumentList "/energy /output `"$reportDir\CHAMADO_energy_report.html`" /duration 60" -Wait -NoNewWindow -PassThru

    $reportPath = Join-Path $reportDir "CHAMADO_energy_report.html"
    if (Test-Path $reportPath) {
        Write-Status "Relatório salvo na Área de Trabalho: CHAMADO_energy_report.html" "OK"
        $open = Read-Host "   Abrir no navegador? (S/N)"
        if ($open -match "^[Ss]") {
            Start-Process $reportPath
        }
    } else {
        Write-Status "Erro ao gerar relatório de energia." "ERRO"
    }
    Write-Log "Relatório de energia gerado."
    Pause-Script
}

function Check-WindowsActivation {
    Write-Header
    Write-SubHeader "VERIFICAR ATIVAÇÃO DO WINDOWS"

    Write-Host "   Consultando status de ativação..." -ForegroundColor Yellow
    Write-Host ""

    $license = cscript //nologo "$env:WINDIR\System32\slmgr.vbs" /xpr 2>$null
    $detail  = cscript //nologo "$env:WINDIR\System32\slmgr.vbs" /dli 2>$null

    if ($license) {
        foreach ($line in $license) {
            if ($line.Trim()) {
                Write-Host "   $line" -ForegroundColor White
            }
        }
    }

    Write-Host ""
    if ($detail) {
        foreach ($line in $detail) {
            if ($line.Trim()) {
                Write-Host "   $line" -ForegroundColor Gray
            }
        }
    }

    Write-Log "Verificação de ativação do Windows executada."
    Pause-Script
}
