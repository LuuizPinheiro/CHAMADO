# ==============================================================================
# MÓDULO: Reparos e Manutenção
# ==============================================================================

function Invoke-MenuReparos {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "REPAROS E MANUTENÇÃO"

        Write-MenuOption "1"  "SFC /scannow (Verificar Arquivos do Sistema)"
        Write-MenuOption "2"  "DISM RestoreHealth (Reparar Imagem do Windows)"
        Write-MenuOption "3"  "CHKDSK (Verificar Disco)"
        Write-MenuOption "4"  "Reiniciar Spooler de Impressão"
        Write-MenuOption "5"  "Limpar Fila de Impressão"
        Write-MenuOption "6"  "Resetar Windows Update"
        Write-MenuOption "7"  "Reparar Windows Store / Apps UWP"
        Write-MenuOption "8"  "Reconstruir Cache de Ícones"
        Write-MenuOption "9"  "Reparo Completo (SFC + DISM + Store)"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Invoke-SFC }
            "2" { Invoke-DISM }
            "3" { Invoke-CHKDSK }
            "4" { Restart-PrintSpooler }
            "5" { Clear-PrintQueue }
            "6" { Reset-WindowsUpdate }
            "7" { Repair-WindowsStore }
            "8" { Rebuild-IconCache }
            "9" { Invoke-FullRepair }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Invoke-SFC {
    Write-Header
    Write-SubHeader "SFC - VERIFICADOR DE ARQUIVOS DO SISTEMA"
    Write-Host "   Este processo pode levar de 5 a 30 minutos." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Iniciar agora? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host "   Executando SFC /scannow..." -ForegroundColor Yellow
        Write-Host ""
        sfc /scannow
        Write-Log "SFC /scannow executado."
    }
    Pause-Script
}

function Invoke-DISM {
    Write-Header
    Write-SubHeader "DISM - REPARAR IMAGEM DO WINDOWS"
    Write-Host "   Necessita de conexão com a internet." -ForegroundColor Yellow
    Write-Host "   Este processo pode levar de 10 a 40 minutos." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Iniciar agora? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host "   [1/3] Verificando saúde..." -ForegroundColor Gray
        DISM /Online /Cleanup-Image /CheckHealth

        Write-Host ""
        Write-Host "   [2/3] Escaneando imagem..." -ForegroundColor Gray
        DISM /Online /Cleanup-Image /ScanHealth

        Write-Host ""
        Write-Host "   [3/3] Restaurando saúde..." -ForegroundColor Gray
        DISM /Online /Cleanup-Image /RestoreHealth

        Write-Log "DISM RestoreHealth executado."
    }
    Pause-Script
}

function Invoke-CHKDSK {
    Write-Header
    Write-SubHeader "CHKDSK - VERIFICAR DISCO"
    Write-Host "   AVISO: A verificação do disco C: requer reinicialização." -ForegroundColor Yellow
    Write-Host ""

    Write-MenuOption "1" "Verificar disco C: (somente leitura)"
    Write-MenuOption "2" "Agendar verificação com reparo no próximo boot"
    Write-MenuOption "0" "Cancelar"

    $op = Get-Choice

    switch ($op) {
        "1" {
            Write-Host "   Executando verificação (somente leitura)..." -ForegroundColor Yellow
            chkdsk C:
            Write-Log "CHKDSK somente leitura executado."
        }
        "2" {
            Write-Host "   Agendando CHKDSK /F /R para o próximo boot..." -ForegroundColor Yellow
            $chk = Start-Process -FilePath "cmd.exe" -ArgumentList "/c echo S | chkdsk C: /F /R" -Wait -NoNewWindow -PassThru
            Write-Status "CHKDSK agendado. Reinicie o computador para executar." "OK"
            Write-Log "CHKDSK /F /R agendado."
        }
    }
    Pause-Script
}

function Restart-PrintSpooler {
    Write-Header
    Write-SubHeader "REINICIAR SPOOLER DE IMPRESSÃO"

    Write-Host "   Parando o serviço Spooler..." -ForegroundColor Yellow
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "   Iniciando o serviço Spooler..." -ForegroundColor Yellow
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $svc = Get-Service -Name Spooler
    if ($svc.Status -eq "Running") {
        Write-Status "Spooler reiniciado com sucesso!" "OK"
    } else {
        Write-Status "Falha ao reiniciar o Spooler!" "ERRO"
    }
    Write-Log "Spooler reiniciado. Status: $($svc.Status)"
    Pause-Script
}

function Clear-PrintQueue {
    Write-Header
    Write-SubHeader "LIMPAR FILA DE IMPRESSÃO"

    Write-Host "   Parando Spooler e limpando fila..." -ForegroundColor Yellow
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -Path "$env:WINDIR\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Start-Service -Name Spooler -ErrorAction SilentlyContinue

    Write-Status "Fila de impressão limpa e Spooler reiniciado!" "OK"
    Write-Log "Fila de impressão limpa."
    Pause-Script
}

function Reset-WindowsUpdate {
    Write-Header
    Write-SubHeader "RESETAR WINDOWS UPDATE"

    Write-Host "   Parando serviços do Windows Update..." -ForegroundColor Yellow
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name cryptSvc -Force -ErrorAction SilentlyContinue
    Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
    Stop-Service -Name msiserver -Force -ErrorAction SilentlyContinue

    Write-Host "   Renomeando pastas de cache..." -ForegroundColor Yellow
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    Rename-Item "$env:WINDIR\SoftwareDistribution" "SoftwareDistribution.bak.$timestamp" -ErrorAction SilentlyContinue
    Rename-Item "$env:WINDIR\System32\catroot2" "catroot2.bak.$timestamp" -ErrorAction SilentlyContinue

    Write-Host "   Reiniciando serviços..." -ForegroundColor Yellow
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name cryptSvc -ErrorAction SilentlyContinue
    Start-Service -Name bits -ErrorAction SilentlyContinue
    Start-Service -Name msiserver -ErrorAction SilentlyContinue

    Write-Status "Windows Update resetado com sucesso!" "OK"
    Write-Host "   Tente verificar atualizações novamente." -ForegroundColor Gray
    Write-Log "Windows Update resetado."
    Pause-Script
}

function Repair-WindowsStore {
    Write-Header
    Write-SubHeader "REPARAR WINDOWS STORE / APPS UWP"

    Write-Host "   [1/2] Limpando cache da Store..." -ForegroundColor Yellow
    Start-Process wsreset.exe -Wait -ErrorAction SilentlyContinue
    
    Write-Host "   [2/2] Reregistrando todos os apps..." -ForegroundColor Yellow
    Get-AppxPackage -AllUsers | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
    }

    Write-Status "Windows Store reparada!" "OK"
    Write-Log "Windows Store reparada."
    Pause-Script
}

function Rebuild-IconCache {
    Write-Header
    Write-SubHeader "RECONSTRUIR CACHE DE ÍCONES"

    Write-Host "   Fechando o Explorer..." -ForegroundColor Yellow
    taskkill /f /im explorer.exe 2>$null | Out-Null
    Start-Sleep -Seconds 2

    Write-Host "   Removendo cache de ícones..." -ForegroundColor Yellow
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*" -Force -ErrorAction SilentlyContinue

    Write-Host "   Reiniciando Explorer..." -ForegroundColor Yellow
    Start-Process explorer.exe
    Start-Sleep -Seconds 2

    Write-Status "Cache de ícones reconstruído!" "OK"
    Write-Log "Cache de ícones reconstruído."
    Pause-Script
}

function Invoke-FullRepair {
    Write-Header
    Write-SubHeader "REPARO COMPLETO (SFC + DISM + STORE)"
    Write-Host "   Executando sequência completa de reparos." -ForegroundColor Yellow
    Write-Host "   Isso pode levar de 20 a 60 minutos." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Confirma? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host ""
        Write-Host "   [ETAPA 1/3] DISM RestoreHealth" -ForegroundColor $global:ThemeColor
        DISM /Online /Cleanup-Image /RestoreHealth

        Write-Host ""
        Write-Host "   [ETAPA 2/3] SFC /scannow" -ForegroundColor $global:ThemeColor
        sfc /scannow

        Write-Host ""
        Write-Host "   [ETAPA 3/3] Reparando Windows Store" -ForegroundColor $global:ThemeColor
        Get-AppxPackage -AllUsers | ForEach-Object {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Status "Reparo completo finalizado!" "OK"
        Write-Host "   Recomendamos reiniciar o computador." -ForegroundColor Yellow
        Write-Log "Reparo completo (DISM + SFC + Store) executado."
    }
    Pause-Script
}
