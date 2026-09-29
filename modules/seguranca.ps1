# ==============================================================================
# MÓDULO: Segurança e Privacidade
# ==============================================================================

function Invoke-MenuSeguranca {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "SEGURANÇA E PRIVACIDADE"

        Write-MenuOption "1" "Status do Windows Defender"
        Write-MenuOption "2" "Scan Rápido do Defender"
        Write-MenuOption "3" "Scan Completo do Defender"
        Write-MenuOption "4" "Atualizar Definições do Defender"
        Write-MenuOption "5" "Status do Firewall"
        Write-MenuOption "6" "Status do BitLocker"
        Write-MenuOption "7" "Verificar Acesso RDP"
        Write-MenuOption "8" "Listar Usuários do Sistema"
        Write-MenuOption "9" "Programas Instalados Recentemente"
        Write-MenuOption "0" "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Show-DefenderStatus }
            "2" { Invoke-DefenderQuickScan }
            "3" { Invoke-DefenderFullScan }
            "4" { Update-DefenderSignatures }
            "5" { Show-FirewallStatus }
            "6" { Show-BitLockerStatus }
            "7" { Show-RDPStatus }
            "8" { Show-SystemUsers }
            "9" { Show-RecentPrograms }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Show-DefenderStatus {
    Write-Header
    Write-SubHeader "STATUS DO WINDOWS DEFENDER"

    $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if (-not $status) {
        Write-Status "Não foi possível verificar o Defender (pode haver outro antivírus)" "WARN"
        Pause-Script
        return
    }

    if ($status.RealTimeProtectionEnabled) {
        Write-Status "Proteção em Tempo Real: ATIVADA" "OK"
    } else {
        Write-Status "Proteção em Tempo Real: DESATIVADA!" "CRIT"
    }

    if ($status.IoavProtectionEnabled) {
        Write-Status "Proteção de Downloads: ATIVADA" "OK"
    } else {
        Write-Status "Proteção de Downloads: DESATIVADA" "WARN"
    }

    if ($status.AntispywareEnabled) {
        Write-Status "Anti-Spyware: ATIVADO" "OK"
    } else {
        Write-Status "Anti-Spyware: DESATIVADO" "WARN"
    }

    $lastUpdate = $status.AntivirusSignatureLastUpdated
    $daysSince = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).Days
    if ($daysSince -gt 7) {
        Write-Status "Última atualização de definições: há $daysSince dias" "WARN"
    } else {
        Write-Status "Última atualização de definições: há $daysSince dias" "OK"
    }

    Write-Host ""
    Write-Host "   Versão do Engine: $($status.AMEngineVersion)" -ForegroundColor Gray
    Write-Host "   Versão das Definições: $($status.AntivirusSignatureVersion)" -ForegroundColor Gray

    Write-Log "Status do Defender verificado."
    Pause-Script
}

function Invoke-DefenderQuickScan {
    Write-Header
    Write-SubHeader "SCAN RÁPIDO DO DEFENDER"
    Write-Host "   Iniciando scan rápido..." -ForegroundColor Yellow
    Write-Host "   Isso pode levar de 5 a 15 minutos." -ForegroundColor Gray
    Write-Host ""
    Start-MpScan -ScanType QuickScan
    Write-Status "Scan rápido finalizado!" "OK"
    Write-Log "Scan rápido do Defender executado."
    Pause-Script
}

function Invoke-DefenderFullScan {
    Write-Header
    Write-SubHeader "SCAN COMPLETO DO DEFENDER"
    Write-Host "   AVISO: O scan completo pode levar HORAS dependendo do disco." -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "   Iniciar scan completo? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host "   Executando..." -ForegroundColor Yellow
        Start-MpScan -ScanType FullScan
        Write-Status "Scan completo finalizado!" "OK"
        Write-Log "Scan completo do Defender executado."
    }
    Pause-Script
}

function Update-DefenderSignatures {
    Write-Header
    Write-SubHeader "ATUALIZAR DEFINIÇÕES DO DEFENDER"
    Write-Host "   Baixando definições mais recentes..." -ForegroundColor Yellow
    Update-MpSignature -ErrorAction SilentlyContinue
    Write-Status "Definições atualizadas!" "OK"
    Write-Log "Definições do Defender atualizadas."
    Pause-Script
}

function Show-FirewallStatus {
    Write-Header
    Write-SubHeader "STATUS DO FIREWALL"

    $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    foreach ($p in $profiles) {
        if ($p.Enabled) {
            Write-Status "Perfil $($p.Name): ATIVADO" "OK"
        } else {
            Write-Status "Perfil $($p.Name): DESATIVADO!" "CRIT"
        }
    }
    Write-Log "Status do Firewall verificado."
    Pause-Script
}

function Show-BitLockerStatus {
    Write-Header
    Write-SubHeader "STATUS DO BITLOCKER"

    $volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
    if (-not $volumes) {
        Write-Status "BitLocker não está disponível neste sistema." "INFO"
        Pause-Script
        return
    }

    foreach ($vol in $volumes) {
        $drive = $vol.MountPoint
        $status = $vol.VolumeStatus
        $protection = $vol.ProtectionStatus

        if ($protection -eq "On") {
            Write-Status "Drive $drive : Criptografado e Protegido" "OK"
        } elseif ($status -eq "FullyEncrypted") {
            Write-Status "Drive $drive : Criptografado (Proteção suspensa)" "WARN"
        } else {
            Write-Status "Drive $drive : NÃO criptografado" "INFO"
        }
    }
    Write-Log "BitLocker verificado."
    Pause-Script
}

function Show-RDPStatus {
    Write-Header
    Write-SubHeader "STATUS DO ACESSO REMOTO (RDP)"

    $rdp = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
    if ($rdp.fDenyTSConnections -eq 0) {
        Write-Status "RDP está HABILITADO neste computador" "WARN"
        $rdpUsers = net localgroup "Usuários da Área de Trabalho Remota" 2>$null
        if (-not $rdpUsers) {
            $rdpUsers = net localgroup "Remote Desktop Users" 2>$null
        }
        Write-Host ""
        Write-Host "   Usuários com acesso RDP:" -ForegroundColor $global:ThemeColor
        Write-Host "   $rdpUsers"
    } else {
        Write-Status "RDP está DESABILITADO" "OK"
    }
    Write-Log "Status RDP verificado."
    Pause-Script
}

function Show-SystemUsers {
    Write-Header
    Write-SubHeader "USUÁRIOS DO SISTEMA"

    $users = Get-LocalUser -ErrorAction SilentlyContinue
    Write-Host "   Nome                    Ativo   Admin   Último Login" -ForegroundColor $global:ThemeColor
    Write-Host "   ----------------------  ------  ------  --------------------" -ForegroundColor DarkGray

    foreach ($u in $users) {
        $isAdmin = (Get-LocalGroupMember -Group "Administradores" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $u.Name }) -ne $null
        if (-not $isAdmin) {
            $isAdmin = (Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $u.Name }) -ne $null
        }
        $adminStr = if ($isAdmin) { "Sim " } else { "Não " }
        $activeStr = if ($u.Enabled) { "Sim " } else { "Não " }
        $lastLogon = if ($u.LastLogon) { $u.LastLogon.ToString("dd/MM/yyyy HH:mm") } else { "Nunca" }
        $name = $u.Name.PadRight(24)
        Write-Host "   $name$($activeStr.PadRight(8))$($adminStr.PadRight(8))$lastLogon"
    }
    Write-Log "Usuários do sistema listados."
    Pause-Script
}

function Show-RecentPrograms {
    Write-Header
    Write-SubHeader "PROGRAMAS INSTALADOS RECENTEMENTE (Últimos 30 dias)"

    $cutoff = (Get-Date).AddDays(-30)
    $programs = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.InstallDate -and $_.DisplayName } |
                ForEach-Object {
                    try {
                        $installDate = [datetime]::ParseExact($_.InstallDate, "yyyyMMdd", $null)
                        if ($installDate -ge $cutoff) {
                            [PSCustomObject]@{ Nome = $_.DisplayName; Data = $installDate.ToString("dd/MM/yyyy") }
                        }
                    } catch {}
                } | Sort-Object Data -Descending

    if ($programs) {
        Write-Host "   Programa                              Data" -ForegroundColor $global:ThemeColor
        Write-Host "   ------------------------------------   ----------" -ForegroundColor DarkGray
        foreach ($p in $programs) {
            $name = $p.Nome
            if ($name.Length -gt 38) { $name = $name.Substring(0, 35) + "..." }
            Write-Host "   $($name.PadRight(40)) $($p.Data)"
        }
    } else {
        Write-Status "Nenhum programa novo instalado nos últimos 30 dias." "INFO"
    }
    Write-Log "Programas recentes listados."
    Pause-Script
}
