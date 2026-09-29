# ==============================================================================
# MÓDULO: Personalização de Tema
# ==============================================================================

function Invoke-MenuTema {
    Write-Header
    Write-SubHeader "PERSONALIZAR TEMA"

    Write-Host "   Tema atual: " -NoNewline
    Write-Host "$($global:ThemeColor)" -ForegroundColor $global:ThemeColor
    Write-Host ""
    Write-Host "   Escolha a nova cor:" -ForegroundColor White
    Write-Host ""

    Write-Host "   [1] " -ForegroundColor White -NoNewline
    Write-Host "Verde Matrix (Padrão)" -ForegroundColor Green

    Write-Host "   [2] " -ForegroundColor White -NoNewline
    Write-Host "Ciano Tech" -ForegroundColor Cyan

    Write-Host "   [3] " -ForegroundColor White -NoNewline
    Write-Host "Amarelo Alerta" -ForegroundColor Yellow

    Write-Host "   [4] " -ForegroundColor White -NoNewline
    Write-Host "Vermelho Fogo" -ForegroundColor Red

    Write-Host "   [5] " -ForegroundColor White -NoNewline
    Write-Host "Magenta Neon" -ForegroundColor Magenta

    Write-Host "   [6] " -ForegroundColor White -NoNewline
    Write-Host "Branco Clean" -ForegroundColor White

    Write-Host ""
    Write-Host "   [0] Voltar" -ForegroundColor DarkGray

    $c = Get-Choice

    $newColor = switch ($c) {
        "1" { "Green" }
        "2" { "Cyan" }
        "3" { "Yellow" }
        "4" { "Red" }
        "5" { "Magenta" }
        "6" { "White" }
        default { $null }
    }

    if ($newColor) {
        $global:ThemeColor = $newColor
        Set-Content -Path $global:CfgFile -Value $newColor -Force
        Write-Log "Tema alterado para $newColor"
        Write-Host ""
        Write-Host "   Tema aplicado!" -ForegroundColor $newColor
        Pause-Script
    }
}
