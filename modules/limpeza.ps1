# ==============================================================================
# MÓDULO: Limpeza Profunda
# ==============================================================================

function Invoke-MenuLimpeza {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "LIMPEZA PROFUNDA"

        Write-MenuOption "1"  "Limpar Temp do Usuário"
        Write-MenuOption "2"  "Limpar Temp do Windows"
        Write-MenuOption "3"  "Limpar Cache de Thumbnails"
        Write-MenuOption "4"  "Limpar Prefetch"
        Write-MenuOption "5"  "Limpar Logs Antigos do Windows"
        Write-MenuOption "6"  "Limpar Cache do Windows Update"
        Write-MenuOption "7"  "Esvaziar Lixeira"
        Write-MenuOption "8"  "LIMPEZA TOTAL (Modo Turbo - Tudo de uma vez)"
        Write-MenuOption "0"  "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Clean-UserTemp }
            "2" { Clean-WindowsTemp }
            "3" { Clean-Thumbnails }
            "4" { Clean-Prefetch }
            "5" { Clean-EventLogs }
            "6" { Clean-UpdateCache }
            "7" { Clean-RecycleBin }
            "8" { Invoke-TurboClean }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-FolderSizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    return [math]::Round($size / 1MB, 2)
}

function Clean-UserTemp {
    Write-Header
    Write-SubHeader "LIMPAR TEMP DO USUÁRIO"
    $before = Get-FolderSizeMB $env:TEMP
    Write-Host "   Tamanho atual: $($before)MB" -ForegroundColor Gray
    Write-Host "   Limpando..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    $after = Get-FolderSizeMB $env:TEMP
    $freed = [math]::Round($before - $after, 2)
    Write-Status "Liberados: $($freed)MB" "OK"
    Write-Log "Temp do usuário limpo. Liberados: $($freed)MB"
    Pause-Script
}

function Clean-WindowsTemp {
    Write-Header
    Write-SubHeader "LIMPAR TEMP DO WINDOWS"
    $before = Get-FolderSizeMB "$env:WINDIR\Temp"
    Write-Host "   Tamanho atual: $($before)MB" -ForegroundColor Gray
    Write-Host "   Limpando..." -ForegroundColor Yellow
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    $after = Get-FolderSizeMB "$env:WINDIR\Temp"
    $freed = [math]::Round($before - $after, 2)
    Write-Status "Liberados: $($freed)MB" "OK"
    Write-Log "Temp do Windows limpo. Liberados: $($freed)MB"
    Pause-Script
}

function Clean-Thumbnails {
    Write-Header
    Write-SubHeader "LIMPAR CACHE DE THUMBNAILS"
    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    $before = Get-FolderSizeMB $thumbPath
    Write-Host "   Limpando thumbnails..." -ForegroundColor Yellow
    Remove-Item "$thumbPath\thumbcache_*" -Force -ErrorAction SilentlyContinue
    $after = Get-FolderSizeMB $thumbPath
    $freed = [math]::Round($before - $after, 2)
    Write-Status "Cache de thumbnails limpo. Liberados: $($freed)MB" "OK"
    Write-Log "Thumbnails limpos."
    Pause-Script
}

function Clean-Prefetch {
    Write-Header
    Write-SubHeader "LIMPAR PREFETCH"
    $before = Get-FolderSizeMB "$env:WINDIR\Prefetch"
    Write-Host "   Limpando Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Force -ErrorAction SilentlyContinue
    $after = Get-FolderSizeMB "$env:WINDIR\Prefetch"
    $freed = [math]::Round($before - $after, 2)
    Write-Status "Prefetch limpo. Liberados: $($freed)MB" "OK"
    Write-Log "Prefetch limpo."
    Pause-Script
}

function Clean-EventLogs {
    Write-Header
    Write-SubHeader "LIMPAR LOGS DE EVENTOS DO WINDOWS"
    Write-Host "   Limpando todos os logs de eventos..." -ForegroundColor Yellow
    wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
    Write-Status "Logs de eventos limpos!" "OK"
    Write-Log "Event logs limpos."
    Pause-Script
}

function Clean-UpdateCache {
    Write-Header
    Write-SubHeader "LIMPAR CACHE DO WINDOWS UPDATE"
    $updatePath = "$env:WINDIR\SoftwareDistribution\Download"
    $before = Get-FolderSizeMB $updatePath

    Write-Host "   Parando Windows Update..." -ForegroundColor Yellow
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Write-Host "   Limpando cache..." -ForegroundColor Yellow
    Remove-Item -Path "$updatePath\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "   Reiniciando Windows Update..." -ForegroundColor Yellow
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue

    $after = Get-FolderSizeMB $updatePath
    $freed = [math]::Round($before - $after, 2)
    Write-Status "Cache do Update limpo. Liberados: $($freed)MB" "OK"
    Write-Log "Cache do Windows Update limpo."
    Pause-Script
}

function Clean-RecycleBin {
    Write-Header
    Write-SubHeader "ESVAZIAR LIXEIRA"
    Write-Host "   Esvaziando a Lixeira de todos os drives..." -ForegroundColor Yellow
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Status "Lixeira esvaziada!" "OK"
    Write-Log "Lixeira esvaziada."
    Pause-Script
}

function Invoke-TurboClean {
    Write-Header
    Write-SubHeader "LIMPEZA TOTAL - MODO TURBO"
    Write-Host "   Este modo vai executar TODAS as limpezas de uma vez." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Confirma limpeza total? (S/N)"
    if ($confirm -match "^[Ss]") {
        Write-Host ""
        $totalFreed = 0

        # Temp Usuário
        $b = Get-FolderSizeMB $env:TEMP
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        $a = Get-FolderSizeMB $env:TEMP
        $freed = [math]::Round($b - $a, 2); $totalFreed += $freed
        Write-Status "Temp Usuário: $($freed)MB liberados" "OK"

        # Temp Windows
        $b = Get-FolderSizeMB "$env:WINDIR\Temp"
        Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        $a = Get-FolderSizeMB "$env:WINDIR\Temp"
        $freed = [math]::Round($b - $a, 2); $totalFreed += $freed
        Write-Status "Temp Windows: $($freed)MB liberados" "OK"

        # Thumbnails
        $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        $b = Get-FolderSizeMB $thumbPath
        Remove-Item "$thumbPath\thumbcache_*" -Force -ErrorAction SilentlyContinue
        $a = Get-FolderSizeMB $thumbPath
        $freed = [math]::Round($b - $a, 2); $totalFreed += $freed
        Write-Status "Thumbnails: $($freed)MB liberados" "OK"

        # Prefetch
        $b = Get-FolderSizeMB "$env:WINDIR\Prefetch"
        Remove-Item -Path "$env:WINDIR\Prefetch\*" -Force -ErrorAction SilentlyContinue
        $a = Get-FolderSizeMB "$env:WINDIR\Prefetch"
        $freed = [math]::Round($b - $a, 2); $totalFreed += $freed
        Write-Status "Prefetch: $($freed)MB liberados" "OK"

        # Event Logs
        wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
        Write-Status "Event Logs: Limpos" "OK"

        # Update Cache
        $updatePath = "$env:WINDIR\SoftwareDistribution\Download"
        $b = Get-FolderSizeMB $updatePath
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Remove-Item -Path "$updatePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        $a = Get-FolderSizeMB $updatePath
        $freed = [math]::Round($b - $a, 2); $totalFreed += $freed
        Write-Status "Cache Update: $($freed)MB liberados" "OK"

        # Lixeira
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Status "Lixeira: Esvaziada" "OK"

        Write-Host ""
        Write-Host "   ============================================" -ForegroundColor Green
        Write-Host "   TOTAL LIBERADO: ~$([math]::Round($totalFreed, 0))MB" -ForegroundColor Green
        Write-Host "   ============================================" -ForegroundColor Green
        Write-Log "Limpeza Turbo executada. Total liberado: ~$([math]::Round($totalFreed, 0))MB"
    }
    Pause-Script
}
