# ==============================================================================
# MÓDULO: Analisador de Disco (Arquivos e Pastas)
# ==============================================================================
# Usa um scanner proprio (.NET) em vez de Get-ChildItem -Recurse, pois o
# Get-ChildItem falha em varios PCs (pastas protegidas, caminhos longos,
# junctions em loop, falta de memoria ao ordenar milhoes de arquivos).
# ==============================================================================

$script:DiskScannerCode = @"
using System;
using System.IO;
using System.Collections.Generic;

public class ChamadoFileEntry {
    public string FullName;
    public string Name;
    public long Length;
    public string Extension;
}

public class ChamadoDiskScanner {
    private Stack<string[]> _stack = new Stack<string[]>();
    private int _topN;
    private int _topPerExt;

    public List<ChamadoFileEntry> TopFiles = new List<ChamadoFileEntry>();
    public Dictionary<string, long> ExtSize  = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, long> ExtCount = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, List<ChamadoFileEntry>> ExtTop = new Dictionary<string, List<ChamadoFileEntry>>(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, long> FolderSize = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
    public long TotalSize = 0;
    public long TotalFiles = 0;
    public long TotalDirs = 0;
    public long Errors = 0;
    public string RootFilesKey = "[Arquivos soltos na raiz]";

    public ChamadoDiskScanner(string root, int topN, int topPerExt) {
        _topN = topN;
        _topPerExt = topPerExt;
        _stack.Push(new string[] { root, null });
    }

    public bool Step(int maxDirs) {
        int processed = 0;
        while (_stack.Count > 0 && processed < maxDirs) {
            string[] item = _stack.Pop();
            processed++;
            TotalDirs++;
            ProcessDir(item[0], item[1]);
        }
        return _stack.Count == 0;
    }

    private void ProcessDir(string dir, string topKey) {
        IEnumerator<FileSystemInfo> en = null;
        try { en = new DirectoryInfo(dir).EnumerateFileSystemInfos().GetEnumerator(); }
        catch { Errors++; return; }

        try {
            while (true) {
                FileSystemInfo fsi = null;
                try {
                    if (!en.MoveNext()) break;
                    fsi = en.Current;
                } catch { Errors++; break; }

                try {
                    FileAttributes a = fsi.Attributes;
                    if ((a & FileAttributes.Directory) == FileAttributes.Directory) {
                        // Ignora junctions/symlinks para evitar loops e contagem duplicada
                        if ((a & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint) continue;
                        _stack.Push(new string[] { fsi.FullName, topKey ?? fsi.FullName });
                    } else {
                        FileInfo fi = fsi as FileInfo;
                        if (fi == null) continue;
                        long len = fi.Length;
                        string ext = fi.Extension;
                        ext = String.IsNullOrEmpty(ext) ? "(sem extensao)" : ext.ToLowerInvariant();

                        ChamadoFileEntry e = new ChamadoFileEntry();
                        e.FullName = fi.FullName;
                        e.Name = fi.Name;
                        e.Length = len;
                        e.Extension = ext;

                        TotalFiles++;
                        TotalSize += len;
                        AddTop(TopFiles, e, _topN);

                        long v;
                        ExtSize.TryGetValue(ext, out v);  ExtSize[ext] = v + len;
                        ExtCount.TryGetValue(ext, out v); ExtCount[ext] = v + 1;

                        List<ChamadoFileEntry> lst;
                        if (!ExtTop.TryGetValue(ext, out lst)) { lst = new List<ChamadoFileEntry>(); ExtTop[ext] = lst; }
                        AddTop(lst, e, _topPerExt);

                        string fk = topKey ?? RootFilesKey;
                        FolderSize.TryGetValue(fk, out v); FolderSize[fk] = v + len;
                    }
                } catch { Errors++; }
            }
        } finally {
            if (en != null) { try { en.Dispose(); } catch { } }
        }
    }

    private static void AddTop(List<ChamadoFileEntry> list, ChamadoFileEntry e, int max) {
        if (max <= 0) return;
        if (list.Count < max) { list.Add(e); return; }
        int minIdx = 0;
        for (int i = 1; i < list.Count; i++) {
            if (list[i].Length < list[minIdx].Length) minIdx = i;
        }
        if (e.Length > list[minIdx].Length) list[minIdx] = e;
    }
}
"@

function Initialize-DiskScanner {
    if (([System.Management.Automation.PSTypeName]'ChamadoDiskScanner').Type) { return $true }
    try {
        Add-Type -TypeDefinition $script:DiskScannerCode -Language CSharp -ErrorAction Stop
    } catch { }
    return [bool](([System.Management.Automation.PSTypeName]'ChamadoDiskScanner').Type)
}

function Invoke-DiskScan {
    <#
        Escaneia uma pasta/drive de forma resiliente e retorna um objeto com:
        TopFiles, ExtSize, ExtCount, ExtTop, FolderSize, TotalSize, TotalFiles, TotalDirs, Errors
    #>
    param(
        [string]$Path,
        [int]$TopN = 20,
        [int]$TopPerExt = 15
    )

    # Garante barra final (\"C:\" sem barra = pasta atual do drive C!)
    $root = $Path.Trim().Trim('"')
    if ($root -match '^[A-Za-z]:$') { $root = "$root\" }
    if (-not $root.EndsWith("\")) { $root = "$root\" }

    $start = Get-Date

    if (Initialize-DiskScanner) {
        $scanner = New-Object ChamadoDiskScanner($root, $TopN, $TopPerExt)
        $done = $false
        while (-not $done) {
            $done = $scanner.Step(150)
            $elapsed = [int]((Get-Date) - $start).TotalSeconds
            $line = "   Arquivos: {0:N0} | Pastas: {1:N0} | Lido: {2} | {3}s" -f $scanner.TotalFiles, $scanner.TotalDirs, (Format-FileSize $scanner.TotalSize), $elapsed
            Write-Host ("`r" + $line.PadRight(78)) -NoNewline -ForegroundColor DarkGray
        }
        Write-Host ("`r" + (" " * 80) + "`r") -NoNewline

        return [PSCustomObject]@{
            TopFiles   = @($scanner.TopFiles | Sort-Object Length -Descending)
            ExtSize    = $scanner.ExtSize
            ExtCount   = $scanner.ExtCount
            ExtTop     = $scanner.ExtTop
            FolderSize = $scanner.FolderSize
            TotalSize  = $scanner.TotalSize
            TotalFiles = $scanner.TotalFiles
            TotalDirs  = $scanner.TotalDirs
            Errors     = $scanner.Errors
            Seconds    = [int]((Get-Date) - $start).TotalSeconds
        }
    }

    # ---------- Fallback 100% PowerShell (se Add-Type estiver bloqueado) ----------
    $topFiles   = New-Object System.Collections.ArrayList
    $extSize    = @{}
    $extCount   = @{}
    $extTop     = @{}
    $folderSize = @{}
    $totalSize  = [long]0
    $totalFiles = [long]0
    $totalDirs  = [long]0
    $errors     = [long]0
    $rootKey    = "[Arquivos soltos na raiz]"

    $stack = New-Object System.Collections.Stack
    $stack.Push(@($root, $null))

    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        $dir = $item[0]; $topKey = $item[1]
        $totalDirs++

        $entries = $null
        try { $entries = ([System.IO.DirectoryInfo]$dir).GetFileSystemInfos() } catch { $errors++; continue }

        foreach ($fsi in $entries) {
            try {
                $attr = [int]$fsi.Attributes
                if ($attr -band 16) {
                    if ($attr -band 1024) { continue }   # ReparsePoint
                    $k = if ($topKey) { $topKey } else { $fsi.FullName }
                    $stack.Push(@($fsi.FullName, $k))
                } else {
                    $len = [long]$fsi.Length
                    $ext = if ($fsi.Extension) { $fsi.Extension.ToLower() } else { "(sem extensao)" }
                    $entry = [PSCustomObject]@{ FullName = $fsi.FullName; Name = $fsi.Name; Length = $len; Extension = $ext }

                    $totalFiles++; $totalSize += $len
                    Add-TopEntry $topFiles $entry $TopN

                    $extSize[$ext]  = [long]$extSize[$ext] + $len
                    $extCount[$ext] = [long]$extCount[$ext] + 1
                    if (-not $extTop.ContainsKey($ext)) { $extTop[$ext] = New-Object System.Collections.ArrayList }
                    Add-TopEntry $extTop[$ext] $entry $TopPerExt

                    $fk = if ($topKey) { $topKey } else { $rootKey }
                    $folderSize[$fk] = [long]$folderSize[$fk] + $len
                }
            } catch { $errors++ }
        }

        if (($totalDirs % 200) -eq 0) {
            $line = "   Arquivos: {0:N0} | Pastas: {1:N0} | Lido: {2}" -f $totalFiles, $totalDirs, (Format-FileSize $totalSize)
            Write-Host ("`r" + $line.PadRight(78)) -NoNewline -ForegroundColor DarkGray
        }
    }
    Write-Host ("`r" + (" " * 80) + "`r") -NoNewline

    return [PSCustomObject]@{
        TopFiles   = @($topFiles | Sort-Object Length -Descending)
        ExtSize    = $extSize
        ExtCount   = $extCount
        ExtTop     = $extTop
        FolderSize = $folderSize
        TotalSize  = $totalSize
        TotalFiles = $totalFiles
        TotalDirs  = $totalDirs
        Errors     = $errors
        Seconds    = [int]((Get-Date) - $start).TotalSeconds
    }
}

function Add-TopEntry {
    param($List, $Entry, [int]$Max)
    if ($Max -le 0) { return }
    if ($List.Count -lt $Max) { [void]$List.Add($Entry); return }
    $minIdx = 0
    for ($i = 1; $i -lt $List.Count; $i++) {
        if ($List[$i].Length -lt $List[$minIdx].Length) { $minIdx = $i }
    }
    if ($Entry.Length -gt $List[$minIdx].Length) { $List[$minIdx] = $Entry }
}

function Write-ScanFooter {
    param($Scan)
    Write-Host ""
    Write-Host ("   Escaneados: {0:N0} arquivos em {1:N0} pastas ({2}) em {3}s" -f $Scan.TotalFiles, $Scan.TotalDirs, (Format-FileSize $Scan.TotalSize), $Scan.Seconds) -ForegroundColor DarkGray
    if ($Scan.Errors -gt 0) {
        Write-Host ("   {0:N0} itens sem permissao de acesso foram ignorados (normal em pastas do sistema)." -f $Scan.Errors) -ForegroundColor DarkGray
    }
}

function Write-NoFilesHelp {
    param($Scan, [string]$Path)
    Write-Status "Nenhum arquivo encontrado em $Path." "WARN"
    if ($Scan -and $Scan.Errors -gt 0) {
        Write-Host "   O acesso foi negado em $($Scan.Errors) itens." -ForegroundColor Yellow
        Write-Host "   Execute o CHAMADO como Administrador (pelo CHAMADO.bat)." -ForegroundColor Yellow
    }
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-MenuAnalisadorDisco {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "ANALISADOR DE DISCO"

        if (-not (Test-IsAdmin)) {
            Write-Host "   [!] Sem privilegios de Administrador: algumas pastas serao ignoradas." -ForegroundColor Yellow
            Write-Host ""
        }

        Write-MenuOption "1" "Top 20 Maiores Arquivos do Disco"
        Write-MenuOption "2" "Top 20 Maiores Pastas"
        Write-MenuOption "3" "Análise por Tipo de Arquivo (Vídeos, Imagens, etc)"
        Write-MenuOption "4" "Escanear uma Pasta Específica"
        Write-MenuOption "5" "Resumo Geral de Todos os Drives"
        Write-MenuOption "0" "Voltar ao Menu Principal"

        $op = Get-Choice

        switch ($op) {
            "1" { Find-LargestFiles }
            "2" { Find-LargestFolders }
            "3" { Analyze-FileTypes }
            "4" { Scan-SpecificFolder }
            "5" { Show-DrivesSummary }
            "0" { $loop = $false }
            default { Write-Host "   Opção inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-AvailableDrives {
    # Usa .NET DriveInfo (nao depende de WMI, que costuma estar corrompido)
    $list = @()
    try {
        foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
            $ready = $false
            try { $ready = $d.IsReady } catch { }
            if (-not $ready) { continue }
            if ($d.DriveType -notin @('Fixed', 'Removable', 'Network')) { continue }
            $list += [PSCustomObject]@{
                Letter = $d.Name.TrimEnd('\')
                Label  = $d.VolumeLabel
                Type   = "$($d.DriveType)"
                Size   = [long]$d.TotalSize
                Free   = [long]$d.AvailableFreeSpace
            }
        }
    } catch { }

    if ($list.Count -eq 0) {
        # Fallback: PSDrive
        foreach ($p in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            if ($p.Root -notmatch '^[A-Za-z]:\\$') { continue }
            $used = [long]$p.Used; $free = [long]$p.Free
            $list += [PSCustomObject]@{ Letter = "$($p.Name):"; Label = $p.Description; Type = "Fixed"; Size = $used + $free; Free = $free }
        }
    }
    return $list
}

function Select-Drive {
    $drives = @(Get-AvailableDrives)
    Write-Host ""
    Write-Host "   Drives disponíveis:" -ForegroundColor $global:ThemeColor
    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.Free / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        $usedPerc = if ($d.Size -gt 0) { [math]::Round((($d.Size - $d.Free) / $d.Size) * 100) } else { 0 }
        $tipo = switch ($d.Type) { "Removable" { " (USB)" } "Network" { " (Rede)" } default { "" } }
        Write-Host "   $($d.Letter) [$($d.Label)]$tipo - $($freeGB)GB livre de $($totalGB)GB ($($usedPerc)% usado)" -ForegroundColor White
    }
    Write-Host ""
    $default = if ($drives.Count -gt 0) { ($drives | Where-Object { $_.Letter -eq $env:SystemDrive } | Select-Object -First 1).Letter } else { $null }
    if (-not $default) { $default = $env:SystemDrive }

    $chosen = Read-Host "   Escolha o drive (Enter = $default)"
    if ([string]::IsNullOrWhiteSpace($chosen)) { $chosen = $default }
    $clean = $chosen.Trim().TrimEnd(':','\')
    if ($clean -notmatch '^[A-Za-z]$') {
        Write-Status "Drive inválido! Digite apenas a letra (ex: C)." "ERRO"
        return $null
    }
    $driveLetter = "$($clean.ToUpper()):"
    if (Test-Path -LiteralPath "$driveLetter\") {
        return $driveLetter
    } else {
        Write-Status "Drive não encontrado!" "ERRO"
        return $null
    }
}

function Format-FileSize {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return "$([math]::Round($Bytes / 1TB, 2)) TB" }
    elseif ($Bytes -ge 1GB) { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
    elseif ($Bytes -ge 1MB) { return "$([math]::Round($Bytes / 1MB, 1)) MB" }
    elseif ($Bytes -ge 1KB) { return "$([math]::Round($Bytes / 1KB, 0)) KB" }
    else { return "$([long]$Bytes) B" }
}

function Format-ShortPath {
    param([string]$Path, [int]$Max = 52)
    if ($Path.Length -gt $Max) { return "..." + $Path.Substring($Path.Length - ($Max - 3)) }
    return $Path
}

function Open-InExplorer {
    param([string]$Path, [switch]$Select)
    try {
        if ($Select) { Start-Process explorer.exe -ArgumentList "/select,`"$Path`"" }
        else { Start-Process explorer.exe -ArgumentList "`"$Path`"" }
        Write-Status "Aberto no Explorer!" "OK"
    } catch {
        Write-Status "Nao foi possivel abrir o Explorer." "ERRO"
    }
}

function Find-LargestFiles {
    Write-Header
    Write-SubHeader "TOP 20 MAIORES ARQUIVOS"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Escaneando $drive (pode demorar em discos grandes)..." -ForegroundColor Yellow
    Write-Host ""

    $scan = Invoke-DiskScan -Path $drive -TopN 20 -TopPerExt 0
    $files = @($scan.TopFiles)

    if ($files.Count -eq 0) {
        Write-NoFilesHelp $scan $drive
        Pause-Script
        return
    }

    Write-Host "   #   Tamanho      Arquivo" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $files) {
        $size = (Format-FileSize $f.Length).PadRight(12)
        $num = $i.ToString().PadLeft(2)
        $color = if ($f.Length -ge 1GB) { "Red" } elseif ($f.Length -ge 100MB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $(Format-ShortPath $f.FullName)" -ForegroundColor $color
        $i++
    }

    Write-ScanFooter $scan
    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? Digite o número (ou 0 para voltar)"
    if ($openChoice -match "^\d+$" -and $openChoice -ne "0") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $files.Count) { Open-InExplorer $files[$idx].FullName -Select }
    }

    Write-Log "Top 20 maiores arquivos listados em $drive ($($scan.TotalFiles) arquivos, $($scan.Errors) erros de acesso)"
    Pause-Script
}

function Find-LargestFolders {
    Write-Header
    Write-SubHeader "TOP 20 MAIORES PASTAS"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Calculando tamanho das pastas em $drive (pode demorar)..." -ForegroundColor Yellow
    Write-Host ""

    $scan = Invoke-DiskScan -Path $drive -TopN 0 -TopPerExt 0

    $sorted = @($scan.FolderSize.GetEnumerator() |
        ForEach-Object { [PSCustomObject]@{ Path = $_.Key; Size = [long]$_.Value } } |
        Sort-Object Size -Descending | Select-Object -First 20)

    if ($sorted.Count -eq 0) {
        Write-NoFilesHelp $scan $drive
        Pause-Script
        return
    }

    Write-Host "   #   Tamanho      Pasta" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $sorted) {
        $size = (Format-FileSize $f.Size).PadRight(12)
        $num = $i.ToString().PadLeft(2)
        $color = if ($f.Size -ge 10GB) { "Red" } elseif ($f.Size -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $(Format-ShortPath $f.Path)" -ForegroundColor $color
        $i++
    }

    Write-ScanFooter $scan
    Write-Host ""
    $openChoice = Read-Host "   Abrir alguma pasta? Digite o número (ou 0 para voltar)"
    if ($openChoice -match "^\d+$" -and $openChoice -ne "0") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $sorted.Count) {
            $target = $sorted[$idx].Path
            if (-not (Test-Path -LiteralPath $target)) { $target = "$drive\" }
            Open-InExplorer $target
        }
    }

    Write-Log "Top 20 maiores pastas listadas em $drive"
    Pause-Script
}

function Get-FileTypeCategories {
    # Ordenado para que cada extensao pertenca a apenas UMA categoria
    return [ordered]@{
        "Vídeos"      = @(".mp4",".avi",".mkv",".mov",".wmv",".flv",".webm",".m4v",".ts",".mpg",".mpeg",".3gp",".vob")
        "Imagens"     = @(".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".tif",".svg",".ico",".raw",".psd",".heic",".cr2",".nef")
        "Músicas"     = @(".mp3",".wav",".flac",".aac",".ogg",".wma",".m4a",".opus")
        "Documentos"  = @(".pdf",".doc",".docx",".xls",".xlsx",".ppt",".pptx",".txt",".odt",".ods",".odp",".csv",".rtf")
        "Compactados" = @(".zip",".rar",".7z",".tar",".gz",".bz2",".xz",".cab")
        "Imagens ISO" = @(".iso",".img",".bin",".cue",".vhd",".vhdx",".vmdk",".nsp",".xci")
        "Executáveis" = @(".exe",".msi",".msix",".appx",".bat",".cmd",".ps1",".dll",".sys")
        "Temporários" = @(".tmp",".temp",".log",".dmp",".bak",".old",".etl",".cache")
    }
}

function Analyze-FileTypes {
    Write-Header
    Write-SubHeader "ANÁLISE POR TIPO DE ARQUIVO"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Escaneando $drive por tipos de arquivo (pode demorar)..." -ForegroundColor Yellow
    Write-Host ""

    $scan = Invoke-DiskScan -Path $drive -TopN 0 -TopPerExt 15

    if ($scan.TotalFiles -eq 0) {
        Write-NoFilesHelp $scan $drive
        Pause-Script
        return
    }

    $categories = Get-FileTypeCategories
    $results = @()
    $knownExts = @{}

    foreach ($cat in $categories.Keys) {
        $size = [long]0; $count = [long]0
        $top = New-Object System.Collections.ArrayList
        foreach ($ext in $categories[$cat]) {
            $knownExts[$ext] = $true
            if ($scan.ExtSize.ContainsKey($ext)) {
                $size  += [long]$scan.ExtSize[$ext]
                $count += [long]$scan.ExtCount[$ext]
                foreach ($e in $scan.ExtTop[$ext]) { [void]$top.Add($e) }
            }
        }
        if ($count -gt 0) {
            $results += [PSCustomObject]@{
                Categoria = $cat
                Arquivos  = $count
                Tamanho   = $size
                Lista     = @($top | Sort-Object Length -Descending | Select-Object -First 15)
            }
        }
    }

    $results = @($results | Sort-Object Tamanho -Descending)

    Write-Host "   Categoria            Arquivos     Tamanho" -ForegroundColor $global:ThemeColor
    Write-Host "   -------------------  -----------  ----------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($r in $results) {
        $catName = $r.Categoria.PadRight(16)
        $count   = ("{0:N0}" -f $r.Arquivos).PadRight(12)
        $size    = Format-FileSize $r.Tamanho
        $color   = if ($r.Tamanho -ge 10GB) { "Red" } elseif ($r.Tamanho -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   [$i] $catName $count $size" -ForegroundColor $color
        $i++
    }

    # Outros
    $othersSize = [long]0; $othersCount = [long]0
    foreach ($k in @($scan.ExtSize.Keys)) {
        if (-not $knownExts.ContainsKey($k)) {
            $othersSize  += [long]$scan.ExtSize[$k]
            $othersCount += [long]$scan.ExtCount[$k]
        }
    }
    if ($othersCount -gt 0) {
        Write-Host "   [-] $("Outros".PadRight(16)) $(("{0:N0}" -f $othersCount).PadRight(12)) $(Format-FileSize $othersSize)" -ForegroundColor DarkGray
    }

    # Top 5 extensoes que mais ocupam
    Write-Host ""
    Write-Host "   Extensoes que mais ocupam espaco:" -ForegroundColor $global:ThemeColor
    $scan.ExtSize.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "   $($_.Key.PadRight(16)) $(Format-FileSize $_.Value)" -ForegroundColor Gray
    }

    Write-ScanFooter $scan
    Write-Host ""

    $detail = Read-Host "   Ver detalhes de qual categoria? (Número, ou 0 para voltar)"
    if ($detail -match "^\d+$" -and $detail -ne "0") {
        $idx = [int]$detail - 1
        if ($idx -ge 0 -and $idx -lt $results.Count) {
            Show-CategoryDetail $results[$idx]
        }
    }

    Write-Log "Análise por tipo de arquivo em $drive"
    Pause-Script
}

function Show-CategoryDetail {
    param($CategoryResult)

    Write-Header
    Write-SubHeader "DETALHES: $($CategoryResult.Categoria)"
    Write-Host "   Total: $("{0:N0}" -f $CategoryResult.Arquivos) arquivos ($(Format-FileSize $CategoryResult.Tamanho))" -ForegroundColor White
    Write-Host ""

    $topFiles = @($CategoryResult.Lista)

    Write-Host "   #   Tamanho      Arquivo" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $topFiles) {
        $size = (Format-FileSize $f.Length).PadRight(12)
        $num = $i.ToString().PadLeft(2)
        Write-Host "   $num  $size  $(Format-ShortPath $f.FullName)" -ForegroundColor White
        $i++
    }

    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? (Número, ou 0 para voltar)"
    if ($openChoice -match "^\d+$" -and $openChoice -ne "0") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $topFiles.Count) { Open-InExplorer $topFiles[$idx].FullName -Select }
    }
}

function Scan-SpecificFolder {
    Write-Header
    Write-SubHeader "ESCANEAR PASTA ESPECÍFICA"

    Write-Host "   Atalhos: [1] Meu usuario  [2] Downloads  [3] Area de Trabalho  [4] Documentos" -ForegroundColor DarkGray
    $folderPath = Read-Host "   Caminho da pasta (ex: C:\Users) ou atalho"
    $folderPath = switch ($folderPath.Trim()) {
        "1" { $env:USERPROFILE }
        "2" { Join-Path $env:USERPROFILE "Downloads" }
        "3" { [Environment]::GetFolderPath("Desktop") }
        "4" { [Environment]::GetFolderPath("MyDocuments") }
        default { $folderPath.Trim().Trim('"') }
    }

    if ([string]::IsNullOrWhiteSpace($folderPath) -or -not (Test-Path -LiteralPath $folderPath -PathType Container)) {
        Write-Status "Pasta não encontrada!" "ERRO"
        Pause-Script
        return
    }
    if ($folderPath -match '^[A-Za-z]:$') { $folderPath = "$folderPath\" }

    Write-Host ""
    Write-Host "   Escaneando $folderPath ..." -ForegroundColor Yellow
    Write-Host ""

    $scan = Invoke-DiskScan -Path $folderPath -TopN 10 -TopPerExt 0

    if ($scan.TotalFiles -eq 0) {
        Write-NoFilesHelp $scan $folderPath
        Pause-Script
        return
    }

    Write-Host "   Total: $("{0:N0}" -f $scan.TotalFiles) arquivos ($(Format-FileSize $scan.TotalSize))" -ForegroundColor White
    Write-Host ""

    Write-Host "   --- Subpastas por tamanho ---" -ForegroundColor $global:ThemeColor
    $subSizes = @($scan.FolderSize.GetEnumerator() |
        ForEach-Object { [PSCustomObject]@{ Path = $_.Key; Size = [long]$_.Value } } |
        Sort-Object Size -Descending | Select-Object -First 15)

    $i = 1
    foreach ($s in $subSizes) {
        $num  = $i.ToString().PadLeft(2)
        $size = (Format-FileSize $s.Size).PadRight(12)
        $name = Split-Path $s.Path -Leaf
        if (-not $name) { $name = $s.Path }
        if ($name.Length -gt 45) { $name = $name.Substring(0, 42) + "..." }
        $color = if ($s.Size -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $name" -ForegroundColor $color
        $i++
    }

    Write-Host ""
    Write-Host "   --- Maiores arquivos nesta pasta ---" -ForegroundColor $global:ThemeColor
    $topFiles = @($scan.TopFiles)
    $i = 1
    foreach ($f in $topFiles) {
        $num  = $i.ToString().PadLeft(2)
        $size = (Format-FileSize $f.Length).PadRight(12)
        $name = $f.Name
        if ($name.Length -gt 45) { $name = $name.Substring(0, 42) + "..." }
        Write-Host "   $num  $size  $name" -ForegroundColor White
        $i++
    }

    Write-ScanFooter $scan
    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? (Número, ou 0 para voltar)"
    if ($openChoice -match "^\d+$" -and $openChoice -ne "0") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $topFiles.Count) { Open-InExplorer $topFiles[$idx].FullName -Select }
    }

    Write-Log "Pasta escaneada: $folderPath ($($scan.TotalFiles) arquivos, $(Format-FileSize $scan.TotalSize))"
    Pause-Script
}

function Show-DrivesSummary {
    Write-Header
    Write-SubHeader "RESUMO DE TODOS OS DRIVES"

    $drives = @(Get-AvailableDrives)
    if ($drives.Count -eq 0) {
        Write-Status "Nenhum drive encontrado." "WARN"
        Pause-Script
        return
    }

    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.Free / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        $usedGB  = [math]::Round(($d.Size - $d.Free) / 1GB, 1)
        $freePerc = if ($d.Size -gt 0) { [int][math]::Round(($d.Free / $d.Size) * 100) } else { 0 }
        $tipo = switch ($d.Type) { "Removable" { " (USB)" } "Network" { " (Rede)" } default { "" } }

        Write-Host "   Drive $($d.Letter) [$($d.Label)]$tipo" -ForegroundColor $global:ThemeColor
        Write-ProgressBar $freePerc
        Write-Host "   Usado: $($usedGB)GB | Livre: $($freeGB)GB | Total: $($totalGB)GB" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Log "Resumo de drives exibido."
    Pause-Script
}
