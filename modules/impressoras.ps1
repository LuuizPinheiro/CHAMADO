# ==============================================================================
# MÓDULO: Impressoras de Rede (Detecção e Conexão Automática)
# ==============================================================================
# - Varre a sub-rede local (ping paralelo + tabela ARP)
# - Detecta impressoras pelas portas 9100 (RAW), 515 (LPD) e 631 (IPP)
# - Identifica o modelo via SNMP (community "public")
# - Detecta impressoras compartilhadas em outros PCs (SMB)
# - Instala automaticamente com o melhor driver disponível
# ==============================================================================

function Invoke-MenuImpressoras {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "IMPRESSORAS DE REDE"

        Write-MenuOption "1"  "Detectar e Conectar Impressoras Automaticamente"
        Write-MenuOption "2"  "Apenas Escanear a Rede (sem instalar)"
        Write-MenuOption "3"  "Listar Impressoras Instaladas"
        Write-MenuOption "4"  "Adicionar Impressora por IP (manual)"
        Write-MenuOption "5"  "Conectar Impressora Compartilhada (\\PC\Impressora)"
        Write-MenuOption "6"  "Definir Impressora Padrão"
        Write-MenuOption "7"  "Imprimir Página de Teste"
        Write-MenuOption "8"  "Remover Impressora"
        Write-MenuOption "9"  "Limpar Fila de Impressão (Reiniciar Spooler)"
        Write-MenuOption "10" "Ativar Descoberta Automática do Windows"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1"  { Invoke-AutoConnectPrinters }
            "2"  { Invoke-AutoConnectPrinters -ScanOnly }
            "3"  { Show-InstalledPrinters }
            "4"  { Add-PrinterByIP }
            "5"  { Add-SharedPrinter }
            "6"  { Set-DefaultPrinterMenu }
            "7"  { Invoke-PrinterTestPage }
            "8"  { Remove-PrinterMenu }
            "9"  { Reset-PrintSpooler }
            "10" { Enable-PrinterDiscovery -Show; Pause-Script }
            "0"  { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# ------------------------------------------------------------------------------
# UTILITÁRIOS
# ------------------------------------------------------------------------------

function Test-PrintCmdlets {
    if (-not (Get-Command Add-Printer -ErrorAction SilentlyContinue)) {
        Write-Status "Os comandos de impressora (PrintManagement) não estão disponíveis neste Windows." "ERRO"
        Write-Host "   Necessário Windows 8 / 10 / 11." -ForegroundColor Gray
        return $false
    }
    $sp = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if ($sp -and $sp.Status -ne 'Running') {
        Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
    }
    return $true
}

function ConvertTo-UInt32IP {
    param([string]$IP)
    $b = ([System.Net.IPAddress]::Parse($IP)).GetAddressBytes()
    [Array]::Reverse($b)
    return [BitConverter]::ToUInt32($b, 0)
}

function ConvertFrom-UInt32IP {
    param([uint32]$Value)
    $b = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($b)
    return (New-Object System.Net.IPAddress(, $b)).ToString()
}

function Get-LocalIPv4Networks {
    $nets = @()
    # Método 1: NetTCPIP
    try {
        $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' }
        foreach ($a in $addrs) {
            $ad = Get-NetAdapter -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue
            if ($ad -and $ad.Status -ne 'Up') { continue }
            if ($ad -and $ad.InterfaceDescription -match 'Hyper-V|VirtualBox|VMware|WSL|Loopback|TAP-|Npcap') { continue }
            $nets += [PSCustomObject]@{ IP = $a.IPAddress; Prefix = [int]$a.PrefixLength; Adapter = $a.InterfaceAlias }
        }
    } catch { }

    # Método 2: WMI (fallback)
    if ($nets.Count -eq 0) {
        $cfgs = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue
        foreach ($c in $cfgs) {
            for ($i = 0; $i -lt @($c.IPAddress).Count; $i++) {
                $ip = @($c.IPAddress)[$i]; $mask = @($c.IPSubnet)[$i]
                if ($ip -notmatch '^\d+\.\d+\.\d+\.\d+$' -or $ip -match '^(127\.|169\.254\.)') { continue }
                $bits = 0
                foreach ($oct in $mask.Split('.')) { $bits += ([Convert]::ToString([int]$oct, 2) -replace '0', '').Length }
                $nets += [PSCustomObject]@{ IP = $ip; Prefix = $bits; Adapter = $c.Description }
            }
        }
    }
    return $nets
}

function Get-SubnetHosts {
    param([string]$IP, [int]$Prefix)
    # Limita a varredura a no máximo /22 (1022 hosts) para não demorar
    if ($Prefix -lt 22) { $Prefix = 24 }
    if ($Prefix -gt 30) { return @() }

    $ipNum   = [uint64](ConvertTo-UInt32IP $IP)
    $hostBits = 32 - $Prefix
    $size    = [uint64][math]::Pow(2, $hostBits)
    $network = [uint64]([math]::Floor($ipNum / $size) * $size)
    $hosts = New-Object System.Collections.Generic.List[string]
    for ($n = $network + 1; $n -lt ($network + $size - 1); $n++) {
        if ($n -eq $ipNum) { continue }
        $hosts.Add((ConvertFrom-UInt32IP ([uint32]$n)))
    }
    return $hosts
}

function Find-LiveHosts {
    param([string[]]$Hosts, [int]$TimeoutMs = 700)

    $live = @{}
    # Ping paralelo em lotes
    $batchSize = 256
    for ($i = 0; $i -lt $Hosts.Count; $i += $batchSize) {
        $batch = $Hosts[$i..([math]::Min($i + $batchSize, $Hosts.Count) - 1)]
        $pairs = @()
        foreach ($h in $batch) {
            try {
                $p = New-Object System.Net.NetworkInformation.Ping
                $pairs += [PSCustomObject]@{ Host = $h; Ping = $p; Task = $p.SendPingAsync($h, $TimeoutMs) }
            } catch { }
        }
        try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($pairs.Task), ($TimeoutMs + 2000)) } catch { }
        foreach ($pp in $pairs) {
            try {
                if ($pp.Task.Status -eq 'RanToCompletion' -and $pp.Task.Result.Status -eq 'Success') { $live[$pp.Host] = $true }
            } catch { }
            try { $pp.Ping.Dispose() } catch { }
        }
    }

    # Tabela ARP (pega dispositivos que bloqueiam ping)
    try {
        Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.State -in @('Reachable', 'Stale', 'Delay', 'Probe', 'Permanent') -and $_.LinkLayerAddress -and $_.LinkLayerAddress -notmatch '^(00-00-00-00-00-00|FF-FF-FF-FF-FF-FF)$' } |
            ForEach-Object { if ($Hosts -contains $_.IPAddress) { $live[$_.IPAddress] = $true } }
    } catch {
        $arp = arp -a 2>$null
        foreach ($line in $arp) {
            if ($line -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-f]{2}(-[0-9a-f]{2}){5})') {
                if ($Hosts -contains $Matches[1] -and $Matches[2] -ne 'ff-ff-ff-ff-ff-ff') { $live[$Matches[1]] = $true }
            }
        }
    }
    return @($live.Keys)
}

function Test-TcpPorts {
    <# Testa várias portas em vários hosts em paralelo. Retorna hashtable host -> lista de portas abertas #>
    param([string[]]$Hosts, [int[]]$Ports, [int]$TimeoutMs = 1200)

    $result = @{}
    $items = @()
    foreach ($h in $Hosts) {
        foreach ($port in $Ports) {
            try {
                $c = New-Object System.Net.Sockets.TcpClient
                $items += [PSCustomObject]@{ Host = $h; Port = $port; Client = $c; Task = $c.ConnectAsync($h, $port) }
            } catch { }
        }
    }
    if ($items.Count -eq 0) { return $result }
    try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($items.Task), $TimeoutMs) } catch { }

    foreach ($it in $items) {
        try {
            if ($it.Task.Status -eq 'RanToCompletion' -and $it.Client.Connected) {
                if (-not $result.ContainsKey($it.Host)) { $result[$it.Host] = @() }
                $result[$it.Host] += $it.Port
            }
        } catch { }
        try { $it.Client.Close() } catch { }
    }
    return $result
}

# ------------------------------------------------------------------------------
# SNMP (identificação do modelo) - implementação mínima SNMPv1 GET
# ------------------------------------------------------------------------------

function ConvertTo-BerLength {
    param([int]$Length)
    if ($Length -lt 128) { return , ([byte[]]@($Length)) }
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($Length -gt 0) { $bytes.Insert(0, [byte]($Length -band 0xFF)); $Length = $Length -shr 8 }
    $bytes.Insert(0, [byte](0x80 + $bytes.Count))
    return , $bytes.ToArray()
}

function New-BerTlv {
    param([byte]$Tag, [byte[]]$Value)
    if ($null -eq $Value) { $Value = [byte[]]@() }
    $list = New-Object System.Collections.Generic.List[byte]
    $list.Add($Tag)
    $list.AddRange([byte[]](ConvertTo-BerLength $Value.Length))
    $list.AddRange($Value)
    return , $list.ToArray()
}

function ConvertTo-BerOid {
    param([string]$Oid)
    $parts = @($Oid.Trim('.').Split('.') | ForEach-Object { [long]$_ })
    $out = New-Object System.Collections.Generic.List[byte]
    $out.Add([byte](40 * $parts[0] + $parts[1]))
    for ($i = 2; $i -lt $parts.Count; $i++) {
        $v = $parts[$i]
        $tmp = New-Object System.Collections.Generic.List[byte]
        $tmp.Insert(0, [byte]($v -band 0x7F)); $v = $v -shr 7
        while ($v -gt 0) { $tmp.Insert(0, [byte](($v -band 0x7F) -bor 0x80)); $v = $v -shr 7 }
        $out.AddRange($tmp)
    }
    return , $out.ToArray()
}

function Read-BerTlv {
    param([byte[]]$Buffer, [int]$Offset)
    $tag = $Buffer[$Offset]; $Offset++
    $len = [int]$Buffer[$Offset]; $Offset++
    if ($len -band 0x80) {
        $n = $len -band 0x7F; $len = 0
        for ($i = 0; $i -lt $n; $i++) { $len = ($len -shl 8) + $Buffer[$Offset]; $Offset++ }
    }
    return [PSCustomObject]@{ Tag = $tag; Len = $len; Start = $Offset; Next = $Offset + $len }
}

function Get-SnmpString {
    param([string]$IP, [string]$Oid, [string]$Community = "public", [int]$TimeoutMs = 900)
    $udp = $null
    try {
        $varbind = New-BerTlv 0x30 ([byte[]]((New-BerTlv 0x06 (ConvertTo-BerOid $Oid)) + (New-BerTlv 0x05 @())))
        $vblist  = New-BerTlv 0x30 $varbind
        $reqId   = [byte](Get-Random -Minimum 1 -Maximum 120)
        $pduBody = [byte[]]((New-BerTlv 0x02 @($reqId)) + (New-BerTlv 0x02 @(0)) + (New-BerTlv 0x02 @(0)) + $vblist)
        $pdu     = New-BerTlv 0xA0 $pduBody
        $msgBody = [byte[]]((New-BerTlv 0x02 @(0)) + (New-BerTlv 0x04 ([Text.Encoding]::ASCII.GetBytes($Community))) + $pdu)
        $packet  = New-BerTlv 0x30 $msgBody

        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = $TimeoutMs
        $udp.Connect($IP, 161)
        [void]$udp.Send($packet, $packet.Length)
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $resp = $udp.Receive([ref]$ep)

        $msg = Read-BerTlv $resp 0
        $ver = Read-BerTlv $resp $msg.Start
        $com = Read-BerTlv $resp $ver.Next
        $rsp = Read-BerTlv $resp $com.Next
        $rid = Read-BerTlv $resp $rsp.Start
        $err = Read-BerTlv $resp $rid.Next
        if ($resp[$err.Start] -ne 0) { return $null }
        $eix = Read-BerTlv $resp $err.Next
        $vbl = Read-BerTlv $resp $eix.Next
        $vb  = Read-BerTlv $resp $vbl.Start
        $oidT = Read-BerTlv $resp $vb.Start
        $val = Read-BerTlv $resp $oidT.Next
        if ($val.Tag -ne 0x04 -or $val.Len -le 0) { return $null }
        $text = [Text.Encoding]::ASCII.GetString($resp, $val.Start, $val.Len)
        $text = ($text -replace '[^\x20-\x7E]', '').Trim()
        if ($text) { return $text } else { return $null }
    } catch {
        return $null
    } finally {
        if ($udp) { try { $udp.Close() } catch { } }
    }
}

function Get-PrinterModel {
    param([string]$IP)
    # hrDeviceDescr (modelo exato) -> sysDescr (descrição geral)
    $model = Get-SnmpString $IP "1.3.6.1.2.1.25.3.2.1.3.1"
    if (-not $model) { $model = Get-SnmpString $IP "1.3.6.1.2.1.1.1.0" }
    if ($model) {
        $model = ($model -split '[;,]')[0].Trim()
        if ($model.Length -gt 60) { $model = $model.Substring(0, 60).Trim() }
    }
    return $model
}

# ------------------------------------------------------------------------------
# DESCOBERTA
# ------------------------------------------------------------------------------

function Get-InstalledPrinterIndex {
    $idx = @{ ByHost = @{}; Names = @(); Shares = @{} }
    try {
        $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue)
        $printers = @(Get-Printer -ErrorAction SilentlyContinue)
        $idx.Names = @($printers | ForEach-Object { $_.Name })
        foreach ($pr in $printers) {
            $port = $ports | Where-Object { $_.Name -eq $pr.PortName } | Select-Object -First 1
            $hostAddr = $null
            if ($port -and $port.PrinterHostAddress) { $hostAddr = $port.PrinterHostAddress }
            elseif ($pr.PortName -match '(\d+\.\d+\.\d+\.\d+)') { $hostAddr = $Matches[1] }
            if ($hostAddr) { $idx.ByHost[$hostAddr] = $pr.Name }
            if ($pr.Name -like '\\*') { $idx.Shares[$pr.Name.ToLower()] = $pr.Name }
        }
    } catch { }
    return $idx
}

function Find-SharedPrinters {
    param([string]$HostIP)
    $found = @()
    $tmp = Join-Path $env:TEMP "chamado_netview_$([guid]::NewGuid().ToString('N')).txt"
    try {
        $proc = Start-Process -FilePath "net.exe" -ArgumentList "view \\$HostIP" -NoNewWindow -PassThru -RedirectStandardOutput $tmp -RedirectStandardError "$tmp.err"
        if (-not $proc.WaitForExit(6000)) { try { $proc.Kill() } catch { }; return @() }
        $lines = Get-Content $tmp -ErrorAction SilentlyContinue
        foreach ($l in $lines) {
            # Coluna "Tipo" é localizada: Print (EN) / Impressão (PT) / Imprimir / Drucker...
            if ($l -match '^(\S.*?)\s{2,}(Print|Impress|Imprim|Druck)') {
                $found += $Matches[1].Trim()
            }
        }
    } catch { } finally {
        Remove-Item $tmp, "$tmp.err" -Force -ErrorAction SilentlyContinue
    }
    return $found
}

function Find-NetworkPrinters {
    param([switch]$IncludeShared = $true)

    $nets = @(Get-LocalIPv4Networks)
    if ($nets.Count -eq 0) {
        Write-Status "Nenhuma rede IPv4 ativa encontrada. Verifique o cabo/Wi-Fi." "ERRO"
        return @()
    }

    $allHosts = New-Object System.Collections.Generic.List[string]
    foreach ($n in $nets) {
        $p = if ($n.Prefix -lt 22) { 24 } else { $n.Prefix }
        Write-Host "   Rede: $($n.IP)/$p ($($n.Adapter))" -ForegroundColor Gray
        foreach ($h in (Get-SubnetHosts $n.IP $n.Prefix)) { if (-not $allHosts.Contains($h)) { $allHosts.Add($h) } }
    }
    if ($allHosts.Count -eq 0) { Write-Status "Sub-rede inválida para varredura." "ERRO"; return @() }

    Write-Host "   [1/3] Procurando dispositivos ativos ($($allHosts.Count) endereços)..." -ForegroundColor Yellow
    $live = @(Find-LiveHosts -Hosts $allHosts.ToArray())
    Write-Host "         $($live.Count) dispositivos responderam." -ForegroundColor DarkGray
    if ($live.Count -eq 0) { return @() }

    Write-Host "   [2/3] Verificando portas de impressão (9100 / 515 / 631)..." -ForegroundColor Yellow
    $ports = @(9100, 515, 631)
    if ($IncludeShared) { $ports += 445 }
    $open = Test-TcpPorts -Hosts $live -Ports $ports

    $index = Get-InstalledPrinterIndex
    $devices = @()

    Write-Host "   [3/3] Identificando modelos..." -ForegroundColor Yellow
    foreach ($h in ($open.Keys | Sort-Object { [version]$_ })) {
        $p = @($open[$h])
        $printPorts = @($p | Where-Object { $_ -in @(9100, 515, 631) })
        if ($printPorts.Count -gt 0) {
            $model = Get-PrinterModel $h
            $devices += [PSCustomObject]@{
                Tipo        = "Rede"
                IP          = $h
                Modelo      = if ($model) { $model } else { "Impressora de Rede" }
                Portas      = $printPorts
                Caminho     = $h
                Instalada   = $index.ByHost.ContainsKey($h)
                NomeInstalado = $index.ByHost[$h]
            }
        }
        if ($IncludeShared -and ($p -contains 445)) {
            foreach ($share in (Find-SharedPrinters $h)) {
                $unc = "\\$h\$share"
                $hostName = $null
                try { $hostName = ([System.Net.Dns]::GetHostEntry($h)).HostName.Split('.')[0] } catch { }
                $uncByName = if ($hostName) { "\\$hostName\$share" } else { $null }
                $inst = $index.Shares.ContainsKey($unc.ToLower()) -or ($uncByName -and $index.Shares.ContainsKey($uncByName.ToLower()))
                $devices += [PSCustomObject]@{
                    Tipo        = "Compartilhada"
                    IP          = $h
                    Modelo      = $share
                    Portas      = @(445)
                    Caminho     = if ($uncByName) { $uncByName } else { $unc }
                    Instalada   = [bool]$inst
                    NomeInstalado = $null
                }
            }
        }
    }
    return $devices
}

# ------------------------------------------------------------------------------
# INSTALAÇÃO
# ------------------------------------------------------------------------------

function Find-BestPrinterDriver {
    param([string]$Model)

    $installed = @(Get-PrinterDriver -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $maker = $null; $modelToken = $null
    if ($Model -and $Model -ne "Impressora de Rede") {
        $words = $Model -split '\s+'
        $maker = $words[0]
        $modelToken = $words | Where-Object { $_ -match '\d' } | Select-Object -First 1
    }

    # 1) Driver já instalado que combine com fabricante + modelo
    if ($maker -and $modelToken) {
        $core = ($modelToken -replace '[a-zA-Z]+$', '')
        $match = $installed | Where-Object { $_ -match [regex]::Escape($maker) -and ($_ -match [regex]::Escape($modelToken) -or ($core.Length -ge 3 -and $_ -match [regex]::Escape($core))) } | Select-Object -First 1
        if ($match) { return $match }
    }

    # 2) Tenta instalar do repositório de drivers do Windows (DriverStore / inbox)
    $candidates = @()
    if ($Model -and $Model -ne "Impressora de Rede") {
        $candidates += $Model
        $candidates += "$Model PCL-6"
        $candidates += "$Model PCL 6"
        $candidates += "$Model Series"
        $candidates += "$Model PS"
    }
    if ($maker -match '^HP|Hewlett') { $candidates += "HP Universal Printing PCL 6"; $candidates += "HP Universal Printing PS" }
    if ($maker -match 'Samsung') { $candidates += "Samsung Universal Print Driver 3"; $candidates += "Samsung Universal Print Driver 2" }
    if ($maker -match 'Kyocera') { $candidates += "Kyocera Classic Universaldriver PCL6" }
    if ($maker -match 'Ricoh')   { $candidates += "PCL6 Driver for Universal Print" }

    foreach ($c in $candidates) {
        if ($installed -contains $c) { return $c }
        try {
            Add-PrinterDriver -Name $c -ErrorAction Stop
            return $c
        } catch { }
    }

    # 3) Drivers genéricos (funcionam na maioria das laser via porta RAW)
    #    Jato de tinta (Epson/Canon) normalmente NÃO funcionam com PCL genérico.
    if ($maker -match 'Epson|Canon') { return $null }
    foreach ($g in @("Microsoft PCL6 Class Driver", "Microsoft PS Class Driver")) {
        if ($installed -contains $g) { return $g }
        try { Add-PrinterDriver -Name $g -ErrorAction Stop; return $g } catch { }
    }
    return $null
}

function Install-NetworkPrinter {
    param($Device)

    if ($Device.Tipo -eq "Compartilhada") {
        try {
            Add-Printer -ConnectionName $Device.Caminho -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; Nome = $Device.Caminho; Msg = "Conectada" }
        } catch {
            # Tenta pelo IP caso o nome não resolva
            $alt = "\\$($Device.IP)\$($Device.Modelo)"
            try {
                Add-Printer -ConnectionName $alt -ErrorAction Stop
                return [PSCustomObject]@{ Ok = $true; Nome = $alt; Msg = "Conectada" }
            } catch {
                return [PSCustomObject]@{ Ok = $false; Nome = $Device.Caminho; Msg = $_.Exception.Message }
            }
        }
    }

    $ip = $Device.IP
    $driver = Find-BestPrinterDriver $Device.Modelo
    if (-not $driver) {
        return [PSCustomObject]@{ Ok = $false; Nome = $Device.Modelo; Msg = "Driver do fabricante necessário" }
    }

    # Cria a porta TCP/IP (RAW 9100 preferencial, senão LPR)
    $portName = "IP_$ip"
    try {
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            if ($Device.Portas -contains 9100 -or -not ($Device.Portas -contains 515)) {
                Add-PrinterPort -Name $portName -PrinterHostAddress $ip -PortNumber 9100 -ErrorAction Stop
            } else {
                Add-PrinterPort -Name $portName -LprHostAddress $ip -LprQueueName "lp" -LprByteCounting -ErrorAction Stop
            }
        }
    } catch {
        return [PSCustomObject]@{ Ok = $false; Nome = $Device.Modelo; Msg = "Falha ao criar porta: $($_.Exception.Message)" }
    }

    $baseName = if ($Device.Modelo -and $Device.Modelo -ne "Impressora de Rede") { $Device.Modelo } else { "Impressora de Rede" }
    $name = "$baseName ($ip)"
    $existing = @(Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    if ($existing -contains $name) {
        return [PSCustomObject]@{ Ok = $true; Nome = $name; Msg = "Já instalada" }
    }

    try {
        Add-Printer -Name $name -DriverName $driver -PortName $portName -ErrorAction Stop
        return [PSCustomObject]@{ Ok = $true; Nome = $name; Msg = "Driver: $driver" }
    } catch {
        return [PSCustomObject]@{ Ok = $false; Nome = $name; Msg = $_.Exception.Message }
    }
}

function Enable-PrinterDiscovery {
    param([switch]$Show)
    $Verbose = [bool]$Show
    if ($Verbose) {
        Write-Header
        Write-SubHeader "ATIVAR DESCOBERTA AUTOMÁTICA DO WINDOWS"
        Write-Host "   Ativa os serviços que permitem ao Windows encontrar e instalar" -ForegroundColor Gray
        Write-Host "   impressoras sozinho (WSD / UPnP / Network Discovery)." -ForegroundColor Gray
        Write-Host ""
    }

    # Serviços de descoberta
    foreach ($svc in @("Spooler", "fdPHost", "FDResPub", "SSDPSRV", "upnphost", "NcdAutoSetup", "Dnscache")) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Set-Service -Name $svc -StartupType Automatic -ErrorAction SilentlyContinue
            if ($s.Status -ne 'Running') { Start-Service -Name $svc -ErrorAction SilentlyContinue }
            if ($Verbose) { Write-Status "Serviço $svc ativo" "OK" }
        }
    }

    # Firewall: Descoberta de Rede + Compartilhamento de Arquivos e Impressoras (IDs independentes de idioma)
    try {
        Enable-NetFirewallRule -Group "@FirewallAPI.dll,-32752" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -Group "@FirewallAPI.dll,-28502" -ErrorAction SilentlyContinue
        if ($Verbose) { Write-Status "Firewall: Descoberta de Rede e Compartilhamento liberados" "OK" }
    } catch {
        netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes 2>$null | Out-Null
    }

    # Configuração automática de dispositivos de rede
    try {
        $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private"
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -Path $key -Name "AutoSetup" -Value 1 -Type DWord -Force
        if ($Verbose) { Write-Status "Configuração automática de dispositivos de rede ativada" "OK" }
    } catch { }

    # Perfil de rede
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
        $public = @($profiles | Where-Object { $_.NetworkCategory -eq 'Public' })
        if ($public.Count -gt 0) {
            Write-Host ""
            Write-Host "   A rede '$($public[0].Name)' está como PÚBLICA (a descoberta automática fica bloqueada)." -ForegroundColor Yellow
            $r = Read-Host "   Alterar para PRIVADA? (S/N)"
            if ($r -match '^[Ss]') {
                foreach ($p in $public) { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue }
                Write-Status "Rede alterada para Privada" "OK"
            }
        } elseif ($Verbose) {
            Write-Status "Perfil de rede já é Privado/Domínio" "OK"
        }
    } catch { }

    Write-Log "Descoberta automática de impressoras ativada."
}

function Write-PrinterReport {
    param($Devices, $Results)
    try {
        $lines = @()
        $lines += "CHAMADO - Relatorio de Impressoras de Rede"
        $lines += "Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') | PC: $env:COMPUTERNAME"
        $lines += "------------------------------------------------------------------"
        foreach ($d in $Devices) {
            $st = if ($d.Instalada) { "Ja instalada" } else { "Nova" }
            $lines += "{0,-15} {1,-14} {2,-40} Portas: {3} [{4}]" -f $d.IP, $d.Tipo, $d.Modelo, ($d.Portas -join ","), $st
        }
        if ($Results) {
            $lines += ""
            $lines += "Instalacao:"
            foreach ($r in $Results) { $lines += "  [{0}] {1} - {2}" -f $(if ($r.Ok) { "OK" } else { "FALHA" }), $r.Nome, $r.Msg }
        }
        $path = Join-Path $global:DataDir "impressoras_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $lines | Set-Content -Path $path -Encoding UTF8 -Force
    } catch { }
}

# ------------------------------------------------------------------------------
# FLUXO PRINCIPAL
# ------------------------------------------------------------------------------

function Invoke-AutoConnectPrinters {
    param([switch]$ScanOnly)

    Write-Header
    Write-SubHeader $(if ($ScanOnly) { "ESCANEAR REDE POR IMPRESSORAS" } else { "DETECTAR E CONECTAR IMPRESSORAS" })

    if (-not (Test-PrintCmdlets)) { Pause-Script; return }

    if (-not $ScanOnly) {
        Write-Host "   Preparando o Windows para descoberta de impressoras..." -ForegroundColor Gray
        Enable-PrinterDiscovery
        Write-Host ""
    }

    $devices = @(Find-NetworkPrinters)
    Write-Host ""

    if ($devices.Count -eq 0) {
        Write-Status "Nenhuma impressora encontrada na rede." "WARN"
        Write-Host ""
        Write-Host "   Dicas:" -ForegroundColor $global:ThemeColor
        Write-Host "   - Verifique se a impressora está ligada e conectada na MESMA rede." -ForegroundColor Gray
        Write-Host "   - Impressoras USB precisam estar compartilhadas no PC onde estão ligadas." -ForegroundColor Gray
        Write-Host "   - Algumas impressoras Wi-Fi só aparecem via WSD: aguarde 1-2 min com a" -ForegroundColor Gray
        Write-Host "     descoberta ativada e confira em Configurações > Impressoras." -ForegroundColor Gray
        Write-PrinterReport @() $null
        Write-Log "Busca de impressoras: nenhuma encontrada."
        Pause-Script
        return
    }

    Write-Host "   #   IP               Tipo           Modelo / Nome                     Status" -ForegroundColor $global:ThemeColor
    Write-Host "   --  ---------------  -------------  --------------------------------  ----------" -ForegroundColor DarkGray
    $i = 1
    foreach ($d in $devices) {
        $model = $d.Modelo; if ($model.Length -gt 32) { $model = $model.Substring(0, 29) + "..." }
        $st = if ($d.Instalada) { "Instalada" } else { "NOVA" }
        $color = if ($d.Instalada) { "DarkGray" } else { "White" }
        Write-Host ("   {0,2}  {1,-15}  {2,-13}  {3,-32}  {4}" -f $i, $d.IP, $d.Tipo, $model, $st) -ForegroundColor $color
        $i++
    }
    Write-Host ""

    $new = @($devices | Where-Object { -not $_.Instalada })

    if ($ScanOnly) {
        Write-Host "   Painel web da impressora: digite o IP no navegador (ex: http://$($devices[0].IP))" -ForegroundColor DarkGray
        Write-PrinterReport $devices $null
        Write-Log "Busca de impressoras: $($devices.Count) encontradas (somente escaneamento)."
        Pause-Script
        return
    }

    if ($new.Count -eq 0) {
        Write-Status "Todas as impressoras encontradas já estão instaladas!" "OK"
        Write-PrinterReport $devices $null
        Pause-Script
        return
    }

    Write-Host "   $($new.Count) impressora(s) nova(s) encontrada(s)." -ForegroundColor Yellow
    $sel = Read-Host "   Conectar quais? (Enter = TODAS as novas, números separados por vírgula, 0 = cancelar)"
    if ($sel -eq "0") { return }

    $toInstall = @()
    if ([string]::IsNullOrWhiteSpace($sel)) {
        $toInstall = $new
    } else {
        foreach ($n in ($sel -split ',')) {
            $n = $n.Trim()
            if ($n -match '^\d+$') {
                $idx = [int]$n - 1
                if ($idx -ge 0 -and $idx -lt $devices.Count) { $toInstall += $devices[$idx] }
            }
        }
    }

    Write-Host ""
    $results = @()
    foreach ($d in $toInstall) {
        Write-Host "   Conectando $($d.Modelo) ($($d.IP))..." -ForegroundColor Gray
        $r = Install-NetworkPrinter $d
        $results += $r
        if ($r.Ok) {
            Write-Status "$($r.Nome) - $($r.Msg)" "OK"
            Write-Log "Impressora conectada: $($r.Nome) ($($r.Msg))"
        } else {
            Write-Status "$($r.Nome) - $($r.Msg)" "ERRO"
            Write-Log "Falha ao conectar impressora $($r.Nome): $($r.Msg)" "ERRO"
        }
    }

    $failedDriver = @($results | Where-Object { -not $_.Ok -and $_.Msg -match 'Driver' })
    if ($failedDriver.Count -gt 0) {
        Write-Host ""
        Write-Host "   Algumas impressoras precisam do driver do fabricante." -ForegroundColor Yellow
        Write-Host "   O Windows pode instalá-las sozinho em 1-2 minutos (descoberta ativada)." -ForegroundColor Gray
        $o = Read-Host "   Abrir 'Impressoras e Scanners' do Windows para adicionar manualmente? (S/N)"
        if ($o -match '^[Ss]') { Start-Process "ms-settings:printers" -ErrorAction SilentlyContinue }
    }

    $okList = @($results | Where-Object { $_.Ok })
    if ($okList.Count -gt 0) {
        Write-Host ""
        Write-Host "   Definir uma delas como impressora padrão?" -ForegroundColor $global:ThemeColor
        for ($k = 0; $k -lt $okList.Count; $k++) { Write-Host "   [$($k + 1)] $($okList[$k].Nome)" }
        $def = Read-Host "   Número (Enter = pular)"
        if ($def -match '^\d+$') {
            $idx = [int]$def - 1
            if ($idx -ge 0 -and $idx -lt $okList.Count) { Set-PrinterAsDefault $okList[$idx].Nome }
        }
    }

    Write-PrinterReport $devices $results
    Pause-Script
}

# ------------------------------------------------------------------------------
# GERENCIAMENTO
# ------------------------------------------------------------------------------

function Get-PrinterList {
    $list = @()
    try {
        $list = @(Get-Printer -ErrorAction Stop | Sort-Object Name)
    } catch {
        $list = @(Get-WmiObject Win32_Printer -ErrorAction SilentlyContinue | Sort-Object Name |
            ForEach-Object { [PSCustomObject]@{ Name = $_.Name; PortName = $_.PortName; DriverName = $_.DriverName; PrinterStatus = $_.PrinterStatus; Type = "" } })
    }
    return $list
}

function Get-DefaultPrinterName {
    try {
        $d = Get-CimInstance Win32_Printer -Filter "Default=True" -ErrorAction Stop | Select-Object -First 1
        if ($d) { return $d.Name }
    } catch {
        $d = Get-WmiObject Win32_Printer -Filter "Default=True" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($d) { return $d.Name }
    }
    return $null
}

function Select-PrinterFromList {
    param([string]$Prompt = "Escolha a impressora")
    $list = @(Get-PrinterList)
    if ($list.Count -eq 0) { Write-Status "Nenhuma impressora instalada." "WARN"; return $null }
    $default = Get-DefaultPrinterName
    $i = 1
    foreach ($p in $list) {
        $mark = if ($p.Name -eq $default) { " (PADRÃO)" } else { "" }
        Write-Host ("   [{0,2}] {1}{2}" -f $i, $p.Name, $mark) -ForegroundColor $(if ($mark) { $global:ThemeColor } else { "White" })
        $i++
    }
    Write-Host ""
    $c = Read-Host "   $Prompt (número, 0 = cancelar)"
    if ($c -match '^\d+$' -and $c -ne "0") {
        $idx = [int]$c - 1
        if ($idx -ge 0 -and $idx -lt $list.Count) { return $list[$idx].Name }
    }
    return $null
}

function Get-WmiPrinterByName {
    param([string]$Name)
    $escaped = $Name.Replace('\', '\\').Replace("'", "\'")
    $p = Get-CimInstance Win32_Printer -Filter "Name='$escaped'" -ErrorAction SilentlyContinue
    if (-not $p) { $p = Get-WmiObject Win32_Printer -Filter "Name='$escaped'" -ErrorAction SilentlyContinue }
    return $p
}

function Set-PrinterAsDefault {
    param([string]$Name)
    # Impede o Windows 10/11 de trocar a padrão sozinho
    try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name "LegacyDefaultPrinterMode" -Value 1 -Type DWord -Force } catch { }
    $p = Get-WmiPrinterByName $Name
    $ok = $false
    if ($p) {
        try {
            if ($p -is [Microsoft.Management.Infrastructure.CimInstance]) {
                $r = Invoke-CimMethod -InputObject $p -MethodName SetDefaultPrinter -ErrorAction Stop
                $ok = ($r.ReturnValue -eq 0)
            } else {
                $r = $p.SetDefaultPrinter(); $ok = ($r.ReturnValue -eq 0)
            }
        } catch { }
    }
    if (-not $ok) {
        try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($Name); $ok = $true } catch { }
    }
    if ($ok) { Write-Status "'$Name' definida como padrão" "OK"; Write-Log "Impressora padrão: $Name" }
    else { Write-Status "Não foi possível definir '$Name' como padrão" "ERRO" }
}

function Show-InstalledPrinters {
    Write-Header
    Write-SubHeader "IMPRESSORAS INSTALADAS"

    $list = @(Get-PrinterList)
    if ($list.Count -eq 0) {
        Write-Status "Nenhuma impressora instalada." "WARN"
        Pause-Script
        return
    }
    $default = Get-DefaultPrinterName
    $ports = @{}
    try { Get-PrinterPort -ErrorAction SilentlyContinue | ForEach-Object { $ports[$_.Name] = $_.PrinterHostAddress } } catch { }

    foreach ($p in $list) {
        $isDef = ($p.Name -eq $default)
        Write-Host "   $($p.Name)$(if ($isDef) { '  [PADRÃO]' })" -ForegroundColor $(if ($isDef) { $global:ThemeColor } else { "White" })
        $addr = $ports[$p.PortName]
        $portTxt = if ($addr) { "$($p.PortName) -> $addr" } else { $p.PortName }
        Write-Host "      Porta:  $portTxt" -ForegroundColor Gray
        Write-Host "      Driver: $($p.DriverName)" -ForegroundColor Gray
        $jobs = @(Get-PrintJob -PrinterName $p.Name -ErrorAction SilentlyContinue).Count
        if ($jobs -gt 0) { Write-Host "      Fila:   $jobs trabalho(s) pendente(s)" -ForegroundColor Yellow }
        Write-Host ""
    }
    Write-Log "Impressoras instaladas listadas."
    Pause-Script
}

function Add-PrinterByIP {
    Write-Header
    Write-SubHeader "ADICIONAR IMPRESSORA POR IP"
    if (-not (Test-PrintCmdlets)) { Pause-Script; return }

    $ip = (Read-Host "   IP da impressora (ex: 192.168.0.50)").Trim()
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { Write-Status "IP inválido." "ERRO"; Pause-Script; return }

    Write-Host ""
    Write-Host "   Testando $ip..." -ForegroundColor Gray
    $open = Test-TcpPorts -Hosts @($ip) -Ports @(9100, 515, 631, 80) -TimeoutMs 2000
    $ports = @($open[$ip])
    if ($ports.Count -eq 0) {
        Write-Status "Nenhuma porta de impressão respondeu em $ip. Verifique se está ligada." "ERRO"
        Pause-Script
        return
    }
    Write-Status "Portas abertas: $($ports -join ', ')" "OK"
    $model = Get-PrinterModel $ip
    if ($model) { Write-Status "Modelo detectado: $model" "OK" }
    else {
        Write-Status "Modelo não identificado via SNMP." "INFO"
        $model = Read-Host "   Digite o modelo (ou Enter para genérico)"
        if (-not $model) { $model = "Impressora de Rede" }
    }

    $dev = [PSCustomObject]@{ Tipo = "Rede"; IP = $ip; Modelo = $model; Portas = $ports; Caminho = $ip; Instalada = $false; NomeInstalado = $null }
    Write-Host ""
    Write-Host "   Instalando..." -ForegroundColor Yellow
    $r = Install-NetworkPrinter $dev
    if ($r.Ok) { Write-Status "$($r.Nome) - $($r.Msg)" "OK"; Write-Log "Impressora adicionada por IP: $($r.Nome)" }
    else {
        Write-Status "$($r.Nome) - $($r.Msg)" "ERRO"
        if ($r.Msg -match 'Driver') {
            Write-Host "   Instale o driver do fabricante e tente novamente." -ForegroundColor Yellow
            $o = Read-Host "   Pesquisar driver na internet? (S/N)"
            if ($o -match '^[Ss]') { Start-Process "https://www.google.com/search?q=driver+$([uri]::EscapeDataString($model))+windows" }
        }
    }
    Pause-Script
}

function Add-SharedPrinter {
    Write-Header
    Write-SubHeader "CONECTAR IMPRESSORA COMPARTILHADA"
    if (-not (Test-PrintCmdlets)) { Pause-Script; return }

    Write-Host "   Formato: \\NOME-DO-PC\NomeDaImpressora  ou  \\192.168.0.10\NomeDaImpressora" -ForegroundColor Gray
    Write-Host "   Dica: digite apenas \\NOME-DO-PC para listar as impressoras daquele PC." -ForegroundColor DarkGray
    Write-Host ""
    $path = (Read-Host "   Caminho").Trim()
    if ($path -notmatch '^\\\\[^\\]+') { Write-Status "Caminho inválido." "ERRO"; Pause-Script; return }

    if ($path -match '^\\\\([^\\]+)\\?$') {
        $pcName = $Matches[1]
        $shares = @(Find-SharedPrinters $pcName)
        if ($shares.Count -eq 0) { Write-Status "Nenhuma impressora compartilhada encontrada em $pcName." "WARN"; Pause-Script; return }
        $i = 1
        foreach ($s in $shares) { Write-Host "   [$i] $s"; $i++ }
        $c = Read-Host "   Escolha (número)"
        if ($c -notmatch '^\d+$' -or [int]$c -lt 1 -or [int]$c -gt $shares.Count) { return }
        $path = "\\$pcName\$($shares[[int]$c - 1])"
    }

    try {
        Add-Printer -ConnectionName $path -ErrorAction Stop
        Write-Status "Conectada: $path" "OK"
        Write-Log "Impressora compartilhada conectada: $path"
        $d = Read-Host "   Definir como padrão? (S/N)"
        if ($d -match '^[Ss]') { Set-PrinterAsDefault $path }
    } catch {
        Write-Status "Falha: $($_.Exception.Message)" "ERRO"
        Write-Host "   Verifique se o PC remoto está ligado, com compartilhamento ativado," -ForegroundColor Gray
        Write-Host "   e se você tem permissão (pode ser necessário usuário/senha do PC remoto)." -ForegroundColor Gray
    }
    Pause-Script
}

function Set-DefaultPrinterMenu {
    Write-Header
    Write-SubHeader "DEFINIR IMPRESSORA PADRÃO"
    $name = Select-PrinterFromList "Nova impressora padrão"
    if ($name) { Set-PrinterAsDefault $name }
    Pause-Script
}

function Invoke-PrinterTestPage {
    Write-Header
    Write-SubHeader "IMPRIMIR PÁGINA DE TESTE"
    $name = Select-PrinterFromList "Imprimir teste em"
    if (-not $name) { Pause-Script; return }
    $p = Get-WmiPrinterByName $name
    $ok = $false
    try {
        if ($p -is [Microsoft.Management.Infrastructure.CimInstance]) {
            $r = Invoke-CimMethod -InputObject $p -MethodName PrintTestPage -ErrorAction Stop
            $ok = ($r.ReturnValue -eq 0)
        } elseif ($p) {
            $r = $p.PrintTestPage(); $ok = ($r.ReturnValue -eq 0)
        }
    } catch { }
    if (-not $ok) {
        try { Start-Process rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /k /n `"$name`"" -Wait; $ok = $true } catch { }
    }
    if ($ok) { Write-Status "Página de teste enviada para '$name'" "OK"; Write-Log "Página de teste: $name" }
    else { Write-Status "Falha ao enviar página de teste." "ERRO" }
    Pause-Script
}

function Remove-PrinterMenu {
    Write-Header
    Write-SubHeader "REMOVER IMPRESSORA"
    $name = Select-PrinterFromList "Remover qual"
    if (-not $name) { Pause-Script; return }
    $c = Read-Host "   Confirmar remoção de '$name'? (S/N)"
    if ($c -notmatch '^[Ss]') { return }
    try {
        $pr = Get-Printer -Name $name -ErrorAction Stop
        $portName = $pr.PortName
        Remove-Printer -Name $name -ErrorAction Stop
        # Remove a porta TCP/IP se não estiver mais em uso
        if ($portName -like 'IP_*' -and -not (Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.PortName -eq $portName })) {
            Remove-PrinterPort -Name $portName -ErrorAction SilentlyContinue
        }
        Write-Status "Impressora removida." "OK"
        Write-Log "Impressora removida: $name"
    } catch {
        Write-Status "Falha ao remover: $($_.Exception.Message)" "ERRO"
    }
    Pause-Script
}

function Reset-PrintSpooler {
    Write-Header
    Write-SubHeader "LIMPAR FILA DE IMPRESSÃO"
    Write-Host "   Parando o Spooler de Impressão..." -ForegroundColor Gray
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $spoolDir = Join-Path $env:SystemRoot "System32\spool\PRINTERS"
    $count = @(Get-ChildItem -Path $spoolDir -File -Force -ErrorAction SilentlyContinue).Count
    Get-ChildItem -Path $spoolDir -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "   Iniciando o Spooler..." -ForegroundColor Gray
    Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    $s = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq 'Running') {
        Write-Status "Fila limpa ($count arquivo(s) removido(s)) e Spooler reiniciado." "OK"
    } else {
        Write-Status "Spooler não iniciou. Tente reiniciar o computador." "ERRO"
    }
    Write-Log "Spooler reiniciado, $count trabalhos removidos."
    Pause-Script
}
