# ==============================================================================
# MÓDULO: Backup Rápido (Ninja Backup)
# ==============================================================================

function Invoke-MenuBackup {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "NINJA BACKUP - BACKUP RÁPIDO"

        Write-MenuOption "1" "Backup de Pastas do Usuário (Documentos, Desktop, Downloads)"
        Write-MenuOption "2" "Backup de Drivers Instalados"
        Write-MenuOption "3" "Exportar Perfis Wi-Fi (com senhas)"
        Write-MenuOption "4" "Restaurar Perfis Wi-Fi (de backup)"
        Write-MenuOption "5" "Exportar Lista de Programas Instalados"
        Write-MenuOption "6" "Backup Completo (Tudo acima)"
        Write-MenuOption "0" "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Backup-UserFolders }
            "2" { Backup-Drivers }
            "3" { Export-WifiProfiles }
            "4" { Import-WifiProfiles }
            "5" { Export-ProgramList }
            "6" { Invoke-FullBackup }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-BackupDrive {
    Write-Host ""
    Write-Host "   Drives disponíveis:" -ForegroundColor $global:ThemeColor

    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=2 OR DriveType=3" | Where-Object { $_.DeviceID -ne "C:" }
    if (-not $drives) {
        Write-Status "Nenhum drive externo ou secundário encontrado!" "WARN"
        Write-Host "   Conecte um pendrive ou HD externo." -ForegroundColor Yellow
        $custom = Read-Host "   Ou digite o caminho manualmente (ex: D:\Backup)"
        return $custom
    }

    foreach ($d in $drives) {
        $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        Write-Host "   $($d.DeviceID) - $($d.VolumeName) ($($freeGB)GB livre de $($totalGB)GB)" -ForegroundColor White
    }

    $chosen = Read-Host "`n   Escolha o drive de destino (ex: D)"
    $destDrive = "$($chosen.Trim().TrimEnd(':')):"
    $destPath = Join-Path $destDrive "CHAMADO_Backup_$(Get-Date -Format 'yyyyMMdd')"

    if (-not (Test-Path $destDrive)) {
        Write-Status "Drive $destDrive não encontrado!" "ERRO"
        return $null
    }

    if (-not (Test-Path $destPath)) {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    }

    return $destPath
}

function Backup-UserFolders {
    Write-Header
    Write-SubHeader "BACKUP DE PASTAS DO USUÁRIO"

    $dest = Get-BackupDrive
    if (-not $dest) { Pause-Script; return }

    $folders = @(
        @{ Source = [Environment]::GetFolderPath("Desktop"); Name = "Desktop" },
        @{ Source = [Environment]::GetFolderPath("MyDocuments"); Name = "Documentos" },
        @{ Source = (Join-Path $env:USERPROFILE "Downloads"); Name = "Downloads" },
        @{ Source = [Environment]::GetFolderPath("MyPictures"); Name = "Imagens" }
    )

    foreach ($f in $folders) {
        if (Test-Path $f.Source) {
            $target = Join-Path $dest $f.Name
            Write-Host "   Copiando $($f.Name)..." -ForegroundColor Yellow
            robocopy $f.Source $target /E /R:1 /W:1 /NP /NDL /NJH /NJS 2>$null | Out-Null
            Write-Status "$($f.Name) copiado!" "OK"
        } else {
            Write-Status "$($f.Name): pasta não encontrada" "WARN"
        }
    }

    Write-Host ""
    Write-Status "Backup salvo em: $dest" "OK"
    Write-Log "Backup de pastas do usuário em: $dest"
    Pause-Script
}

function Backup-Drivers {
    Write-Header
    Write-SubHeader "BACKUP DE DRIVERS"

    $dest = Get-BackupDrive
    if (-not $dest) { Pause-Script; return }

    $driverDest = Join-Path $dest "Drivers"
    if (-not (Test-Path $driverDest)) {
        New-Item -ItemType Directory -Path $driverDest -Force | Out-Null
    }

    Write-Host "   Exportando drivers instalados (pode demorar)..." -ForegroundColor Yellow
    $result = Start-Process dism -ArgumentList "/online /export-driver /destination:`"$driverDest`"" -Wait -NoNewWindow -PassThru

    if ($result.ExitCode -eq 0) {
        $count = (Get-ChildItem $driverDest -Directory).Count
        Write-Status "Drivers exportados: $count drivers em $driverDest" "OK"
    } else {
        Write-Status "Ocorreu um erro ao exportar drivers" "ERRO"
    }
    Write-Log "Backup de drivers em: $driverDest"
    Pause-Script
}

function Export-WifiProfiles {
    Write-Header
    Write-SubHeader "EXPORTAR PERFIS WI-FI"

    $dest = Get-BackupDrive
    if (-not $dest) { Pause-Script; return }

    $wifiDest = Join-Path $dest "WiFi_Profiles"
    if (-not (Test-Path $wifiDest)) {
        New-Item -ItemType Directory -Path $wifiDest -Force | Out-Null
    }

    Write-Host "   Exportando perfis Wi-Fi..." -ForegroundColor Yellow
    netsh wlan export profile key=clear folder="$wifiDest" 2>$null | Out-Null

    $count = (Get-ChildItem $wifiDest -Filter "*.xml").Count
    Write-Status "Exportados $count perfis Wi-Fi para: $wifiDest" "OK"
    Write-Log "Perfis Wi-Fi exportados: $count perfis."
    Pause-Script
}

function Import-WifiProfiles {
    Write-Header
    Write-SubHeader "RESTAURAR PERFIS WI-FI (DE BACKUP)"

    $source = Read-Host "   Caminho da pasta com os XMLs (ex: D:\CHAMADO_Backup\WiFi_Profiles)"
    if (-not (Test-Path $source)) {
        Write-Status "Pasta não encontrada: $source" "ERRO"
        Pause-Script
        return
    }

    $xmls = Get-ChildItem $source -Filter "*.xml"
    if ($xmls.Count -eq 0) {
        Write-Status "Nenhum arquivo XML encontrado na pasta!" "WARN"
        Pause-Script
        return
    }

    Write-Host "   Importando $($xmls.Count) perfis..." -ForegroundColor Yellow
    foreach ($xml in $xmls) {
        netsh wlan add profile filename="$($xml.FullName)" user=all 2>$null | Out-Null
        Write-Status "Importado: $($xml.BaseName)" "OK"
    }

    Write-Log "Perfis Wi-Fi restaurados: $($xmls.Count) perfis."
    Pause-Script
}

function Export-ProgramList {
    Write-Header
    Write-SubHeader "EXPORTAR LISTA DE PROGRAMAS INSTALADOS"

    $dest = Get-BackupDrive
    if (-not $dest) { Pause-Script; return }

    $listFile = Join-Path $dest "programas_instalados.txt"

    Write-Host "   Coletando lista de programas..." -ForegroundColor Yellow

    $programs = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } |
                Sort-Object DisplayName |
                Select-Object DisplayName, DisplayVersion, Publisher |
                ForEach-Object { "$($_.DisplayName) | v$($_.DisplayVersion) | $($_.Publisher)" }

    $header = "CHAMADO - Lista de Programas Instalados`nGerado em: $(Get-Date)`nTotal: $($programs.Count) programas`n`n"
    $content = $header + ($programs -join "`n")
    Set-Content -Path $listFile -Value $content -Force

    Write-Status "Lista salva com $($programs.Count) programas em: $listFile" "OK"
    Write-Log "Lista de programas exportada: $($programs.Count) programas."
    Pause-Script
}

function Invoke-FullBackup {
    Write-Header
    Write-SubHeader "BACKUP COMPLETO (NINJA MODE)"

    $dest = Get-BackupDrive
    if (-not $dest) { Pause-Script; return }

    Write-Host "   Executando backup completo..." -ForegroundColor Yellow
    Write-Host ""

    # Pastas do usuário
    $folders = @(
        @{ Source = [Environment]::GetFolderPath("Desktop"); Name = "Desktop" },
        @{ Source = [Environment]::GetFolderPath("MyDocuments"); Name = "Documentos" },
        @{ Source = (Join-Path $env:USERPROFILE "Downloads"); Name = "Downloads" },
        @{ Source = [Environment]::GetFolderPath("MyPictures"); Name = "Imagens" }
    )
    foreach ($f in $folders) {
        if (Test-Path $f.Source) {
            $target = Join-Path $dest $f.Name
            Write-Host "   Copiando $($f.Name)..." -ForegroundColor Gray
            robocopy $f.Source $target /E /R:1 /W:1 /NP /NDL /NJH /NJS 2>$null | Out-Null
            Write-Status "$($f.Name)" "OK"
        }
    }

    # Drivers
    $driverDest = Join-Path $dest "Drivers"
    New-Item -ItemType Directory -Path $driverDest -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   Exportando drivers..." -ForegroundColor Gray
    Start-Process dism -ArgumentList "/online /export-driver /destination:`"$driverDest`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
    Write-Status "Drivers" "OK"

    # Wi-Fi
    $wifiDest = Join-Path $dest "WiFi_Profiles"
    New-Item -ItemType Directory -Path $wifiDest -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   Exportando perfis Wi-Fi..." -ForegroundColor Gray
    netsh wlan export profile key=clear folder="$wifiDest" 2>$null | Out-Null
    Write-Status "Perfis Wi-Fi" "OK"

    # Lista de programas
    $listFile = Join-Path $dest "programas_instalados.txt"
    Write-Host "   Exportando lista de programas..." -ForegroundColor Gray
    $programs = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } | Sort-Object DisplayName |
                ForEach-Object { "$($_.DisplayName) | v$($_.DisplayVersion)" }
    Set-Content -Path $listFile -Value ($programs -join "`n") -Force
    Write-Status "Lista de programas" "OK"

    Write-Host ""
    Write-Host "   ============================================" -ForegroundColor Green
    Write-Host "   BACKUP COMPLETO finalizado!" -ForegroundColor Green
    Write-Host "   Salvo em: $dest" -ForegroundColor Green
    Write-Host "   ============================================" -ForegroundColor Green
    Write-Log "Backup completo Ninja Mode executado em: $dest"
    Pause-Script
}
