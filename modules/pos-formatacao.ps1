# ==============================================================================
# MÓDULO: Pós-Formatação - Instalação de Programas (Winget)
# ==============================================================================
# Catálogo organizado por categorias + Packs prontos por perfil de uso.
# Para adicionar um programa: inclua @{ Id="Winget.Id"; Nome="Nome" } na
# categoria desejada. Programas da Microsoft Store usam Fonte="msstore".
# Para descobrir o Id: winget search "nome do programa"
# ==============================================================================

$script:CatalogoProgramas = @(
    @{ Categoria = "Navegadores"; Programas = @(
        @{ Id = "Google.Chrome";        Nome = "Google Chrome" },
        @{ Id = "Mozilla.Firefox";      Nome = "Mozilla Firefox" },
        @{ Id = "Brave.Brave";          Nome = "Brave Browser" },
        @{ Id = "Opera.Opera";          Nome = "Opera" },
        @{ Id = "Opera.OperaGX";        Nome = "Opera GX" },
        @{ Id = "Vivaldi.Vivaldi";      Nome = "Vivaldi" }
    )},
    @{ Categoria = "Compactadores e Utilitários Básicos"; Programas = @(
        @{ Id = "7zip.7zip";            Nome = "7-Zip" },
        @{ Id = "RARLab.WinRAR";        Nome = "WinRAR" },
        @{ Id = "Giorgiotani.Peazip";   Nome = "PeaZip" },
        @{ Id = "Notepad++.Notepad++";  Nome = "Notepad++" },
        @{ Id = "voidtools.Everything"; Nome = "Everything (Busca Instantânea)" },
        @{ Id = "Microsoft.PowerToys";  Nome = "Microsoft PowerToys" },
        @{ Id = "ShareX.ShareX";        Nome = "ShareX (Print de Tela)" },
        @{ Id = "Greenshot.Greenshot";  Nome = "Greenshot (Print de Tela)" },
        @{ Id = "LocalSend.LocalSend";  Nome = "LocalSend (Enviar arquivos pela rede)" }
    )},
    @{ Categoria = "Escritório e PDF"; Programas = @(
        @{ Id = "TheDocumentFoundation.LibreOffice"; Nome = "LibreOffice" },
        @{ Id = "ONLYOFFICE.DesktopEditors";         Nome = "ONLYOFFICE (compatível com MS Office)" },
        @{ Id = "Kingsoft.WPSOffice";                Nome = "WPS Office" },
        @{ Id = "Microsoft.Office";                  Nome = "Microsoft 365 / Office (requer licença)" },
        @{ Id = "Adobe.Acrobat.Reader.64-bit";       Nome = "Adobe Acrobat Reader" },
        @{ Id = "Foxit.FoxitReader";                 Nome = "Foxit PDF Reader" },
        @{ Id = "SumatraPDF.SumatraPDF";             Nome = "Sumatra PDF (leve)" },
        @{ Id = "PDFsam.PDFsam";                     Nome = "PDFsam (Juntar/Dividir PDF)" },
        @{ Id = "Notion.Notion";                     Nome = "Notion" },
        @{ Id = "Obsidian.Obsidian";                 Nome = "Obsidian (Anotações)" }
    )},
    @{ Categoria = "Comunicação"; Programas = @(
        @{ Id = "9NKSQGP7F2NH";              Nome = "WhatsApp Desktop"; Fonte = "msstore" },
        @{ Id = "Telegram.TelegramDesktop";  Nome = "Telegram" },
        @{ Id = "Discord.Discord";           Nome = "Discord" },
        @{ Id = "Zoom.Zoom";                 Nome = "Zoom" },
        @{ Id = "Microsoft.Teams";           Nome = "Microsoft Teams" },
        @{ Id = "SlackTechnologies.Slack";   Nome = "Slack" },
        @{ Id = "Mozilla.Thunderbird";       Nome = "Thunderbird (E-mail)" }
    )},
    @{ Categoria = "Multimídia (Áudio e Vídeo)"; Programas = @(
        @{ Id = "VideoLAN.VLC";                        Nome = "VLC Media Player" },
        @{ Id = "CodecGuide.K-LiteCodecPack.Standard"; Nome = "K-Lite Codec Pack" },
        @{ Id = "clsid2.mpc-hc";                       Nome = "MPC-HC (Player)" },
        @{ Id = "Spotify.Spotify";                     Nome = "Spotify (instalar sem Admin)" },
        @{ Id = "PeterPawlowski.foobar2000";           Nome = "foobar2000" },
        @{ Id = "Audacity.Audacity";                   Nome = "Audacity (Editor de Áudio)" },
        @{ Id = "OBSProject.OBSStudio";                Nome = "OBS Studio (Gravar/Transmitir)" },
        @{ Id = "HandBrake.HandBrake";                 Nome = "HandBrake (Converter Vídeo)" },
        @{ Id = "Meltytech.Shotcut";                   Nome = "Shotcut (Editor de Vídeo)" }
    )},
    @{ Categoria = "Imagem e Design"; Programas = @(
        @{ Id = "IrfanSkiljan.IrfanView";   Nome = "IrfanView (Visualizador)" },
        @{ Id = "XnSoft.XnViewMP";          Nome = "XnView MP (Visualizador)" },
        @{ Id = "dotPDN.PaintDotNet";       Nome = "Paint.NET" },
        @{ Id = "GIMP.GIMP";                Nome = "GIMP" },
        @{ Id = "Inkscape.Inkscape";        Nome = "Inkscape (Vetores)" },
        @{ Id = "KDE.Krita";                Nome = "Krita (Desenho)" },
        @{ Id = "BlenderFoundation.Blender"; Nome = "Blender (3D)" },
        @{ Id = "Figma.Figma";              Nome = "Figma" }
    )},
    @{ Categoria = "Acesso Remoto e Rede"; Programas = @(
        @{ Id = "AnyDeskSoftwareGmbH.AnyDesk";     Nome = "AnyDesk" },
        @{ Id = "RustDesk.RustDesk";               Nome = "RustDesk" },
        @{ Id = "TeamViewer.TeamViewer";           Nome = "TeamViewer" },
        @{ Id = "Google.ChromeRemoteDesktopHost";  Nome = "Chrome Remote Desktop" },
        @{ Id = "mRemoteNG.mRemoteNG";             Nome = "mRemoteNG (RDP/SSH)" },
        @{ Id = "PuTTY.PuTTY";                     Nome = "PuTTY (SSH)" },
        @{ Id = "WinSCP.WinSCP";                   Nome = "WinSCP (SFTP)" },
        @{ Id = "TimKosse.FileZilla.Client";       Nome = "FileZilla (FTP)" },
        @{ Id = "Famatech.AdvancedIPScanner";      Nome = "Advanced IP Scanner" },
        @{ Id = "WiresharkFoundation.Wireshark";   Nome = "Wireshark" }
    )},
    @{ Categoria = "Jogos"; Programas = @(
        @{ Id = "Valve.Steam";                 Nome = "Steam" },
        @{ Id = "EpicGames.EpicGamesLauncher"; Nome = "Epic Games Launcher" },
        @{ Id = "ElectronicArts.EADesktop";    Nome = "EA App" },
        @{ Id = "Ubisoft.Connect";             Nome = "Ubisoft Connect" },
        @{ Id = "GOG.Galaxy";                  Nome = "GOG Galaxy" },
        @{ Id = "Playnite.Playnite";           Nome = "Playnite (Biblioteca unificada)" },
        @{ Id = "Guru3D.Afterburner";          Nome = "MSI Afterburner" }
    )},
    @{ Categoria = "Runtimes e Dependências"; Programas = @(
        @{ Id = "Microsoft.VCRedist.2015+.x64";      Nome = "Visual C++ 2015-2022 (x64)" },
        @{ Id = "Microsoft.VCRedist.2015+.x86";      Nome = "Visual C++ 2015-2022 (x86)" },
        @{ Id = "Microsoft.VCRedist.2013.x64";       Nome = "Visual C++ 2013 (x64)" },
        @{ Id = "Microsoft.VCRedist.2013.x86";       Nome = "Visual C++ 2013 (x86)" },
        @{ Id = "Microsoft.VCRedist.2012.x64";       Nome = "Visual C++ 2012 (x64)" },
        @{ Id = "Microsoft.VCRedist.2012.x86";       Nome = "Visual C++ 2012 (x86)" },
        @{ Id = "Microsoft.VCRedist.2010.x64";       Nome = "Visual C++ 2010 (x64)" },
        @{ Id = "Microsoft.VCRedist.2010.x86";       Nome = "Visual C++ 2010 (x86)" },
        @{ Id = "Microsoft.VCRedist.2008.x64";       Nome = "Visual C++ 2008 (x64)" },
        @{ Id = "Microsoft.VCRedist.2008.x86";       Nome = "Visual C++ 2008 (x86)" },
        @{ Id = "Microsoft.DotNet.DesktopRuntime.8"; Nome = ".NET Desktop Runtime 8" },
        @{ Id = "Microsoft.DotNet.DesktopRuntime.9"; Nome = ".NET Desktop Runtime 9" },
        @{ Id = "Oracle.JavaRuntimeEnvironment";     Nome = "Java Runtime (JRE 8)" },
        @{ Id = "EclipseAdoptium.Temurin.21.JRE";    Nome = "Java 21 (Temurin JRE)" },
        @{ Id = "Microsoft.DirectX";                 Nome = "DirectX End-User Runtime" }
    )},
    @{ Categoria = "Ferramentas do Técnico (Hardware e Diagnóstico)"; Programas = @(
        @{ Id = "CPUID.CPU-Z";                      Nome = "CPU-Z" },
        @{ Id = "TechPowerUp.GPU-Z";                Nome = "GPU-Z" },
        @{ Id = "REALiX.HWiNFO";                    Nome = "HWiNFO" },
        @{ Id = "CPUID.HWMonitor";                  Nome = "HWMonitor (Temperaturas)" },
        @{ Id = "CrystalDewWorld.CrystalDiskInfo";  Nome = "CrystalDiskInfo (Saúde do Disco)" },
        @{ Id = "CrystalDewWorld.CrystalDiskMark";  Nome = "CrystalDiskMark (Velocidade do Disco)" },
        @{ Id = "AntibodySoftware.WizTree";         Nome = "WizTree (Espaço em Disco)" },
        @{ Id = "RevoUninstaller.RevoUninstaller";  Nome = "Revo Uninstaller" },
        @{ Id = "BleachBit.BleachBit";              Nome = "BleachBit (Limpeza)" },
        @{ Id = "Rufus.Rufus";                      Nome = "Rufus (Pendrive Bootável)" },
        @{ Id = "Ventoy.Ventoy";                    Nome = "Ventoy (Multi-Boot USB)" },
        @{ Id = "Microsoft.Sysinternals.Autoruns";  Nome = "Autoruns (Sysinternals)" },
        @{ Id = "Microsoft.Sysinternals.ProcessExplorer"; Nome = "Process Explorer (Sysinternals)" }
    )},
    @{ Categoria = "Segurança e Privacidade"; Programas = @(
        @{ Id = "Malwarebytes.Malwarebytes";  Nome = "Malwarebytes" },
        @{ Id = "Bitwarden.Bitwarden";        Nome = "Bitwarden (Senhas)" },
        @{ Id = "KeePassXCTeam.KeePassXC";    Nome = "KeePassXC (Senhas offline)" },
        @{ Id = "Proton.ProtonVPN";           Nome = "Proton VPN" },
        @{ Id = "Cloudflare.Warp";            Nome = "Cloudflare WARP (1.1.1.1)" },
        @{ Id = "IDRIX.VeraCrypt";            Nome = "VeraCrypt (Criptografia)" }
    )},
    @{ Categoria = "Nuvem e Downloads"; Programas = @(
        @{ Id = "Google.GoogleDrive";              Nome = "Google Drive" },
        @{ Id = "Dropbox.Dropbox";                 Nome = "Dropbox" },
        @{ Id = "Microsoft.OneDrive";              Nome = "Microsoft OneDrive" },
        @{ Id = "qBittorrent.qBittorrent";         Nome = "qBittorrent" },
        @{ Id = "Tonec.InternetDownloadManager";   Nome = "Internet Download Manager (pago)" }
    )},
    @{ Categoria = "Desenvolvimento"; Programas = @(
        @{ Id = "Microsoft.VisualStudioCode"; Nome = "Visual Studio Code" },
        @{ Id = "Git.Git";                    Nome = "Git" },
        @{ Id = "GitHub.GitHubDesktop";       Nome = "GitHub Desktop" },
        @{ Id = "Python.Python.3.12";         Nome = "Python 3.12" },
        @{ Id = "OpenJS.NodeJS.LTS";          Nome = "Node.js LTS" },
        @{ Id = "Microsoft.WindowsTerminal";  Nome = "Windows Terminal" },
        @{ Id = "Docker.DockerDesktop";       Nome = "Docker Desktop" },
        @{ Id = "Postman.Postman";            Nome = "Postman" }
    )}
)

# Packs prontos (referenciam os Ids do catálogo)
$script:PacksProntos = @(
    @{ Nome = "Básico Casa (recomendado p/ todo PC)"; Ids = @(
        "Google.Chrome", "7zip.7zip", "VideoLAN.VLC", "Adobe.Acrobat.Reader.64-bit", "9NKSQGP7F2NH", "AnyDeskSoftwareGmbH.AnyDesk",
        "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86", "Microsoft.DotNet.DesktopRuntime.8", "Microsoft.DirectX") },
    @{ Nome = "Escritório / Empresa"; Ids = @(
        "Google.Chrome", "Mozilla.Firefox", "7zip.7zip", "ONLYOFFICE.DesktopEditors", "Adobe.Acrobat.Reader.64-bit", "PDFsam.PDFsam",
        "Zoom.Zoom", "Microsoft.Teams", "AnyDeskSoftwareGmbH.AnyDesk", "Oracle.JavaRuntimeEnvironment",
        "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86", "Microsoft.DotNet.DesktopRuntime.8") },
    @{ Nome = "Gamer"; Ids = @(
        "Valve.Steam", "EpicGames.EpicGamesLauncher", "Discord.Discord", "Guru3D.Afterburner", "OBSProject.OBSStudio",
        "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86", "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCRedist.2012.x64", "Microsoft.VCRedist.2010.x64", "Microsoft.VCRedist.2008.x86",
        "Microsoft.DotNet.DesktopRuntime.8", "Microsoft.DirectX") },
    @{ Nome = "Técnico de Informática"; Ids = @(
        "CPUID.CPU-Z", "TechPowerUp.GPU-Z", "REALiX.HWiNFO", "CrystalDewWorld.CrystalDiskInfo", "CrystalDewWorld.CrystalDiskMark",
        "AntibodySoftware.WizTree", "RevoUninstaller.RevoUninstaller", "Rufus.Rufus", "Ventoy.Ventoy",
        "Famatech.AdvancedIPScanner", "AnyDeskSoftwareGmbH.AnyDesk", "RustDesk.RustDesk", "Microsoft.Sysinternals.Autoruns", "Malwarebytes.Malwarebytes") },
    @{ Nome = "Criador de Conteúdo"; Ids = @(
        "OBSProject.OBSStudio", "Meltytech.Shotcut", "HandBrake.HandBrake", "Audacity.Audacity", "GIMP.GIMP", "Inkscape.Inkscape",
        "KDE.Krita", "CodecGuide.K-LiteCodecPack.Standard") },
    @{ Nome = "Desenvolvedor"; Ids = @(
        "Microsoft.VisualStudioCode", "Git.Git", "GitHub.GitHubDesktop", "Python.Python.3.12", "OpenJS.NodeJS.LTS",
        "Microsoft.WindowsTerminal", "Postman.Postman", "Notepad++.Notepad++") },
    @{ Nome = "Todos os Runtimes (resolve erros de DLL faltando)"; Ids = @(
        "Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86", "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86",
        "Microsoft.VCRedist.2012.x64", "Microsoft.VCRedist.2012.x86", "Microsoft.VCRedist.2010.x64", "Microsoft.VCRedist.2010.x86",
        "Microsoft.VCRedist.2008.x64", "Microsoft.VCRedist.2008.x86", "Microsoft.DotNet.DesktopRuntime.8", "Microsoft.DotNet.DesktopRuntime.9",
        "Oracle.JavaRuntimeEnvironment", "Microsoft.DirectX") }
)

# ------------------------------------------------------------------------------
# MENUS
# ------------------------------------------------------------------------------

function Invoke-MenuPosFormatacao {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "PÓS-FORMATAÇÃO: INSTALAR PROGRAMAS"
        $total = ($script:CatalogoProgramas | ForEach-Object { $_.Programas.Count } | Measure-Object -Sum).Sum
        Write-Host "   Utiliza o Winget (Gerenciador de Pacotes do Windows) | $total programas no catálogo" -ForegroundColor Gray
        Write-Host ""

        Write-MenuOption "1" "Packs Prontos (por perfil de uso)"
        Write-MenuOption "2" "Navegar por Categorias"
        Write-MenuOption "3" "Instalação Personalizada (todas as categorias)"
        Write-MenuOption "4" "Buscar e Instalar Qualquer Programa (Winget)"
        Write-MenuOption "5" "Atualizar TODOS os Programas Instalados"
        Write-MenuOption "6" "Verificar / Reparar o Winget"
        Write-MenuOption "0" "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Invoke-MenuPacksProntos }
            "2" { Invoke-MenuCategorias }
            "3" { Install-Custom }
            "4" { Search-WingetProgram }
            "5" { Update-AllPrograms }
            "6" { Repair-Winget -Interactive }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-ProgramById {
    param([string]$Id)
    foreach ($cat in $script:CatalogoProgramas) {
        foreach ($p in $cat.Programas) { if ($p.Id -eq $Id) { return $p } }
    }
    return @{ Id = $Id; Nome = $Id }
}

function Invoke-MenuPacksProntos {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "PACKS PRONTOS"
        for ($i = 0; $i -lt $script:PacksProntos.Count; $i++) {
            $pk = $script:PacksProntos[$i]
            Write-MenuOption "$($i + 1)" "$($pk.Nome) - $($pk.Ids.Count) programas"
        }
        Write-MenuOption "0" "Voltar"

        $op = Get-Choice
        if ($op -eq "0") { $loop = $false; continue }
        if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $script:PacksProntos.Count) {
            $pk = $script:PacksProntos[[int]$op - 1]
            $progs = @($pk.Ids | ForEach-Object { Get-ProgramById $_ })
            Install-Pack $pk.Nome $progs
        } else {
            Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1
        }
    }
}

function Invoke-MenuCategorias {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "CATEGORIAS"
        for ($i = 0; $i -lt $script:CatalogoProgramas.Count; $i++) {
            $c = $script:CatalogoProgramas[$i]
            Write-MenuOption "$(($i + 1).ToString().PadLeft(2))" "$($c.Categoria) ($($c.Programas.Count))"
        }
        Write-MenuOption " 0" "Voltar"

        $op = Get-Choice
        if ($op -eq "0") { $loop = $false; continue }
        if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $script:CatalogoProgramas.Count) {
            Show-CategoryPrograms $script:CatalogoProgramas[[int]$op - 1]
        } else {
            Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1
        }
    }
}

function ConvertFrom-Selection {
    <# Converte "1,3,5-8" em índices (base 0). "T" = todos. #>
    param([string]$Text, [int]$Max)
    $result = New-Object System.Collections.Generic.List[int]
    if ($Text -match '^\s*[Tt]') { for ($i = 0; $i -lt $Max; $i++) { $result.Add($i) }; return $result.ToArray() }
    foreach ($part in ($Text -split '[,; ]+')) {
        $part = $part.Trim()
        if ($part -match '^(\d+)\s*-\s*(\d+)$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            if ($a -gt $b) { $t = $a; $a = $b; $b = $t }
            for ($n = $a; $n -le $b; $n++) { if ($n -ge 1 -and $n -le $Max -and -not $result.Contains($n - 1)) { $result.Add($n - 1) } }
        } elseif ($part -match '^\d+$') {
            $n = [int]$part
            if ($n -ge 1 -and $n -le $Max -and -not $result.Contains($n - 1)) { $result.Add($n - 1) }
        }
    }
    return $result.ToArray()
}

function Show-CategoryPrograms {
    param($Category)
    Write-Header
    Write-SubHeader "CATEGORIA: $($Category.Categoria)"

    $progs = @($Category.Programas)
    for ($i = 0; $i -lt $progs.Count; $i++) {
        $num = ($i + 1).ToString().PadLeft(2)
        Write-Host "   [$num] " -ForegroundColor $global:ThemeColor -NoNewline
        Write-Host $progs[$i].Nome -ForegroundColor White
    }
    Write-Host ""
    Write-Host "   Exemplos: 1,3,5  |  2-6  |  T = todos  |  0 = voltar" -ForegroundColor DarkGray
    $sel = Read-Host "   Quais instalar"
    if ([string]::IsNullOrWhiteSpace($sel) -or $sel.Trim() -eq "0") { return }

    $idx = @(ConvertFrom-Selection $sel $progs.Count)
    if ($idx.Count -eq 0) { Write-Status "Nenhum programa válido selecionado." "WARN"; Pause-Script; return }
    Install-Pack $Category.Categoria @($idx | ForEach-Object { $progs[$_] })
}

function Install-Custom {
    Write-Header
    Write-SubHeader "INSTALAÇÃO PERSONALIZADA"

    $all = @()
    $n = 1
    foreach ($cat in $script:CatalogoProgramas) {
        Write-Host "   --- $($cat.Categoria) ---" -ForegroundColor $global:ThemeColor
        $line = ""
        foreach ($p in $cat.Programas) {
            $all += $p
            $cell = ("[{0,3}] {1}" -f $n, $p.Nome)
            if ($cell.Length -gt 45) { $cell = $cell.Substring(0, 44) + "~" }
            if ($line) { Write-Host ("   " + $line.PadRight(47) + $cell); $line = "" } else { $line = $cell }
            $n++
        }
        if ($line) { Write-Host ("   " + $line) }
    }

    Write-Host ""
    Write-Host "   Exemplos: 1,3,5  |  10-15  |  0 = voltar" -ForegroundColor DarkGray
    $selected = Read-Host "   Números"
    if ([string]::IsNullOrWhiteSpace($selected) -or $selected.Trim() -eq "0") { return }

    $idx = @(ConvertFrom-Selection $selected $all.Count)
    if ($idx.Count -gt 0) {
        Install-Pack "Personalizado" @($idx | ForEach-Object { $all[$_] })
    } else {
        Write-Status "Nenhum programa válido selecionado." "WARN"
        Pause-Script
    }
}

# ------------------------------------------------------------------------------
# WINGET
# ------------------------------------------------------------------------------

function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Quando o CHAMADO roda como Admin, o alias do usuário pode não estar no PATH
    $alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path $alias) { return $alias }
    $pkg = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($pkg) { return $pkg.FullName }
    return $null
}

function Repair-Winget {
    param([switch]$Interactive)
    if ($Interactive) { Write-Header; Write-SubHeader "VERIFICAR / REPARAR WINGET" }

    $path = Get-WingetPath
    if ($path) {
        $ver = & $path --version 2>$null
        Write-Status "Winget encontrado: $ver" "OK"
        if ($Interactive) {
            Write-Host "   Atualizando fontes de pacotes..." -ForegroundColor Gray
            & $path source reset --force 2>$null | Out-Null
            & $path source update 2>$null | Out-Null
            Write-Status "Fontes atualizadas." "OK"
            Pause-Script
        }
        return $path
    }

    Write-Status "Winget não encontrado. Tentando instalar/registrar..." "WARN"

    # 1) Registrar o App Installer já presente no sistema
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        Start-Sleep -Seconds 3
    } catch { }
    $path = Get-WingetPath
    if ($path) { Write-Status "Winget registrado com sucesso!" "OK"; if ($Interactive) { Pause-Script }; return $path }

    # 2) Download do App Installer + dependências
    $tmp = Join-Path $env:TEMP "chamado_winget"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $files = @(
        @{ Url = "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx"; File = "vclibs.appx" },
        @{ Url = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.$arch.appx"; File = "uixaml.appx" },
        @{ Url = "https://aka.ms/getwinget"; File = "winget.msixbundle" }
    )
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        foreach ($f in $files) {
            Write-Host "   Baixando $($f.File)..." -ForegroundColor Gray
            $dest = Join-Path $tmp $f.File
            (New-Object Net.WebClient).DownloadFile($f.Url, $dest)
        }
        foreach ($f in $files) {
            Write-Host "   Instalando $($f.File)..." -ForegroundColor Gray
            Add-AppxPackage -Path (Join-Path $tmp $f.File) -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Status "Falha no download: $($_.Exception.Message)" "ERRO"
    }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

    $path = Get-WingetPath
    if ($path) { Write-Status "Winget instalado com sucesso!" "OK" }
    else {
        Write-Status "Não foi possível instalar o Winget automaticamente." "ERRO"
        Write-Host "   Instale o 'Instalador de Aplicativo' pela Microsoft Store e tente novamente." -ForegroundColor Yellow
        $o = Read-Host "   Abrir a Microsoft Store agora? (S/N)"
        if ($o -match '^[Ss]') { Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction SilentlyContinue }
    }
    if ($Interactive) { Pause-Script }
    return $path
}

function Install-Pack {
    param(
        [string]$PackName,
        [array]$Programs
    )

    Write-Header
    Write-SubHeader "INSTALANDO: $PackName"

    $winget = Get-WingetPath
    if (-not $winget) { $winget = Repair-Winget }
    if (-not $winget) { Pause-Script; return }

    Write-Host "   Programas selecionados:" -ForegroundColor $global:ThemeColor
    foreach ($p in $Programs) { Write-Host "   - $($p.Nome)" -ForegroundColor White }
    Write-Host ""
    Write-Host "   Total: $($Programs.Count) programas" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "   Iniciar instalação? (S/N)"
    if ($confirm -notmatch "^[Ss]") { return }

    Write-Host ""
    Write-Log "Iniciando instalação: $PackName"

    $success = 0; $fail = 0; $skip = 0
    $failed = @()
    $n = 0

    foreach ($p in $Programs) {
        $n++
        Write-Host ""
        Write-Host "   [$n/$($Programs.Count)] Instalando $($p.Nome)..." -ForegroundColor Yellow

        $source = if ($p.Fonte) { $p.Fonte } else { "winget" }
        $wgArgs = "install --id `"$($p.Id)`" --exact --source $source --silent --accept-package-agreements --accept-source-agreements"
        $code = -1
        try {
            $proc = Start-Process -FilePath $winget -ArgumentList $wgArgs -Wait -NoNewWindow -PassThru -ErrorAction Stop
            $code = $proc.ExitCode
        } catch { $code = -1 }

        switch ($code) {
            0            { Write-Status "$($p.Nome) instalado!" "OK"; $success++; Write-Log "Instalado: $($p.Nome)" }
            -1978335189  { Write-Status "$($p.Nome) já está instalado e atualizado" "INFO"; $skip++ }
            -1978335135  { Write-Status "$($p.Nome) já está instalado" "INFO"; $skip++ }
            -1978334967  { Write-Status "$($p.Nome) instalado (reinicialização necessária)" "OK"; $success++ }
            -1978335212  { Write-Status "$($p.Nome) - pacote não encontrado no Winget" "ERRO"; $fail++; $failed += $p.Nome }
            default {
                Write-Status "$($p.Nome) - falha (código: $code)" "ERRO"
                $fail++; $failed += $p.Nome
                Write-Log "Falha ao instalar: $($p.Nome) (Exit: $code)" "ERRO"
            }
        }
    }

    Write-Host ""
    Write-Host "   ============================================" -ForegroundColor DarkGray
    Write-Host "   Resultado: " -NoNewline
    Write-Host "$success instalados " -NoNewline -ForegroundColor Green
    Write-Host "| $skip já existentes " -NoNewline -ForegroundColor Cyan
    Write-Host "| $fail falharam" -ForegroundColor Red
    Write-Host "   ============================================" -ForegroundColor DarkGray
    if ($failed.Count -gt 0) {
        Write-Host "   Falharam: $($failed -join ', ')" -ForegroundColor DarkGray
        Write-Host "   Dica: rode a opção 6 (Reparar Winget) e tente novamente." -ForegroundColor DarkGray
    }
    Write-Log "Pack $PackName finalizado. OK:$success Skip:$skip Fail:$fail"
    Pause-Script
}

function Search-WingetProgram {
    Write-Header
    Write-SubHeader "BUSCAR PROGRAMA NO WINGET"

    $winget = Get-WingetPath
    if (-not $winget) { $winget = Repair-Winget }
    if (-not $winget) { Pause-Script; return }

    $term = Read-Host "   Nome do programa (ex: photoshop, java, zoom)"
    if ([string]::IsNullOrWhiteSpace($term)) { return }

    Write-Host ""
    & $winget search "$term" --source winget --accept-source-agreements
    Write-Host ""
    $id = Read-Host "   Copie o 'ID' do programa desejado (ou Enter para voltar)"
    if ([string]::IsNullOrWhiteSpace($id)) { return }

    Install-Pack "Busca: $term" @(@{ Id = $id.Trim(); Nome = $id.Trim() })
}

function Update-AllPrograms {
    Write-Header
    Write-SubHeader "ATUALIZAR TODOS OS PROGRAMAS"

    $winget = Get-WingetPath
    if (-not $winget) { $winget = Repair-Winget }
    if (-not $winget) { Pause-Script; return }

    Write-Host "   Verificando atualizações disponíveis..." -ForegroundColor Gray
    Write-Host ""
    & $winget upgrade --source winget --accept-source-agreements
    Write-Host ""
    $c = Read-Host "   Atualizar todos os programas listados? (S/N)"
    if ($c -notmatch '^[Ss]') { return }

    Write-Host ""
    $proc = Start-Process -FilePath $winget -ArgumentList "upgrade --all --source winget --silent --accept-package-agreements --accept-source-agreements --include-unknown" -Wait -NoNewWindow -PassThru
    Write-Host ""
    if ($proc.ExitCode -eq 0) { Write-Status "Atualização concluída!" "OK" }
    else { Write-Status "Atualização finalizada com avisos (código: $($proc.ExitCode))" "WARN" }
    Write-Log "Winget upgrade --all executado (Exit: $($proc.ExitCode))"
    Pause-Script
}
