# ==============================================================================
# MÓDULO: Pós-Formatação - Instalação de Programas
# ==============================================================================

function Invoke-MenuPosFormatacao {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "PÓS-FORMATAÇÃO: INSTALAR PROGRAMAS"
        Write-Host "   Utiliza o Winget (Gerenciador de Pacotes do Windows)" -ForegroundColor Gray
        Write-Host ""

        Write-MenuOption "1" "Pack Essenciais (Chrome, 7zip, VLC, Reader, etc)"
        Write-MenuOption "2" "Pack Runtimes (Visual C++, .NET, Java, DirectX)"
        Write-MenuOption "3" "Pack Escritório (LibreOffice)"
        Write-MenuOption "4" "Pack Suporte Remoto (AnyDesk, RustDesk)"
        Write-MenuOption "5" "Pack Gamer (Steam, Discord, GeForce Experience)"
        Write-MenuOption "6" "Pack Multimídia (OBS, Spotify, GIMP)"
        Write-MenuOption "7" "Pack Utilitários (CPU-Z, CrystalDiskInfo, PowerToys)"
        Write-MenuOption "8" "Instalação Personalizada (escolher um a um)"
        Write-MenuOption "9" "Instalar TUDO (Essenciais + Runtimes)"
        Write-MenuOption "0" "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Install-Pack "Essenciais" $PackEssenciais }
            "2" { Install-Pack "Runtimes" $PackRuntimes }
            "3" { Install-Pack "Escritório" $PackEscritorio }
            "4" { Install-Pack "Suporte Remoto" $PackRemoto }
            "5" { Install-Pack "Gamer" $PackGamer }
            "6" { Install-Pack "Multimídia" $PackMultimidia }
            "7" { Install-Pack "Utilitários" $PackUtilitarios }
            "8" { Install-Custom }
            "9" { Install-Pack "Essenciais + Runtimes" ($PackEssenciais + $PackRuntimes) }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# --- DEFINIÇÃO DOS PACKS ---

$PackEssenciais = @(
    @{ Id="Google.Chrome"; Nome="Google Chrome" },
    @{ Id="Mozilla.Firefox"; Nome="Mozilla Firefox" },
    @{ Id="7zip.7zip"; Nome="7-Zip" },
    @{ Id="Adobe.Acrobat.Reader.64-bit"; Nome="Adobe Acrobat Reader" },
    @{ Id="VideoLAN.VLC"; Nome="VLC Media Player" },
    @{ Id="Notepad++.Notepad++"; Nome="Notepad++" },
    @{ Id="RARLab.WinRAR"; Nome="WinRAR" }
)

$PackRuntimes = @(
    @{ Id="Microsoft.VCRedist.2015+.x64"; Nome="Visual C++ 2015-2022 (x64)" },
    @{ Id="Microsoft.VCRedist.2015+.x86"; Nome="Visual C++ 2015-2022 (x86)" },
    @{ Id="Microsoft.VCRedist.2013.x64"; Nome="Visual C++ 2013 (x64)" },
    @{ Id="Microsoft.VCRedist.2013.x86"; Nome="Visual C++ 2013 (x86)" },
    @{ Id="Microsoft.VCRedist.2012.x64"; Nome="Visual C++ 2012 (x64)" },
    @{ Id="Microsoft.VCRedist.2010.x64"; Nome="Visual C++ 2010 (x64)" },
    @{ Id="Microsoft.DotNet.DesktopRuntime.8"; Nome=".NET Desktop Runtime 8" },
    @{ Id="Oracle.JavaRuntimeEnvironment"; Nome="Java Runtime (JRE)" },
    @{ Id="Microsoft.DirectX"; Nome="DirectX End-User Runtime" }
)

$PackEscritorio = @(
    @{ Id="TheDocumentFoundation.LibreOffice"; Nome="LibreOffice" }
)

$PackRemoto = @(
    @{ Id="AnyDeskSoftwareGmbH.AnyDesk"; Nome="AnyDesk" },
    @{ Id="RustDesk.RustDesk"; Nome="RustDesk" }
)

$PackGamer = @(
    @{ Id="Valve.Steam"; Nome="Steam" },
    @{ Id="Discord.Discord"; Nome="Discord" },
    @{ Id="EpicGames.EpicGamesLauncher"; Nome="Epic Games Launcher" }
)

$PackMultimidia = @(
    @{ Id="OBSProject.OBSStudio"; Nome="OBS Studio" },
    @{ Id="Spotify.Spotify"; Nome="Spotify" },
    @{ Id="GIMP.GIMP"; Nome="GIMP" },
    @{ Id="Audacity.Audacity"; Nome="Audacity" }
)

$PackUtilitarios = @(
    @{ Id="CPUID.CPU-Z"; Nome="CPU-Z" },
    @{ Id="CrystalDewWorld.CrystalDiskInfo"; Nome="CrystalDiskInfo" },
    @{ Id="Microsoft.PowerToys"; Nome="Microsoft PowerToys" },
    @{ Id="voidtools.Everything"; Nome="Everything Search" },
    @{ Id="Microsoft.WindowsTerminal"; Nome="Windows Terminal" }
)

# --- FUNÇÕES ---

function Install-Pack {
    param(
        [string]$PackName,
        [array]$Programs
    )

    Write-Header
    Write-SubHeader "INSTALANDO PACK: $PackName"

    # Verifica winget
    $wingetTest = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetTest) {
        Write-Status "Winget não encontrado! Verifique se o App Installer está instalado." "ERRO"
        Pause-Script
        return
    }

    Write-Host "   Programas neste pack:" -ForegroundColor $global:ThemeColor
    foreach ($p in $Programs) {
        Write-Host "   - $($p.Nome)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "   Total: $($Programs.Count) programas" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   Iniciar instalação? (S/N)"
    if ($confirm -notmatch "^[Ss]") { return }

    Write-Host ""
    Write-Log "Iniciando instalação do pack: $PackName"

    $success = 0
    $fail = 0
    $skip = 0

    foreach ($p in $Programs) {
        Write-Host "   Instalando $($p.Nome)..." -ForegroundColor Yellow -NoNewline

        $result = Start-Process winget -ArgumentList "install --id $($p.Id) --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue

        if ($result.ExitCode -eq 0) {
            Write-Host "`r" -NoNewline
            Write-Status "$($p.Nome) instalado!" "OK"
            $success++
            Write-Log "Instalado: $($p.Nome)"
        } elseif ($result.ExitCode -eq -1978335189) {
            # Já instalado
            Write-Host "`r" -NoNewline
            Write-Status "$($p.Nome) já está instalado" "INFO"
            $skip++
        } else {
            Write-Host "`r" -NoNewline
            Write-Status "$($p.Nome) - falha (código: $($result.ExitCode))" "ERRO"
            $fail++
            Write-Log "Falha ao instalar: $($p.Nome) (Exit: $($result.ExitCode))" "ERRO"
        }
    }

    Write-Host ""
    Write-Host "   ============================================" -ForegroundColor DarkGray
    Write-Host "   Resultado: " -NoNewline
    Write-Host "$success instalados " -NoNewline -ForegroundColor Green
    Write-Host "| $skip já existentes " -NoNewline -ForegroundColor Cyan
    Write-Host "| $fail falharam" -ForegroundColor Red
    Write-Host "   ============================================" -ForegroundColor DarkGray
    Write-Log "Pack $PackName finalizado. OK:$success Skip:$skip Fail:$fail"
    Pause-Script
}

function Install-Custom {
    Write-Header
    Write-SubHeader "INSTALAÇÃO PERSONALIZADA"

    # Monta lista completa
    $allPrograms = @()
    $allPrograms += $PackEssenciais
    $allPrograms += $PackRuntimes
    $allPrograms += $PackEscritorio
    $allPrograms += $PackRemoto
    $allPrograms += $PackGamer
    $allPrograms += $PackMultimidia
    $allPrograms += $PackUtilitarios

    Write-Host "   Selecione os programas (digite os números separados por vírgula):" -ForegroundColor White
    Write-Host ""

    for ($i = 0; $i -lt $allPrograms.Count; $i++) {
        $num = ($i + 1).ToString().PadLeft(2)
        Write-Host "   [$num] $($allPrograms[$i].Nome)"
    }

    Write-Host ""
    $selected = Read-Host "   Números (ex: 1,3,5,12)"
    $indices = $selected -split "," | ForEach-Object { [int]$_.Trim() - 1 }

    $toInstall = @()
    foreach ($idx in $indices) {
        if ($idx -ge 0 -and $idx -lt $allPrograms.Count) {
            $toInstall += $allPrograms[$idx]
        }
    }

    if ($toInstall.Count -gt 0) {
        Install-Pack "Personalizado" $toInstall
    } else {
        Write-Status "Nenhum programa válido selecionado." "WARN"
        Pause-Script
    }
}
