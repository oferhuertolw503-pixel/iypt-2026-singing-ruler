[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('fill', 'validate')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$DocPath,

    [Parameter(Mandatory = $true)]
    [string]$PptPath,

    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)
    return (Resolve-Path -LiteralPath $PathValue).Path
}

function Get-DefaultBackupPath {
    param([Parameter(Mandatory = $true)][string]$PresentationPath)
    $item = Get-Item -LiteralPath $PresentationPath
    return (Join-Path $item.DirectoryName ($item.BaseName + '.tablefill-backup' + $item.Extension))
}

function Close-ComObject {
    param($ComObject)
    if ($null -ne $ComObject) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject)
    }
}

function Get-WordParagraphArray {
    param([Parameter(Mandatory = $true)][string]$Path)

    $word = $null
    $document = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $document = $word.Documents.Open($Path, $false, $true)

        $paragraphs = New-Object System.Collections.Generic.List[string]
        for ($i = 1; $i -le $document.Paragraphs.Count; $i++) {
            $raw = $document.Paragraphs.Item($i).Range.Text
            $clean = $raw -replace '[\r\a]+$', ''
            [void]$paragraphs.Add($clean)
        }
        return $paragraphs.ToArray()
    }
    finally {
        if ($document) {
            $document.Close([ref]0) | Out-Null
            Close-ComObject $document
        }
        if ($word) {
            $word.Quit() | Out-Null
            Close-ComObject $word
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Convert-ParagraphToMatrix {
    param([Parameter(Mandatory = $true)][string]$ParagraphText)

    $verticalTab = [string][char]11
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($line in ($ParagraphText -split [regex]::Escape($verticalTab))) {
        $cleanLine = ($line -replace '[\r\n]+', ' ').Trim()
        if (-not $cleanLine) {
            continue
        }
        $tokens = @($cleanLine -split '\s+' | Where-Object { $_ -ne '' })
        [void]$rows.Add($tokens)
    }

    return ,$rows.ToArray()
}

function Get-DocData {
    param([Parameter(Mandatory = $true)][string]$Path)

    $paragraphs = Get-WordParagraphArray -Path $Path
    if ($paragraphs.Length -lt 34) {
        throw 'Unexpected doc paragraph count.'
    }

    $lengthTable = Convert-ParagraphToMatrix -ParagraphText $paragraphs[5]
    $thicknessTable = Convert-ParagraphToMatrix -ParagraphText $paragraphs[10]
    $materialFreqTable = Convert-ParagraphToMatrix -ParagraphText $paragraphs[26]
    $modalTTable = Convert-ParagraphToMatrix -ParagraphText $paragraphs[33]

    return @{
        LengthRows = @($lengthTable[1..($lengthTable.Length - 1)])
        ThicknessRows = @($thicknessTable[1..($thicknessTable.Length - 1)])
        MaterialFreqRows = @($materialFreqTable[1..($materialFreqTable.Length - 1)])
        ModalTRows = @($modalTTable[1..($modalTTable.Length - 1)])
    }
}

function Get-ExpectedTargets {
    param([Parameter(Mandatory = $true)][hashtable]$Data)

    return @{
        '25|1' = @{
            2 = $Data.LengthRows[0]
            3 = $Data.LengthRows[1]
            4 = $Data.LengthRows[2]
            5 = $Data.LengthRows[3]
            6 = $Data.LengthRows[4]
        }
        '26|1' = @{
            2 = $Data.ThicknessRows[0]
            3 = $Data.ThicknessRows[1]
            4 = $Data.ThicknessRows[2]
            5 = $Data.ThicknessRows[3]
            6 = $Data.ThicknessRows[4]
        }
        '26|2' = @{
            2 = $Data.MaterialFreqRows[0]
            3 = $Data.MaterialFreqRows[1]
            4 = $Data.MaterialFreqRows[2]
            5 = $Data.MaterialFreqRows[3]
            6 = $Data.MaterialFreqRows[4]
        }
        '30|1' = @{
            2 = $Data.ModalTRows[0]
            3 = $Data.ModalTRows[1]
            4 = $Data.ModalTRows[3]
            5 = $Data.ModalTRows[4]
            6 = $Data.ModalTRows[2]
        }
    }
}

function Set-BodyCellText {
    param(
        $Table,
        [Parameter(Mandatory = $true)][int]$Row,
        [Parameter(Mandatory = $true)][int]$Column,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $cellShape = $Table.Cell($Row, $Column).Shape
    $cellShape.TextFrame.TextRange.Text = $Value
}

function Fill-PresentationTables {
    param(
        [Parameter(Mandatory = $true)][string]$PresentationPath,
        [Parameter(Mandatory = $true)][hashtable]$Targets
    )

    $ppt = $null
    $presentation = $null
    try {
        $ppt = New-Object -ComObject PowerPoint.Application
        $ppt.Visible = -1
        $presentation = $ppt.Presentations.Open($PresentationPath, $false, $false, $false)

        foreach ($slide in $presentation.Slides) {
            $tableOrdinal = 0
            foreach ($shape in $slide.Shapes) {
                if ($shape.HasTable -ne -1) {
                    continue
                }

                $tableOrdinal++
                $targetKey = ('{0}|{1}' -f $slide.SlideIndex, $tableOrdinal)
                if (-not $Targets.ContainsKey($targetKey)) {
                    continue
                }

                $rowMap = $Targets[$targetKey]
                foreach ($rowIndex in ($rowMap.Keys | Sort-Object)) {
                    $rowValues = $rowMap[$rowIndex]
                    for ($columnIndex = 0; $columnIndex -lt $rowValues.Count; $columnIndex++) {
                        Set-BodyCellText -Table $shape.Table -Row $rowIndex -Column ($columnIndex + 1) -Value ([string]$rowValues[$columnIndex])
                    }
                }
            }
        }

        $presentation.Save()
    }
    finally {
        if ($presentation) {
            $presentation.Close()
            Close-ComObject $presentation
        }
        if ($ppt) {
            $ppt.Quit()
            Close-ComObject $ppt
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-TableTextMatrix {
    param($Table)

    $rows = @()
    for ($r = 1; $r -le $Table.Rows.Count; $r++) {
        $row = @()
        for ($c = 1; $c -le $Table.Columns.Count; $c++) {
            $text = $Table.Cell($r, $c).Shape.TextFrame.TextRange.Text
            $row += (($text -replace '[\r\n]+', ' ').Trim())
        }
        $rows += ,$row
    }
    return ,$rows
}

function Get-PresentationSnapshot {
    param([Parameter(Mandatory = $true)][string]$PresentationPath)

    $ppt = $null
    $presentation = $null
    try {
        $ppt = New-Object -ComObject PowerPoint.Application
        $ppt.Visible = -1
        $presentation = $ppt.Presentations.Open($PresentationPath, $false, $true, $false)

        $slides = New-Object System.Collections.Generic.List[object]
        foreach ($slide in $presentation.Slides) {
            $shapeSnapshots = New-Object System.Collections.Generic.List[object]
            $tableOrdinal = 0

            foreach ($shape in $slide.Shapes) {
                $hasTable = ($shape.HasTable -eq -1)
                if ($hasTable) {
                    $tableOrdinal++
                }

                $shapeData = [ordered]@{
                    Name = $shape.Name
                    Type = [int]$shape.Type
                    Left = [double]$shape.Left
                    Top = [double]$shape.Top
                    Width = [double]$shape.Width
                    Height = [double]$shape.Height
                    HasTable = $hasTable
                    HasTextFrame = ($shape.HasTextFrame -eq -1)
                    Text = ''
                    TableOrdinal = $tableOrdinal
                    Table = $null
                }

                if ($shapeData.HasTextFrame) {
                    try {
                        $shapeData.Text = (($shape.TextFrame.TextRange.Text -replace '[\r\n]+', ' ').Trim())
                    }
                    catch {
                        $shapeData.Text = ''
                    }
                }

                if ($hasTable) {
                    $shapeData.Table = @{
                        Rows = $shape.Table.Rows.Count
                        Columns = $shape.Table.Columns.Count
                        Cells = Get-TableTextMatrix -Table $shape.Table
                    }
                }

                [void]$shapeSnapshots.Add([pscustomobject]$shapeData)
            }

            [void]$slides.Add([pscustomobject]@{
                Index = $slide.SlideIndex
                ShapeCount = $slide.Shapes.Count
                Shapes = $shapeSnapshots
            })
        }

        return $slides
    }
    finally {
        if ($presentation) {
            $presentation.Close()
            Close-ComObject $presentation
        }
        if ($ppt) {
            $ppt.Quit()
            Close-ComObject $ppt
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -ne $Expected) {
        throw ('{0} Expected: [{1}] Actual: [{2}]' -f $Message, $Expected, $Actual)
    }
}

function Assert-Near {
    param(
        [Parameter(Mandatory = $true)][double]$Actual,
        [Parameter(Mandatory = $true)][double]$Expected,
        [Parameter(Mandatory = $true)][string]$Message,
        [double]$Tolerance = 0.01
    )

    if ([Math]::Abs($Actual - $Expected) -gt $Tolerance) {
        throw ('{0} Expected: [{1}] Actual: [{2}]' -f $Message, $Expected, $Actual)
    }
}

function Validate-PresentationChange {
    param(
        [Parameter(Mandatory = $true)][string]$OriginalPath,
        [Parameter(Mandatory = $true)][string]$ModifiedPath,
        [Parameter(Mandatory = $true)][hashtable]$Targets
    )

    $before = Get-PresentationSnapshot -PresentationPath $OriginalPath
    $after = Get-PresentationSnapshot -PresentationPath $ModifiedPath

    Assert-Equal -Actual $after.Count -Expected $before.Count -Message 'slide count changed.'

    for ($slideIndex = 0; $slideIndex -lt $before.Count; $slideIndex++) {
        $slideBefore = $before[$slideIndex]
        $slideAfter = $after[$slideIndex]

        Assert-Equal -Actual $slideAfter.ShapeCount -Expected $slideBefore.ShapeCount -Message ('shape count changed on slide {0}.' -f $slideBefore.Index)

        for ($shapeIndex = 0; $shapeIndex -lt $slideBefore.Shapes.Count; $shapeIndex++) {
            $shapeBefore = $slideBefore.Shapes[$shapeIndex]
            $shapeAfter = $slideAfter.Shapes[$shapeIndex]

            Assert-Equal -Actual $shapeAfter.Name -Expected $shapeBefore.Name -Message ('shape name changed on slide {0}.' -f $slideBefore.Index)
            Assert-Equal -Actual $shapeAfter.Type -Expected $shapeBefore.Type -Message ('shape type changed on slide {0}.' -f $slideBefore.Index)
            Assert-Near -Actual $shapeAfter.Left -Expected $shapeBefore.Left -Message ('shape left changed on slide {0}.' -f $slideBefore.Index)
            Assert-Near -Actual $shapeAfter.Top -Expected $shapeBefore.Top -Message ('shape top changed on slide {0}.' -f $slideBefore.Index)
            Assert-Near -Actual $shapeAfter.Width -Expected $shapeBefore.Width -Message ('shape width changed on slide {0}.' -f $slideBefore.Index)
            Assert-Near -Actual $shapeAfter.Height -Expected $shapeBefore.Height -Message ('shape height changed on slide {0}.' -f $slideBefore.Index)
            Assert-Equal -Actual $shapeAfter.HasTable -Expected $shapeBefore.HasTable -Message ('table flag changed on slide {0}.' -f $slideBefore.Index)

            if (-not $shapeBefore.HasTable) {
                Assert-Equal -Actual $shapeAfter.Text -Expected $shapeBefore.Text -Message ('non-table text changed on slide {0}.' -f $slideBefore.Index)
                continue
            }

            Assert-Equal -Actual $shapeAfter.Table.Rows -Expected $shapeBefore.Table.Rows -Message ('table row count changed on slide {0}.' -f $slideBefore.Index)
            Assert-Equal -Actual $shapeAfter.Table.Columns -Expected $shapeBefore.Table.Columns -Message ('table column count changed on slide {0}.' -f $slideBefore.Index)
            Assert-Equal -Actual $shapeAfter.TableOrdinal -Expected $shapeBefore.TableOrdinal -Message ('table ordinal changed on slide {0}.' -f $slideBefore.Index)

            $targetKey = ('{0}|{1}' -f $slideBefore.Index, $shapeBefore.TableOrdinal)
            $rowMap = $null
            if ($Targets.ContainsKey($targetKey)) {
                $rowMap = $Targets[$targetKey]
            }

            for ($r = 0; $r -lt $shapeBefore.Table.Cells.Count; $r++) {
                for ($c = 0; $c -lt $shapeBefore.Table.Cells[$r].Count; $c++) {
                    $beforeText = $shapeBefore.Table.Cells[$r][$c]
                    $afterText = $shapeAfter.Table.Cells[$r][$c]
                    $rowNumber = $r + 1
                    $columnNumber = $c + 1

                    if ($rowMap -and $rowMap.ContainsKey($rowNumber)) {
                        $expectedRow = $rowMap[$rowNumber]
                        if ($columnNumber -le $expectedRow.Count) {
                            Assert-Equal -Actual $afterText -Expected ([string]$expectedRow[$c]) -Message ('target table cell mismatch on slide {0}, row {1}, col {2}.' -f $slideBefore.Index, $rowNumber, $columnNumber)
                            continue
                        }
                    }

                    Assert-Equal -Actual $afterText -Expected $beforeText -Message ('non-target table cell changed on slide {0}, row {1}, col {2}.' -f $slideBefore.Index, $rowNumber, $columnNumber)
                }
            }
        }
    }
}

$resolvedDocPath = Resolve-FullPath -PathValue $DocPath
$resolvedPptPath = Resolve-FullPath -PathValue $PptPath

if (-not $BackupPath) {
    $BackupPath = Get-DefaultBackupPath -PresentationPath $resolvedPptPath
}

$docData = Get-DocData -Path $resolvedDocPath
$targets = Get-ExpectedTargets -Data $docData

switch ($Mode) {
    'fill' {
        if (-not (Test-Path -LiteralPath $BackupPath)) {
            Copy-Item -LiteralPath $resolvedPptPath -Destination $BackupPath
        }
        Fill-PresentationTables -PresentationPath $resolvedPptPath -Targets $targets
        Write-Output 'FILL_OK'
        Write-Output ('BACKUP_PATH=' + $BackupPath)
    }
    'validate' {
        if (-not (Test-Path -LiteralPath $BackupPath)) {
            throw ('backup file not found: ' + $BackupPath)
        }
        Validate-PresentationChange -OriginalPath $BackupPath -ModifiedPath $resolvedPptPath -Targets $targets
        Write-Output 'VALIDATION_OK'
        Write-Output ('BACKUP_PATH=' + $BackupPath)
    }
}
