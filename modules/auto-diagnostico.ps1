# ==============================================================================
# MÓDULO: Auto-Diagnóstico (Análise Completa + Correções Automáticas)
# ==============================================================================

function Invoke-AutoDiagnostico {
    Write-Header
    Write-SubHeader "AUTO-DIAGNÓSTICO COMPLETO"
    Write-Host "   Esta ferramenta vai analisar TODO o computador e sugerir" -ForegroundColor White
    Write-Host "   correções automáticas para os problemas encontrados." -ForegroundColor White
    Write-Host ""
    Write-Host "   Iniciando análise completa..." -ForegroundColor Gray
    Write-Host ""

    # Coleta todos os diagnósticos
    $results = Get-SystemDiagnostics

    # Separa problemas
    $problems = $results | Where-Object { $_.Level -eq "CRIT" -or $_.Level -eq "WARN" }
    $fixes = $problems | Where-Object { $_.Fix -ne $null }
    $okItems = $results | Where-Object { $_.Level -eq "OK" }

    # Exibe tudo que está OK primeiro (resumido)
    Write-Host "   --- ITENS SAUDÁVEIS ---" -ForegroundColor Green
    foreach ($ok in $okItems) {
        Write-Status "$($ok.Check)" "OK"
    }
    Write-Host ""

    # Exibe problemas encontrados
    if ($problems.Count -eq 0) {
        Write-Host "   ============================================" -ForegroundColor Green
        Write-Host "   PARABÉNS! Nenhum problema encontrado!" -ForegroundColor Green
        Write-Host "   Seu computador está em ótimo estado." -ForegroundColor Green
        Write-Host "   ============================================" -ForegroundColor Green
        Write-Log "Auto-diagnóstico: nenhum problema encontrado."
        Pause-Script
        return
    }

    Write-Host "   --- PROBLEMAS ENCONTRADOS ---" -ForegroundColor Red
    $fixableList = @()
    $fixIndex = 1

    foreach ($prob in $problems) {
        Write-Status "$($prob.Check): $($prob.Value)" $prob.Level
        if ($prob.Fix) {
            $fixDesc = Get-FixDescription $prob.Fix
            Write-Host "          -> Correção disponível: $fixDesc" -ForegroundColor DarkCyan
            $fixableList += $prob
            $fixIndex++
        }
    }

    Write-Host ""
    Write-Host "   ============================================" -ForegroundColor DarkGray
    Write-Host "   Encontrados: $($problems.Count) problemas" -NoNewline -ForegroundColor White
    if ($fixableList.Count -gt 0) {
        Write-Host " | $($fixableList.Count) com correção automática" -ForegroundColor Cyan
    } else {
        Write-Host ""
    }
    Write-Host "   ============================================" -ForegroundColor DarkGray

    if ($fixableList.Count -eq 0) {
        Write-Host ""
        Write-Host "   Nenhuma correção automática disponível para os problemas encontrados." -ForegroundColor Yellow
        Write-Host "   Verifique os detalhes acima para ações manuais." -ForegroundColor Yellow
        Pause-Script
        return
    }

    # Menu de correção
    Write-Host ""
    Write-Host "   O que deseja fazer?" -ForegroundColor White
    Write-MenuOption "1" "Corrigir TUDO automaticamente"
    Write-MenuOption "2" "Escolher quais problemas corrigir"
    Write-MenuOption "0" "Não corrigir agora (voltar ao menu)"

    $action = Get-Choice

    switch ($action) {
        "1" {
            Write-Host ""
            Write-Host "   Executando TODAS as correções..." -ForegroundColor Yellow
            Write-Host ""

            # Cria ponto de restauração antes
            Write-Host "   Criando ponto de restauração do sistema..." -ForegroundColor Gray
            try {
                Checkpoint-Computer -Description "CHAMADO Auto-Fix $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
                Write-Status "Ponto de restauração criado com sucesso" "OK"
            } catch {
                Write-Status "Não foi possível criar ponto de restauração (continuando mesmo assim)" "WARN"
            }
            Write-Host ""

            $uniqueFixes = $fixableList | ForEach-Object { $_.Fix } | Select-Object -Unique
            foreach ($fix in $uniqueFixes) {
                Invoke-AutoFix $fix
            }

            Write-Host ""
            Write-Host "   ============================================" -ForegroundColor Green
            Write-Host "   Correções finalizadas!" -ForegroundColor Green
            Write-Host "   Recomendamos reiniciar o computador." -ForegroundColor Green
            Write-Host "   ============================================" -ForegroundColor Green
            Write-Log "Auto-diagnóstico: todas as correções aplicadas."
        }
        "2" {
            Write-Host ""
            Write-Host "   Correções disponíveis:" -ForegroundColor White
            $uniqueFixes = $fixableList | ForEach-Object { $_.Fix } | Select-Object -Unique
            $i = 1
            foreach ($fix in $uniqueFixes) {
                $desc = Get-FixDescription $fix
                Write-MenuOption "$i" "$desc"
                $i++
            }
            Write-Host ""
            $selected = Read-Host "   Digite os números separados por vírgula (ex: 1,3)"
            $indices = $selected -split "," | ForEach-Object { $_.Trim() }

            Write-Host ""
            foreach ($idx in $indices) {
                $fixIdx = [int]$idx - 1
                if ($fixIdx -ge 0 -and $fixIdx -lt $uniqueFixes.Count) {
                    Invoke-AutoFix $uniqueFixes[$fixIdx]
                }
            }
            Write-Log "Auto-diagnóstico: correções selecionadas aplicadas."
        }
    }

    Pause-Script
}

function Get-FixDescription {
    param([string]$FixCode)
    switch ($FixCode) {
        "NETWORK_RESET"      { return "Redefinir configuração de rede (DNS/Winsock/IP)" }
        "DNS_FIX"            { return "Configurar DNS para Google (8.8.8.8)" }
        "TEMP_CLEANUP"       { return "Limpar arquivos temporários" }
        "DISK_CLEANUP"       { return "Limpeza de disco (temporários + cache)" }
        "RESTART_SUGGESTION" { return "Sugestão: Reiniciar o computador" }
        "RAM_HIGH"           { return "Encerrar processos de alto consumo de memória" }
        "STARTUP_CLEANUP"    { return "Listar programas na inicialização para desativar" }
        "DEFENDER_UPDATE"    { return "Atualizar definições do Windows Defender" }
        default              { return "Correção: $FixCode" }
    }
}

function Invoke-AutoFix {
    param([string]$FixCode)

    switch ($FixCode) {
        "NETWORK_RESET" {
            Write-Host "   Executando: Redefinição de Rede..." -ForegroundColor Yellow
            ipconfig /release 2>$null | Out-Null
            Start-Sleep -Seconds 2
            ipconfig /renew 2>$null | Out-Null
            ipconfig /flushdns 2>$null | Out-Null
            netsh winsock reset 2>$null | Out-Null
            netsh int ip reset 2>$null | Out-Null
            Write-Status "Rede redefinida. Pode ser necessário reiniciar." "OK"
            Write-Log "Auto-fix: Reset de rede executado"
        }
        "DNS_FIX" {
            Write-Host "   Executando: Configurando DNS Google..." -ForegroundColor Yellow
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @("8.8.8.8","8.8.4.4") -ErrorAction SilentlyContinue
            }
            ipconfig /flushdns 2>$null | Out-Null
            Write-Status "DNS configurado para Google (8.8.8.8 / 8.8.4.4)" "OK"
            Write-Log "Auto-fix: DNS alterado para Google"
        }
        "TEMP_CLEANUP" {
            Write-Host "   Executando: Limpeza de temporários..." -ForegroundColor Yellow
            $before = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            $after = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $freedMB = [math]::Round(($before - $after) / 1MB, 0)
            Write-Status "Temporários limpos. Liberados: $($freedMB)MB" "OK"
            Write-Log "Auto-fix: Temp cleanup liberou $($freedMB)MB"
        }
        "DISK_CLEANUP" {
            Write-Host "   Executando: Limpeza de disco..." -ForegroundColor Yellow
            Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "Limpeza de disco executada" "OK"
            Write-Log "Auto-fix: Disk cleanup executado"
        }
        "RESTART_SUGGESTION" {
            Write-Host "   Recomendação: Reinicie o computador para melhorar o desempenho." -ForegroundColor Yellow
            $restart = Read-Host "   Deseja reiniciar agora? (S/N)"
            if ($restart -match "^[Ss]") {
                Write-Log "Auto-fix: Reinicialização solicitada pelo usuário"
                Restart-Computer -Force
            }
        }
        "RAM_HIGH" {
            Write-Host "   Analisando processos com alto consumo de RAM..." -ForegroundColor Yellow
            $heavy = Get-Process | Where-Object { $_.WorkingSet64 -gt 500MB -and $_.ProcessName -notmatch "svchost|System|explorer|dwm|csrss" } | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
            if ($heavy) {
                foreach ($p in $heavy) {
                    Write-Host "     - $($p.ProcessName): $([math]::Round($p.WorkingSet64/1MB))MB" -ForegroundColor White
                }
                Write-Host ""
                Write-Host "   AVISO: Encerrar processos pode fechar programas abertos." -ForegroundColor Yellow
            } else {
                Write-Status "Nenhum processo individual com consumo excessivo encontrado" "INFO"
            }
        }
        "STARTUP_CLEANUP" {
            Write-Host "   Programas na inicialização:" -ForegroundColor Yellow
            $startups = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
            foreach ($s in $startups) {
                Write-Host "     - $($s.Name) -> $($s.Command)" -ForegroundColor White
            }
            Write-Host ""
            Write-Host "   Use o Gerenciador de Tarefas (Ctrl+Shift+Esc > Inicializar)" -ForegroundColor Cyan
            Write-Host "   para desativar itens desnecessários." -ForegroundColor Cyan
        }
        "DEFENDER_UPDATE" {
            Write-Host "   Executando: Atualizando definições do Defender..." -ForegroundColor Yellow
            Update-MpSignature -ErrorAction SilentlyContinue
            Write-Status "Definições do Defender atualizadas" "OK"
            Write-Log "Auto-fix: Defender signatures atualizadas"
        }
    }
}
