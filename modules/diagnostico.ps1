# ==============================================================================
# MÓDULO: Diagnóstico Detalhado do Sistema
# ==============================================================================

function Get-SystemDiagnostics {
    <#
    .SYNOPSIS
        Coleta diagnósticos completos do sistema e retorna um array de resultados.
        Usado tanto pelo Diagnóstico Detalhado quanto pelo Auto-Diagnóstico.
    #>
    $results = @()

    # --- SISTEMA OPERACIONAL ---
    $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
    $comp = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue
    $gpu = Get-WmiObject -Class Win32_VideoController -ErrorAction SilentlyContinue
    $bios = Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue

    $results += @{ Category="SISTEMA"; Check="Sistema Operacional"; Value="$($os.Caption) Build $($os.BuildNumber)"; Level="INFO"; Fix=$null }
    $results += @{ Category="SISTEMA"; Check="Processador"; Value="$($cpu.Name)"; Level="INFO"; Fix=$null }
    $results += @{ Category="SISTEMA"; Check="GPU"; Value="$($gpu.Name -join ', ')"; Level="INFO"; Fix=$null }
    $results += @{ Category="SISTEMA"; Check="Fabricante/Modelo"; Value="$($comp.Manufacturer) $($comp.Model)"; Level="INFO"; Fix=$null }
    $results += @{ Category="SISTEMA"; Check="Service Tag"; Value="$($bios.SerialNumber)"; Level="INFO"; Fix=$null }

    # --- LICENÇA WINDOWS ---
    $license = (cscript //nologo "$env:WINDIR\System32\slmgr.vbs" /xpr 2>$null) -join " "
    if ($license -match "permanente|permanent") {
        $results += @{ Category="SISTEMA"; Check="Licença do Windows"; Value="Ativado permanentemente"; Level="OK"; Fix=$null }
    } else {
        $results += @{ Category="SISTEMA"; Check="Licença do Windows"; Value="Pode não estar ativado"; Level="WARN"; Fix=$null }
    }

    # --- UPTIME ---
    $uptime = (New-TimeSpan -Start $os.ConvertToDateTime($os.LastBootUpTime) -End (Get-Date)).TotalDays
    $uptimeRound = [math]::Round($uptime, 1)
    if ($uptimeRound -gt 15) {
        $results += @{ Category="DESEMPENHO"; Check="Uptime do Sistema"; Value="$uptimeRound dias sem reiniciar"; Level="WARN"; Fix="RESTART_SUGGESTION" }
    } elseif ($uptimeRound -gt 7) {
        $results += @{ Category="DESEMPENHO"; Check="Uptime do Sistema"; Value="$uptimeRound dias"; Level="WARN"; Fix="RESTART_SUGGESTION" }
    } else {
        $results += @{ Category="DESEMPENHO"; Check="Uptime do Sistema"; Value="$uptimeRound dias"; Level="OK"; Fix=$null }
    }

    # --- RAM ---
    $totalRAM = [math]::Round($comp.TotalPhysicalMemory / 1GB, 2)
    $freeRAM = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $ramPercent = [math]::Round(($freeRAM / $totalRAM) * 100)

    if ($ramPercent -lt 15) {
        $results += @{ Category="DESEMPENHO"; Check="Memória RAM"; Value="$($usedRAM)GB usada de $($totalRAM)GB ($($ramPercent)% livre)"; Level="CRIT"; Fix="RAM_HIGH" }
    } elseif ($ramPercent -lt 30) {
        $results += @{ Category="DESEMPENHO"; Check="Memória RAM"; Value="$($usedRAM)GB usada de $($totalRAM)GB ($($ramPercent)% livre)"; Level="WARN"; Fix=$null }
    } else {
        $results += @{ Category="DESEMPENHO"; Check="Memória RAM"; Value="$($usedRAM)GB usada de $($totalRAM)GB ($($ramPercent)% livre)"; Level="OK"; Fix=$null }
    }

    # --- DISCOS ---
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    foreach ($d in $disks) {
        $freeGB = [math]::Round($d.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($d.Size / 1GB, 2)
        $freePerc = [math]::Round(($freeGB / $totalGB) * 100)
        $drive = $d.DeviceID

        if ($freePerc -lt 10) {
            $results += @{ Category="DISCO"; Check="Espaço em $drive"; Value="$($freeGB)GB livre de $($totalGB)GB ($($freePerc)%)"; Level="CRIT"; Fix="DISK_CLEANUP" }
        } elseif ($freePerc -lt 20) {
            $results += @{ Category="DISCO"; Check="Espaço em $drive"; Value="$($freeGB)GB livre de $($totalGB)GB ($($freePerc)%)"; Level="WARN"; Fix="DISK_CLEANUP" }
        } else {
            $results += @{ Category="DISCO"; Check="Espaço em $drive"; Value="$($freeGB)GB livre de $($totalGB)GB ($($freePerc)%)"; Level="OK"; Fix=$null }
        }
    }

    # --- SMART STATUS DO HD ---
    $smartDisks = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
    if ($smartDisks) {
        foreach ($sd in $smartDisks) {
            if ($sd.PredictFailure) {
                $results += @{ Category="DISCO"; Check="SMART Status"; Value="FALHA PREVISTA! Faça backup imediatamente!"; Level="CRIT"; Fix=$null }
            } else {
                $results += @{ Category="DISCO"; Check="SMART Status"; Value="Saudável"; Level="OK"; Fix=$null }
            }
        }
    }

    # --- BATERIA (se notebook) ---
    $battery = Get-WmiObject Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $charge = $battery.EstimatedChargeRemaining
        $status = switch ($battery.BatteryStatus) {
            1 { "Descarregando" }
            2 { "Carregando" }
            3 { "Totalmente carregada" }
            default { "Desconhecido" }
        }
        $results += @{ Category="HARDWARE"; Check="Bateria"; Value="$($charge)% - $status"; Level="INFO"; Fix=$null }
    }

    # --- TOP 5 PROCESSOS CPU ---
    $topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
        "$($_.ProcessName): $([math]::Round($_.CPU, 1))s CPU / $([math]::Round($_.WorkingSet64/1MB))MB RAM"
    }
    $results += @{ Category="DESEMPENHO"; Check="Top 5 Processos (CPU)"; Value=($topCPU -join " | "); Level="INFO"; Fix=$null }

    # --- PROGRAMAS NA INICIALIZAÇÃO ---
    $startups = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    $startupCount = ($startups | Measure-Object).Count
    if ($startupCount -gt 10) {
        $results += @{ Category="DESEMPENHO"; Check="Programas na Inicialização"; Value="$startupCount programas (pode causar lentidão no boot)"; Level="WARN"; Fix="STARTUP_CLEANUP" }
    } else {
        $results += @{ Category="DESEMPENHO"; Check="Programas na Inicialização"; Value="$startupCount programas"; Level="OK"; Fix=$null }
    }

    # --- REDE ---
    $pingTest = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($pingTest) {
        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 2 -ErrorAction SilentlyContinue
        $avgLatency = [math]::Round(($pingResult | Measure-Object ResponseTime -Average).Average)
        if ($avgLatency -gt 100) {
            $results += @{ Category="REDE"; Check="Conectividade (Internet)"; Value="Online - Latência alta: $($avgLatency)ms"; Level="WARN"; Fix="NETWORK_RESET" }
        } else {
            $results += @{ Category="REDE"; Check="Conectividade (Internet)"; Value="Online - Latência: $($avgLatency)ms"; Level="OK"; Fix=$null }
        }
    } else {
        $results += @{ Category="REDE"; Check="Conectividade (Internet)"; Value="SEM CONEXÃO COM A INTERNET"; Level="CRIT"; Fix="NETWORK_RESET" }
    }

    # --- DNS ---
    $dnsTest = Resolve-DnsName "google.com" -ErrorAction SilentlyContinue
    if ($dnsTest) {
        $results += @{ Category="REDE"; Check="Resolução DNS"; Value="Funcionando"; Level="OK"; Fix=$null }
    } else {
        $results += @{ Category="REDE"; Check="Resolução DNS"; Value="FALHA na resolução de nomes"; Level="CRIT"; Fix="DNS_FIX" }
    }

    # --- GATEWAY ---
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1
    if ($gateway) {
        $gwPing = Test-Connection -ComputerName $gateway -Count 1 -Quiet
        if ($gwPing) {
            $results += @{ Category="REDE"; Check="Gateway ($gateway)"; Value="Acessível"; Level="OK"; Fix=$null }
        } else {
            $results += @{ Category="REDE"; Check="Gateway ($gateway)"; Value="NÃO RESPONDE ao ping"; Level="CRIT"; Fix="NETWORK_RESET" }
        }
    } else {
        $results += @{ Category="REDE"; Check="Gateway"; Value="Nenhum gateway configurado!"; Level="CRIT"; Fix="NETWORK_RESET" }
    }

    # --- IP OBTIDO ---
    $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -ne "127.0.0.1" }
    if ($ipv4) {
        foreach ($ip in $ipv4) {
            if ($ip.IPAddress -match "^169\.254") {
                $results += @{ Category="REDE"; Check="IP ($($ip.InterfaceAlias))"; Value="$($ip.IPAddress) - IP APIPA (sem DHCP!)"; Level="CRIT"; Fix="NETWORK_RESET" }
            } else {
                $results += @{ Category="REDE"; Check="IP ($($ip.InterfaceAlias))"; Value="$($ip.IPAddress)/$($ip.PrefixLength)"; Level="OK"; Fix=$null }
            }
        }
    } else {
        $results += @{ Category="REDE"; Check="Endereço IP"; Value="Nenhum IP atribuído!"; Level="CRIT"; Fix="NETWORK_RESET" }
    }

    # --- SEGURANÇA: DEFENDER ---
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defender) {
        if ($defender.RealTimeProtectionEnabled) {
            $results += @{ Category="SEGURANÇA"; Check="Windows Defender (Real-Time)"; Value="Ativado"; Level="OK"; Fix=$null }
        } else {
            $results += @{ Category="SEGURANÇA"; Check="Windows Defender (Real-Time)"; Value="DESATIVADO!"; Level="CRIT"; Fix=$null }
        }
        $lastUpdate = $defender.AntivirusSignatureLastUpdated
        $daysSinceUpdate = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).Days
        if ($daysSinceUpdate -gt 7) {
            $results += @{ Category="SEGURANÇA"; Check="Definições do Antivírus"; Value="Atualizado há $daysSinceUpdate dias"; Level="WARN"; Fix="DEFENDER_UPDATE" }
        } else {
            $results += @{ Category="SEGURANÇA"; Check="Definições do Antivírus"; Value="Atualizado (há $daysSinceUpdate dias)"; Level="OK"; Fix=$null }
        }
    }

    # --- FIREWALL ---
    $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    $fwOff = $fw | Where-Object { $_.Enabled -eq $false }
    if ($fwOff) {
        $profiles = ($fwOff.Name -join ", ")
        $results += @{ Category="SEGURANÇA"; Check="Firewall do Windows"; Value="DESATIVADO nos perfis: $profiles"; Level="WARN"; Fix=$null }
    } else {
        $results += @{ Category="SEGURANÇA"; Check="Firewall do Windows"; Value="Ativo em todos os perfis"; Level="OK"; Fix=$null }
    }

    # --- WINDOWS UPDATE ---
    $lastHotfix = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($lastHotfix -and $lastHotfix.InstalledOn) {
        $daysSinceHotfix = (New-TimeSpan -Start $lastHotfix.InstalledOn -End (Get-Date)).Days
        if ($daysSinceHotfix -gt 60) {
            $results += @{ Category="SISTEMA"; Check="Último Windows Update"; Value="Há $daysSinceHotfix dias ($($lastHotfix.HotFixID))"; Level="WARN"; Fix=$null }
        } else {
            $results += @{ Category="SISTEMA"; Check="Último Windows Update"; Value="Há $daysSinceHotfix dias ($($lastHotfix.HotFixID))"; Level="OK"; Fix=$null }
        }
    }

    # --- TEMP SIZE ---
    $tempSize = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $tempGB = [math]::Round($tempSize / 1GB, 2)
    $tempMB = [math]::Round($tempSize / 1MB, 0)
    if ($tempMB -gt 500) {
        $results += @{ Category="LIMPEZA"; Check="Pasta Temporária do Usuário"; Value="$($tempMB)MB de lixo acumulado"; Level="WARN"; Fix="TEMP_CLEANUP" }
    } else {
        $results += @{ Category="LIMPEZA"; Check="Pasta Temporária do Usuário"; Value="$($tempMB)MB"; Level="OK"; Fix=$null }
    }

    $winTempSize = (Get-ChildItem "$env:WINDIR\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $winTempMB = [math]::Round($winTempSize / 1MB, 0)
    if ($winTempMB -gt 500) {
        $results += @{ Category="LIMPEZA"; Check="Pasta Temp do Windows"; Value="$($winTempMB)MB de lixo acumulado"; Level="WARN"; Fix="TEMP_CLEANUP" }
    } else {
        $results += @{ Category="LIMPEZA"; Check="Pasta Temp do Windows"; Value="$($winTempMB)MB"; Level="OK"; Fix=$null }
    }

    return $results
}

function Invoke-DiagnosticoDetalhado {
    Write-Header
    Write-SubHeader "DIAGNÓSTICO DETALHADO DO SISTEMA"
    Write-Host "   Analisando sistema completo, aguarde..." -ForegroundColor Gray
    Write-Host ""

    $results = Get-SystemDiagnostics

    # Agrupa por categoria
    $categories = $results | ForEach-Object { $_.Category } | Select-Object -Unique

    foreach ($cat in $categories) {
        Write-Host "   --- $cat ---" -ForegroundColor $global:ThemeColor
        $items = $results | Where-Object { $_.Category -eq $cat }
        foreach ($item in $items) {
            Write-Status "$($item.Check): $($item.Value)" $item.Level
        }
        Write-Host ""
    }

    # Resumo
    $critCount = ($results | Where-Object { $_.Level -eq "CRIT" }).Count
    $warnCount = ($results | Where-Object { $_.Level -eq "WARN" }).Count
    $okCount   = ($results | Where-Object { $_.Level -eq "OK" }).Count

    Write-Host "   ======================================" -ForegroundColor DarkGray
    Write-Host "   RESUMO: " -NoNewline -ForegroundColor White
    Write-Host "$okCount OK " -NoNewline -ForegroundColor Green
    Write-Host "| $warnCount Avisos " -NoNewline -ForegroundColor Yellow
    Write-Host "| $critCount Críticos" -ForegroundColor Red
    Write-Host "   ======================================" -ForegroundColor DarkGray

    # Exportar?
    Write-Host ""
    $export = Read-Host "   Exportar relatório para arquivo? (S/N)"
    if ($export -match "^[Ss]") {
        $reportFile = Join-Path $global:LogDir "diagnostico_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $reportContent = "CHAMADO - Relatório de Diagnóstico`nGerado em: $(Get-Date)`n`n"
        foreach ($cat in $categories) {
            $reportContent += "--- $cat ---`n"
            $items = $results | Where-Object { $_.Category -eq $cat }
            foreach ($item in $items) {
                $reportContent += "[$($item.Level)] $($item.Check): $($item.Value)`n"
            }
            $reportContent += "`n"
        }
        Set-Content -Path $reportFile -Value $reportContent -Force
        Write-Status "Relatório salvo em: $reportFile" "OK"
    }

    Write-Log "Diagnóstico detalhado executado. CRIT:$critCount WARN:$warnCount OK:$okCount"
    Pause-Script
}

function Invoke-ColetaRapida {
    Write-Header
    Write-SubHeader "COLETA RÁPIDA - INFORMAÇÕES PARA O CHAMADO"

    $comp = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
    $os   = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue
    $cpu  = Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue
    $gpu  = Get-WmiObject -Class Win32_VideoController -ErrorAction SilentlyContinue
    $ram  = [math]::Round($comp.TotalPhysicalMemory / 1GB, 2)
    $ip   = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -ne "127.0.0.1" }).IPAddress -join ", "
    $mac  = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).MacAddress
    $gw   = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1
    $dns  = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses -join ", "
    $uptime = [math]::Round((New-TimeSpan -Start $os.ConvertToDateTime($os.LastBootUpTime) -End (Get-Date)).TotalHours, 1)

    $info = @"
============================================
CHAMADO - Coleta Rápida de Informações
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm")
============================================
Computador:      $($comp.Name)
Usuário:         $($env:USERNAME)
Fabricante:      $($comp.Manufacturer) - $($comp.Model)
Service Tag:     $($bios.SerialNumber)
Processador:     $($cpu.Name)
GPU:             $($gpu.Name -join ', ')
RAM:             $($ram) GB
SO:              $($os.Caption) ($($os.BuildNumber))
Uptime:          $($uptime) horas
IP:              $($ip)
MAC:             $($mac)
Gateway:         $($gw)
DNS:             $($dns)
============================================
"@

    Write-Host $info -ForegroundColor White
    
    Set-Clipboard -Value $info
    Write-Status "Informações copiadas para a área de transferência!" "OK"

    Write-Host ""
    $export = Read-Host "   Salvar em arquivo TXT também? (S/N)"
    if ($export -match "^[Ss]") {
        $exportFile = Join-Path $global:LogDir "coleta_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Set-Content -Path $exportFile -Value $info -Force
        Write-Status "Salvo em: $exportFile" "OK"
    }

    Write-Log "Coleta rápida executada e copiada para clipboard."
    Pause-Script
}
