# ==============================================================================
# MÓDULO: Ferramentas de Rede
# ==============================================================================

function Invoke-MenuRede {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "FERRAMENTAS DE REDE"

        Write-MenuOption "1"  "Informacoes de Rede Completas"
        Write-MenuOption "2"  "Testar Conectividade (Ping Google)"
        Write-MenuOption "3"  "Ping Customizado"
        Write-MenuOption "4"  "Traceroute (Rastrear Rota)"
        Write-MenuOption "5"  "Redefinir Rede Completa"
        Write-MenuOption "6"  "Alterar DNS (Google / Cloudflare / OpenDNS)"
        Write-MenuOption "7"  "Restaurar DNS Automatico (DHCP)"
        Write-MenuOption "8"  "Verificar Portas em Uso"
        Write-MenuOption "9"  "Listar Redes Wi-Fi Salvas (com Senhas)"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Show-NetworkInfo }
            "2" { Test-InternetConnection }
            "3" { Test-CustomPing }
            "4" { Invoke-Traceroute }
            "5" { Reset-Network }
            "6" { Set-CustomDNS }
            "7" { Restore-AutoDNS }
            "8" { Show-OpenPorts }
            "9" { Show-SavedWifi }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Show-NetworkInfo {
    Write-Header
    Write-SubHeader "INFORMAÇÕES DE REDE COMPLETAS"

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

    foreach ($adapter in $adapters) {
        $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dns = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ", "
        $gw = (Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop

        Write-Host "   Adaptador: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor $global:ThemeColor
        Write-Host "   Status:    $($adapter.Status)" -ForegroundColor Green
        Write-Host "   Velocidade: $($adapter.LinkSpeed)"
        Write-Host "   MAC:       $($adapter.MacAddress)"
        if ($ipInfo) {
            Write-Host "   IP:        $($ipInfo.IPAddress)/$($ipInfo.PrefixLength)"
        }
        Write-Host "   Gateway:   $gw"
        Write-Host "   DNS:       $dns"
        
        # DHCP info
        $dhcp = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
        if ($dhcp.NetIPv4Interface.Dhcp -eq "Enabled") {
            Write-Host "   DHCP:      Ativado" -ForegroundColor Green
        } else {
            Write-Host "   DHCP:      Desativado (IP Fixo)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if (-not $adapters) {
        Write-Status "Nenhum adaptador de rede ativo encontrado!" "ERRO"
    }

    Write-Log "Informações de rede exibidas."
    Pause-Script
}

function Test-InternetConnection {
    Write-Header
    Write-SubHeader "TESTE DE CONECTIVIDADE"

    $targets = @(
        @{ Host="127.0.0.1"; Name="Loopback (Próprio PC)" },
        @{ Host=$null; Name="Gateway (Roteador)" },
        @{ Host="8.8.8.8"; Name="Google DNS (Internet)" },
        @{ Host="1.1.1.1"; Name="Cloudflare DNS (Internet)" },
        @{ Host="google.com"; Name="google.com (DNS + Internet)" }
    )

    # Detecta gateway
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1
    $targets[1].Host = $gateway

    foreach ($t in $targets) {
        if (-not $t.Host) {
            Write-Status "$($t.Name): Gateway não encontrado" "ERRO"
            continue
        }
        Write-Host "   Testando $($t.Name) ($($t.Host))..." -ForegroundColor Gray -NoNewline
        $result = Test-Connection -ComputerName $t.Host -Count 3 -ErrorAction SilentlyContinue
        if ($result) {
            $avg = [math]::Round(($result | Measure-Object ResponseTime -Average).Average)
            $loss = 3 - $result.Count
            Write-Host "`r" -NoNewline
            if ($avg -gt 100) {
                Write-Status "$($t.Name): $($avg)ms (Latência ALTA!)" "WARN"
            } else {
                Write-Status "$($t.Name): $($avg)ms" "OK"
            }
        } else {
            Write-Host "`r" -NoNewline
            Write-Status "$($t.Name): SEM RESPOSTA" "ERRO"
        }
    }

    Write-Host ""
    Write-Host "   Diagnóstico rápido:" -ForegroundColor $global:ThemeColor
    # Checa onde o problema está
    $loopOk = Test-Connection -ComputerName "127.0.0.1" -Count 1 -Quiet
    $gwOk = if ($gateway) { Test-Connection -ComputerName $gateway -Count 1 -Quiet } else { $false }
    $netOk = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    $dnsOk = (Resolve-DnsName "google.com" -ErrorAction SilentlyContinue) -ne $null

    if (-not $loopOk) {
        Write-Host "   -> Problema na placa de rede ou driver TCP/IP" -ForegroundColor Red
    } elseif (-not $gwOk) {
        Write-Host "   -> PC não alcança o roteador. Verifique cabo/Wi-Fi." -ForegroundColor Red
    } elseif (-not $netOk) {
        Write-Host "   -> Roteador OK, mas sem saída para internet. Problema no provedor ou roteador." -ForegroundColor Yellow
    } elseif (-not $dnsOk) {
        Write-Host "   -> Internet OK, mas DNS não resolve. Troque o DNS (opção 6)." -ForegroundColor Yellow
    } else {
        Write-Host "   -> Tudo funcionando corretamente!" -ForegroundColor Green
    }

    Write-Log "Teste de conectividade executado."
    Pause-Script
}

function Test-CustomPing {
    Write-Header
    Write-SubHeader "PING CUSTOMIZADO"

    $target = Read-Host "   Digite o IP ou hostname"
    $count = Read-Host "   Quantos pacotes? (Padrão: 4)"
    if (-not $count) { $count = 4 }

    Write-Host ""
    Write-Host "   Executando ping para $target ($count pacotes)..." -ForegroundColor Yellow
    Write-Host ""

    ping $target -n $count

    Write-Log "Ping customizado para $target ($count pacotes)."
    Pause-Script
}

function Invoke-Traceroute {
    Write-Header
    Write-SubHeader "TRACEROUTE"

    $target = Read-Host "   Digite o destino (IP ou hostname, padrão: google.com)"
    if (-not $target) { $target = "google.com" }

    Write-Host ""
    Write-Host "   Rastreando rota para $target..." -ForegroundColor Yellow
    Write-Host "   (Pode demorar até 30 segundos)" -ForegroundColor Gray
    Write-Host ""

    tracert $target

    Write-Log "Traceroute para $target executado."
    Pause-Script
}

function Reset-Network {
    Write-Header
    Write-SubHeader "REDEFINIR REDE COMPLETA"

    Write-Host "   Esta ação vai executar:" -ForegroundColor White
    Write-Host "   - ipconfig /release (liberar IP)" -ForegroundColor Gray
    Write-Host "   - ipconfig /renew (renovar IP)" -ForegroundColor Gray
    Write-Host "   - ipconfig /flushdns (limpar cache DNS)" -ForegroundColor Gray
    Write-Host "   - netsh winsock reset (resetar Winsock)" -ForegroundColor Gray
    Write-Host "   - netsh int ip reset (resetar stack TCP/IP)" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   Confirma? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host ""
        Write-Host "   Executando..." -ForegroundColor Yellow

        Write-Host "   [1/5] Liberando IP..." -ForegroundColor Gray
        ipconfig /release 2>$null | Out-Null

        Write-Host "   [2/5] Renovando IP..." -ForegroundColor Gray
        ipconfig /renew 2>$null | Out-Null

        Write-Host "   [3/5] Limpando cache DNS..." -ForegroundColor Gray
        ipconfig /flushdns 2>$null | Out-Null

        Write-Host "   [4/5] Resetando Winsock..." -ForegroundColor Gray
        netsh winsock reset 2>$null | Out-Null

        Write-Host "   [5/5] Resetando TCP/IP..." -ForegroundColor Gray
        netsh int ip reset 2>$null | Out-Null

        Write-Host ""
        Write-Status "Rede redefinida com sucesso!" "OK"
        Write-Host "   Recomendado reiniciar o computador para aplicar todas as mudanças." -ForegroundColor Yellow

        Write-Log "Reset completo de rede executado."
    }
    Pause-Script
}

function Set-CustomDNS {
    Write-Header
    Write-SubHeader "ALTERAR DNS"

    Write-MenuOption "1" "Google DNS (8.8.8.8 / 8.8.4.4)"
    Write-MenuOption "2" "Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    Write-MenuOption "3" "OpenDNS (208.67.222.222 / 208.67.220.220)"
    Write-MenuOption "4" "DNS customizado"
    Write-MenuOption "0" "Cancelar"

    $op = Get-Choice
    $primary = $null; $secondary = $null; $name = ""

    switch ($op) {
        "1" { $primary = "8.8.8.8"; $secondary = "8.8.4.4"; $name = "Google" }
        "2" { $primary = "1.1.1.1"; $secondary = "1.0.0.1"; $name = "Cloudflare" }
        "3" { $primary = "208.67.222.222"; $secondary = "208.67.220.220"; $name = "OpenDNS" }
        "4" {
            $primary = Read-Host "   DNS Primário"
            $secondary = Read-Host "   DNS Secundário"
            $name = "Custom"
        }
        "0" { return }
    }

    if ($primary) {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($primary, $secondary) -ErrorAction SilentlyContinue
        }
        ipconfig /flushdns 2>$null | Out-Null
        Write-Host ""
        Write-Status "DNS alterado para $name ($primary / $secondary)" "OK"
        Write-Log "DNS alterado para $name ($primary / $secondary)"
    }
    Pause-Script
}

function Restore-AutoDNS {
    Write-Header
    Write-SubHeader "RESTAURAR DNS AUTOMÁTICO"

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    }
    ipconfig /flushdns 2>$null | Out-Null
    Write-Status "DNS restaurado para automático (DHCP)" "OK"
    Write-Log "DNS restaurado para automático."
    Pause-Script
}

function Show-OpenPorts {
    Write-Header
    Write-SubHeader "PORTAS EM USO (LISTENING)"

    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Sort-Object LocalPort | Select-Object -First 25

    Write-Host "   Porta    PID     Processo" -ForegroundColor $global:ThemeColor
    Write-Host "   ------   -----   --------" -ForegroundColor DarkGray

    foreach ($conn in $connections) {
        $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        $procName = if ($proc) { $proc.ProcessName } else { "N/A" }
        $port = $conn.LocalPort.ToString().PadRight(8)
        $pid = $conn.OwningProcess.ToString().PadRight(7)
        Write-Host "   $port $pid $procName"
    }

    Write-Host ""
    Write-Host "   (Mostrando as 25 primeiras portas)" -ForegroundColor DarkGray
    Write-Log "Portas em uso exibidas."
    Pause-Script
}

function Show-SavedWifi {
    Write-Header
    Write-SubHeader "REDES WI-FI SALVAS"

    $profiles = netsh wlan show profiles 2>$null
    
    # Captura os nomes através de regex para evitar problemas com acentos e idiomas diferentes.
    # O formato de saída do netsh sempre tem espaços seguidos de " : " e depois o nome da rede.
    $names = @()
    foreach ($line in $profiles) {
        if ($line -match "\s+:\s+(.+)$") {
            $names += $Matches[1].Trim()
        }
    }

    if (-not $names -or $names.Count -eq 0) {
        Write-Status "Nenhuma rede Wi-Fi salva encontrada." "INFO"
        Pause-Script
        return
    }

    Write-Host "   Rede                              Senha" -ForegroundColor $global:ThemeColor
    Write-Host "   --------------------------------  --------------------------------" -ForegroundColor DarkGray

    $reportLines = @()
    $reportLines += "CHAMADO - Relatório de Redes Wi-Fi"
    $reportLines += "Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $reportLines += "------------------------------------------------------------------"
    $reportLines += "Rede                              Senha"
    $reportLines += "--------------------------------  --------------------------------"

    foreach ($name in $names) {
        $detail = netsh wlan show profile name="$name" key=clear 2>$null
        $keyLine = $detail | Select-String "Conte.do da Chave|Key Content"
        $key = if ($keyLine) { ($keyLine -split ":")[-1].Trim() } else { "(sem senha / protegida)" }
        $displayName = $name.PadRight(34)
        Write-Host "   $displayName$key"
        $reportLines += "$displayName$key"
    }

    $reportPath = Join-Path $global:DataDir "wifi_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $reportLines | Set-Content -Path $reportPath -Encoding UTF8 -Force

    Write-Host ""
    Write-Host "   Total: $($names.Count) redes salvas" -ForegroundColor DarkGray
    Write-Status "Relatório salvo em: data\$(Split-Path $reportPath -Leaf)" "OK"
    Write-Log "Redes Wi-Fi salvas listadas. Relatório gerado: $reportPath"
    Pause-Script
}
