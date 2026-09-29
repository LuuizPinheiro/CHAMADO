# ==============================================================================
# MÓDULO: Analisador de Disco (Arquivos e Pastas)
# ==============================================================================

function Invoke-MenuAnalisadorDisco {
    $loop = $true
    while ($loop) {
        Write-Header
        Write-SubHeader "ANALISADOR DE DISCO"

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

function Select-Drive {
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID
    Write-Host ""
    Write-Host "   Drives disponíveis:" -ForegroundColor $global:ThemeColor
    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.FreeSpace / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        $usedPerc = [math]::Round((($d.Size - $d.FreeSpace) / $d.Size) * 100)
        Write-Host "   $($d.DeviceID) [$($d.VolumeName)] - $($freeGB)GB livre de $($totalGB)GB ($($usedPerc)% usado)" -ForegroundColor White
    }
    Write-Host ""
    $chosen = Read-Host "   Escolha o drive (ex: C)"
    $driveLetter = "$($chosen.Trim().TrimEnd(':')):"
    if (Test-Path "$driveLetter\") {
        return $driveLetter
    } else {
        Write-Status "Drive não encontrado!" "ERRO"
        return $null
    }
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
    elseif ($Bytes -ge 1MB) { return "$([math]::Round($Bytes / 1MB, 1)) MB" }
    elseif ($Bytes -ge 1KB) { return "$([math]::Round($Bytes / 1KB, 0)) KB" }
    else { return "$Bytes B" }
}

function Find-LargestFiles {
    Write-Header
    Write-SubHeader "TOP 20 MAIORES ARQUIVOS"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Escaneando $drive (pode demorar em discos grandes)..." -ForegroundColor Yellow
    Write-Host ""

    $files = Get-ChildItem -Path "$drive\" -Recurse -File -Force -ErrorAction SilentlyContinue |
             Sort-Object Length -Descending |
             Select-Object -First 20

    if (-not $files -or $files.Count -eq 0) {
        Write-Status "Nenhum arquivo encontrado." "INFO"
        Pause-Script
        return
    }

    Write-Host "   #   Tamanho      Arquivo" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $files) {
        $size = (Format-FileSize $f.Length).PadRight(12)
        $path = $f.FullName
        if ($path.Length -gt 50) { $path = "..." + $path.Substring($path.Length - 47) }
        $num = $i.ToString().PadLeft(2)
        
        $color = if ($f.Length -ge 1GB) { "Red" } elseif ($f.Length -ge 100MB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $path" -ForegroundColor $color
        $i++
    }

    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? Digite o número (ou 0 para voltar)"
    if ($openChoice -ne "0" -and $openChoice -match "^\d+$") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $files.Count) {
            $folder = Split-Path $files[$idx].FullName -Parent
            Start-Process explorer.exe -ArgumentList "/select,`"$($files[$idx].FullName)`""
            Write-Status "Pasta aberta no Explorer!" "OK"
        }
    }

    Write-Log "Top 20 maiores arquivos listados em $drive"
    Pause-Script
}

function Find-LargestFolders {
    Write-Header
    Write-SubHeader "TOP 20 MAIORES PASTAS"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Calculando tamanho das pastas em $drive (pode demorar)..." -ForegroundColor Yellow
    Write-Host "   Analisando pastas de primeiro nível..." -ForegroundColor Gray
    Write-Host ""

    $rootFolders = Get-ChildItem -Path "$drive\" -Directory -Force -ErrorAction SilentlyContinue

    $folderSizes = @()
    foreach ($folder in $rootFolders) {
        Write-Host "`r   Analisando: $($folder.Name)                              " -ForegroundColor DarkGray -NoNewline
        $size = (Get-ChildItem -Path $folder.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($size -gt 0) {
            $folderSizes += [PSCustomObject]@{ Path = $folder.FullName; Size = $size }
        }
    }

    Write-Host "`r                                                                   `r" -NoNewline
    $sorted = $folderSizes | Sort-Object Size -Descending | Select-Object -First 20

    Write-Host "   #   Tamanho      Pasta" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $sorted) {
        $size = (Format-FileSize $f.Size).PadRight(12)
        $path = $f.Path
        if ($path.Length -gt 50) { $path = "..." + $path.Substring($path.Length - 47) }
        $num = $i.ToString().PadLeft(2)
        
        $color = if ($f.Size -ge 10GB) { "Red" } elseif ($f.Size -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $path" -ForegroundColor $color
        $i++
    }

    Write-Host ""
    $openChoice = Read-Host "   Abrir alguma pasta? Digite o número (ou 0 para voltar)"
    if ($openChoice -ne "0" -and $openChoice -match "^\d+$") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $sorted.Count) {
            Start-Process explorer.exe -ArgumentList "`"$($sorted[$idx].Path)`""
            Write-Status "Pasta aberta no Explorer!" "OK"
        }
    }

    Write-Log "Top 20 maiores pastas listadas em $drive"
    Pause-Script
}

function Analyze-FileTypes {
    Write-Header
    Write-SubHeader "ANÁLISE POR TIPO DE ARQUIVO"

    $drive = Select-Drive
    if (-not $drive) { Pause-Script; return }

    Write-Host ""
    Write-Host "   Escaneando $drive por tipos de arquivo (pode demorar bastante)..." -ForegroundColor Yellow
    Write-Host ""

    $typeCategories = @{
        "Vídeos"      = @(".mp4",".avi",".mkv",".mov",".wmv",".flv",".webm",".m4v",".ts",".mpg",".mpeg",".3gp")
        "Imagens"     = @(".jpg",".jpeg",".png",".gif",".bmp",".webp",".tiff",".svg",".ico",".raw",".psd")
        "Músicas"     = @(".mp3",".wav",".flac",".aac",".ogg",".wma",".m4a",".opus")
        "Documentos"  = @(".pdf",".doc",".docx",".xls",".xlsx",".ppt",".pptx",".txt",".odt",".ods",".csv")
        "Compactados" = @(".zip",".rar",".7z",".tar",".gz",".bz2",".xz",".iso")
        "Executáveis" = @(".exe",".msi",".bat",".cmd",".ps1",".dll")
        "Jogos/ISOs"  = @(".iso",".img",".bin",".cue",".nsp",".xci")
    }

    $allFiles = Get-ChildItem -Path "$drive\" -Recurse -File -Force -ErrorAction SilentlyContinue

    $results = @()
    foreach ($cat in $typeCategories.Keys) {
        $exts = $typeCategories[$cat]
        $matching = $allFiles | Where-Object { $exts -contains $_.Extension.ToLower() }
        $totalSize = ($matching | Measure-Object -Property Length -Sum).Sum
        $count = ($matching | Measure-Object).Count
        if ($count -gt 0) {
            $results += [PSCustomObject]@{
                Categoria = $cat
                Arquivos  = $count
                Tamanho   = $totalSize
                Lista     = $matching
            }
        }
    }

    # Ordena por tamanho
    $results = $results | Sort-Object Tamanho -Descending

    Write-Host "   Categoria        Arquivos   Tamanho" -ForegroundColor $global:ThemeColor
    Write-Host "   ----------------  --------   ----------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($r in $results) {
        $catName = $r.Categoria.PadRight(18)
        $count   = $r.Arquivos.ToString().PadRight(10)
        $size    = Format-FileSize $r.Tamanho
        $color   = if ($r.Tamanho -ge 10GB) { "Red" } elseif ($r.Tamanho -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   [$i] $catName $count $size" -ForegroundColor $color
        $i++
    }

    # Calcular "Outros"
    $knownExts = $typeCategories.Values | ForEach-Object { $_ }
    $others = $allFiles | Where-Object { $knownExts -notcontains $_.Extension.ToLower() }
    $othersSize = ($others | Measure-Object -Property Length -Sum).Sum
    $othersCount = ($others | Measure-Object).Count
    if ($othersCount -gt 0) {
        Write-Host "   [-] Outros              $($othersCount.ToString().PadRight(10)) $(Format-FileSize $othersSize)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "   Total geral escaneado: $(Format-FileSize (($allFiles | Measure-Object -Property Length -Sum).Sum))" -ForegroundColor White
    Write-Host ""

    # Detalhar uma categoria
    $detail = Read-Host "   Ver detalhes de qual categoria? (Número, ou 0 para voltar)"
    if ($detail -ne "0" -and $detail -match "^\d+$") {
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
    Write-Host "   Total: $($CategoryResult.Arquivos) arquivos ($( Format-FileSize $CategoryResult.Tamanho))" -ForegroundColor White
    Write-Host ""

    $topFiles = $CategoryResult.Lista | Sort-Object Length -Descending | Select-Object -First 15

    Write-Host "   #   Tamanho      Arquivo" -ForegroundColor $global:ThemeColor
    Write-Host "   --  -----------  ------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($f in $topFiles) {
        $size = (Format-FileSize $f.Length).PadRight(12)
        $path = $f.FullName
        if ($path.Length -gt 50) { $path = "..." + $path.Substring($path.Length - 47) }
        $num = $i.ToString().PadLeft(2)
        Write-Host "   $num  $size  $path" -ForegroundColor White
        $i++
    }

    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? (Número, ou 0 para voltar)"
    if ($openChoice -ne "0" -and $openChoice -match "^\d+$") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $topFiles.Count) {
            Start-Process explorer.exe -ArgumentList "/select,`"$($topFiles[$idx].FullName)`""
            Write-Status "Pasta aberta com arquivo selecionado!" "OK"
        }
    }
}

function Scan-SpecificFolder {
    Write-Header
    Write-SubHeader "ESCANEAR PASTA ESPECÍFICA"

    $folderPath = Read-Host "   Caminho da pasta (ex: C:\Users)"
    if (-not (Test-Path $folderPath)) {
        Write-Status "Pasta não encontrada!" "ERRO"
        Pause-Script
        return
    }

    Write-Host ""
    Write-Host "   Escaneando $folderPath ..." -ForegroundColor Yellow
    Write-Host ""

    # Tamanho total
    $allFiles = Get-ChildItem -Path $folderPath -Recurse -File -Force -ErrorAction SilentlyContinue
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
    $totalCount = ($allFiles | Measure-Object).Count

    Write-Host "   Total: $totalCount arquivos ($( Format-FileSize $totalSize))" -ForegroundColor White
    Write-Host ""

    # Subpastas por tamanho
    Write-Host "   --- Subpastas por tamanho ---" -ForegroundColor $global:ThemeColor
    $subFolders = Get-ChildItem -Path $folderPath -Directory -Force -ErrorAction SilentlyContinue
    $subSizes = @()
    foreach ($sub in $subFolders) {
        $size = (Get-ChildItem -Path $sub.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($size -gt 0) {
            $subSizes += [PSCustomObject]@{ Name = $sub.Name; Path = $sub.FullName; Size = $size }
        }
    }
    $subSizes = $subSizes | Sort-Object Size -Descending | Select-Object -First 15

    $i = 1
    foreach ($s in $subSizes) {
        $num  = $i.ToString().PadLeft(2)
        $size = (Format-FileSize $s.Size).PadRight(12)
        $name = $s.Name
        if ($name.Length -gt 40) { $name = $name.Substring(0, 37) + "..." }
        $color = if ($s.Size -ge 1GB) { "Yellow" } else { "White" }
        Write-Host "   $num  $size  $name" -ForegroundColor $color
        $i++
    }

    # Maiores arquivos
    Write-Host ""
    Write-Host "   --- Maiores arquivos nesta pasta ---" -ForegroundColor $global:ThemeColor
    $topFiles = $allFiles | Sort-Object Length -Descending | Select-Object -First 10
    $i = 1
    foreach ($f in $topFiles) {
        $num  = $i.ToString().PadLeft(2)
        $size = (Format-FileSize $f.Length).PadRight(12)
        $name = $f.Name
        if ($name.Length -gt 40) { $name = $name.Substring(0, 37) + "..." }
        Write-Host "   $num  $size  $name" -ForegroundColor White
        $i++
    }

    Write-Host ""
    $openChoice = Read-Host "   Abrir pasta de algum arquivo? (Número, ou 0 para voltar)"
    if ($openChoice -ne "0" -and $openChoice -match "^\d+$") {
        $idx = [int]$openChoice - 1
        if ($idx -ge 0 -and $idx -lt $topFiles.Count) {
            Start-Process explorer.exe -ArgumentList "/select,`"$($topFiles[$idx].FullName)`""
            Write-Status "Pasta aberta!" "OK"
        }
    }

    Write-Log "Pasta escaneada: $folderPath ($totalCount arquivos, $(Format-FileSize $totalSize))"
    Pause-Script
}

function Show-DrivesSummary {
    Write-Header
    Write-SubHeader "RESUMO DE TODOS OS DRIVES"

    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID

    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.FreeSpace / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        $usedGB  = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
        $usedPerc = [math]::Round((($d.Size - $d.FreeSpace) / $d.Size) * 100)
        $freePerc = 100 - $usedPerc

        Write-Host "   Drive $($d.DeviceID) [$($d.VolumeName)]" -ForegroundColor $global:ThemeColor
        Write-ProgressBar $freePerc
        Write-Host "   Usado: $($usedGB)GB | Livre: $($freeGB)GB | Total: $($totalGB)GB" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Log "Resumo de drives exibido."
    Pause-Script
}
