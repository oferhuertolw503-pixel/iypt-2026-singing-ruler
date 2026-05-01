[CmdletBinding()]
param(
    [string]$StudyManifestPath = "",
    [string]$PptPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $repoRoot "scripts\comsol_common.ps1")

if ([string]::IsNullOrWhiteSpace($StudyManifestPath)) {
    $StudyManifestPath = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\study_manifest.json"
}
if ([string]::IsNullOrWhiteSpace($PptPath)) {
    $PptPath = Join-Path $repoRoot "ppt\COMSOL_参数表_当前主线.pptx"
}

function Read-JsonUtf8 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Set-ObjectPropertyValueLocal {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $prop.Value = $Value
    }
}

function Merge-MissingPropertiesRecursivelyLocal {
    param(
        [Parameter(Mandatory = $true)][object]$Target,
        [Parameter(Mandatory = $true)][object]$Source
    )

    foreach ($prop in $Source.PSObject.Properties) {
        $targetProp = $Target.PSObject.Properties[$prop.Name]
        if ($null -eq $targetProp -or $null -eq $targetProp.Value) {
            Set-ObjectPropertyValueLocal -Object $Target -Name $prop.Name -Value $prop.Value
            continue
        }

        if ($prop.Value -is [System.Management.Automation.PSCustomObject] -and $targetProp.Value -is [System.Management.Automation.PSCustomObject]) {
            Merge-MissingPropertiesRecursivelyLocal -Target $targetProp.Value -Source $prop.Value
        }
    }
}

function Merge-MissingStructuralReferenceConfigLocal {
    param(
        [Parameter(Mandatory = $true)][object]$AcousticConfig,
        [Parameter(Mandatory = $true)][object]$StructuralReferenceConfig
    )

    $merged = $AcousticConfig | ConvertTo-Json -Depth 64 | ConvertFrom-Json
    foreach ($sectionName in @("geometry", "material", "boundary", "excitation", "studies", "mesh")) {
        $sourceSection = $StructuralReferenceConfig.PSObject.Properties[$sectionName]
        if ($null -eq $sourceSection -or $null -eq $sourceSection.Value) {
            continue
        }

        $targetSection = $merged.PSObject.Properties[$sectionName]
        if ($null -eq $targetSection -or $null -eq $targetSection.Value) {
            Set-ObjectPropertyValueLocal -Object $merged -Name $sectionName -Value $sourceSection.Value
            continue
        }

        Merge-MissingPropertiesRecursivelyLocal -Target $targetSection.Value -Source $sourceSection.Value
    }

    return $merged
}

function Format-InvariantNumber {
    param(
        [Parameter(Mandatory = $true)][double]$Value,
        [string]$Format = "0.###"
    )

    return $Value.ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Convert-QuantityString {
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($Text -match '^\s*([+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\[(.+)\]\s*$') {
        return [pscustomobject]@{
            value = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
            unit = $matches[2]
        }
    }

    throw "Unsupported quantity string: $Text"
}

function Format-QuantityDisplay {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$DisplayUnit,
        [string]$Format = "0.###"
    )

    $quantity = Convert-QuantityString -Text $Text
    $value = $quantity.value
    $unit = $DisplayUnit

    switch ("$($quantity.unit)->$DisplayUnit") {
        "m->m" { }
        "m->cm" { $value *= 100.0 }
        "m->mm" { $value *= 1000.0 }
        "s->s" { }
        "s->ms" { $value *= 1000.0 }
        "s->μs" { $value *= 1000000.0 }
        "Pa->Pa" { }
        "Pa->GPa" { $value /= 1000000000.0 }
        "Hz->Hz" { }
        "kg/m^3->kg/m^3" { }
        "N*s->N·s" { }
        "m/s->m/s" { }
        default { throw "Unsupported unit conversion: $($quantity.unit) -> $DisplayUnit" }
    }

    return ("{0} {1}" -f (Format-InvariantNumber -Value $value -Format $Format), $unit)
}

function Format-RangeDisplay {
    param(
        [Parameter(Mandatory = $true)][double[]]$Values,
        [string]$Unit = "",
        [string]$Format = "0.###"
    )

    $minValue = ($Values | Measure-Object -Minimum).Minimum
    $maxValue = ($Values | Measure-Object -Maximum).Maximum
    $core = "{0}-{1}" -f (Format-InvariantNumber -Value $minValue -Format $Format), (Format-InvariantNumber -Value $maxValue -Format $Format)
    if ([string]::IsNullOrWhiteSpace($Unit)) {
        return $core
    }
    return ("{0} {1}" -f $core, $Unit)
}

function New-ResolvedBaselineConfig {
    param([Parameter(Mandatory = $true)][object]$StudyManifest)

    $acousticConfig = Read-JsonFile -Path (Join-Path $repoRoot "models\linear\acoustic_field\config\params.json")
    $impactConfig = Read-JsonFile -Path (Join-Path $repoRoot "models\linear\impact_response\config\params.json")
    $baseline = $StudyManifest.baseline

    $config = Merge-MissingStructuralReferenceConfigLocal -AcousticConfig $acousticConfig -StructuralReferenceConfig $impactConfig
    $config.geometry.L_free = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm / 100.0) -Format "0.00000"))
    $config.geometry.b = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$baseline.b_cm / 100.0) -Format "0.00000"))
    $config.geometry.h = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$baseline.h_mm / 1000.0) -Format "0.00000"))
    $config.excitation.x0 = ("{0}*L_free" -f (Format-InvariantNumber -Value ([double]$baseline.x0_ratio) -Format "0.0000"))
    $config.excitation.J = ("{0}[N*s]" -f (Format-InvariantNumber -Value ([double]$baseline.J_Ns) -Format "0.00000"))

    return (New-ResolvedLinearConfig -Config $config -ModelId "acoustic_field" -Quality ([string]$StudyManifest.quality)).Config
}

function New-Entry {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Symbol,
        [Parameter(Mandatory = $true)][string]$Formula,
        [Parameter(Mandatory = $true)][string]$Value
    )

    return [pscustomobject]@{
        name = $Name
        symbol = $Symbol
        formula = $Formula
        value = $Value
    }
}

function Get-RgbValue {
    param([Parameter(Mandatory = $true)][string]$Hex)

    $clean = $Hex.TrimStart("#")
    $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    return ($r -bor ($g -shl 8) -bor ($b -shl 16))
}

function Set-SolidFill {
    param(
        [Parameter(Mandatory = $true)]$Shape,
        [Parameter(Mandatory = $true)][string]$Hex
    )

    $Shape.Fill.Visible = -1
    $Shape.Fill.Solid()
    $Shape.Fill.ForeColor.RGB = Get-RgbValue -Hex $Hex
}

function Set-SolidLine {
    param(
        [Parameter(Mandatory = $true)]$Shape,
        [Parameter(Mandatory = $true)][string]$Hex,
        [double]$Weight = 1.0
    )

    $Shape.Line.Visible = -1
    $Shape.Line.ForeColor.RGB = Get-RgbValue -Hex $Hex
    $Shape.Line.Weight = $Weight
}

function Add-TextBox {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$FontName = "Microsoft YaHei",
        [double]$FontSize = 16,
        [string]$ColorHex = "#1F2937",
        [switch]$Bold,
        [int]$Alignment = 1,
        [int]$VerticalAnchor = 1
    )

    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = 0
    $shape.Line.Visible = 0
    $shape.TextFrame2.MarginLeft = 0
    $shape.TextFrame2.MarginRight = 0
    $shape.TextFrame2.MarginTop = 0
    $shape.TextFrame2.MarginBottom = 0
    $shape.TextFrame2.VerticalAnchor = $VerticalAnchor
    $shape.TextFrame2.WordWrap = -1
    $shape.TextFrame2.TextRange.Text = $Text
    $shape.TextFrame2.TextRange.Font.Name = $FontName
    $shape.TextFrame2.TextRange.Font.Size = $FontSize
    $shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = Get-RgbValue -Hex $ColorHex
    $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = $Alignment
    if ($Bold) {
        $shape.TextFrame2.TextRange.Font.Bold = -1
    }
    return $shape
}

function Add-EquationBox {
    param(
        [Parameter(Mandatory = $true)]$Application,
        [Parameter(Mandatory = $true)]$Presentation,
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [Parameter(Mandatory = $true)][string]$Expression
    )

    $Presentation.Windows.Item(1).View.GotoSlide($Slide.SlideIndex) | Out-Null
    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = 0
    $shape.Line.Visible = 0
    $shape.TextFrame2.MarginLeft = 0
    $shape.TextFrame2.MarginRight = 0
    $shape.TextFrame2.MarginTop = 0
    $shape.TextFrame2.MarginBottom = 0
    $shape.TextFrame2.WordWrap = -1
    $shape.Select() | Out-Null
    Start-Sleep -Milliseconds 120
    $Application.CommandBars.ExecuteMso("InsertBuildingBlocksEquationsGallery")
    Start-Sleep -Milliseconds 120
    $equationShape = $Application.ActiveWindow.Selection.ShapeRange(1)
    $equationShape.TextFrame2.TextRange.Text = $Expression
    Start-Sleep -Milliseconds 80
    $Application.CommandBars.ExecuteMso("EquationProfessional")
    Start-Sleep -Milliseconds 120
    $equationShape.Left = $Left
    $equationShape.Top = $Top
    $equationShape.Width = $Width
    $equationShape.Height = $Height
    $equationShape.Fill.Visible = 0
    $equationShape.Line.Visible = 0
    return $equationShape
}

function Add-CoverSlide {
    param(
        [Parameter(Mandatory = $true)]$Application,
        [Parameter(Mandatory = $true)]$Presentation,
        [Parameter(Mandatory = $true)][object]$StudyManifest
    )

    $slide = $Presentation.Slides.Add($Presentation.Slides.Count + 1, 12)
    $width = $Presentation.PageSetup.SlideWidth
    $height = $Presentation.PageSetup.SlideHeight

    $bg = $slide.Shapes.AddShape(1, 0, 0, $width, $height)
    Set-SolidFill -Shape $bg -Hex "#0F2A56"
    $bg.Line.Visible = 0

    $band = $slide.Shapes.AddShape(1, 0, 0, $width, 16)
    Set-SolidFill -Shape $band -Hex "#D9A85C"
    $band.Line.Visible = 0

    Add-TextBox -Slide $slide -Left 54 -Top 76 -Width 700 -Height 42 -Text "COMSOL 参数表" -FontSize 30 -ColorHex "#F3D59B" -Bold
    Add-TextBox -Slide $slide -Left 54 -Top 122 -Width 760 -Height 72 -Text "Acoustic Field 当前主线" -FontSize 26 -ColorHex "#FFFFFF" -Bold
    Add-TextBox -Slide $slide -Left 56 -Top 206 -Width 760 -Height 54 -Text "仅保留空气域 acoustic_field；扫描参数按 [基准值 + 范围] 展示。" -FontSize 16 -ColorHex "#D8E3F2"
    Add-TextBox -Slide $slide -Left 56 -Top 286 -Width 820 -Height 110 -Text ("当前扫描来源：{0}`r`nStudy：{1}    Design：{2}    Quality：{3}" -f [System.IO.Path]::GetFileName($StudyManifestPath), [string]$StudyManifest.study_selection, [string]$StudyManifest.design, [string]$StudyManifest.quality) -FontSize 15 -ColorHex "#D8E3F2"
    Add-TextBox -Slide $slide -Left 56 -Top 452 -Width 820 -Height 30 -Text "参数列格式：参数名 / 数学公式 / 设置值" -FontSize 15 -ColorHex "#F3D59B" -Bold

    return $slide
}

function Add-ParameterSlide {
    param(
        [Parameter(Mandatory = $true)]$Application,
        [Parameter(Mandatory = $true)]$Presentation,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Subtitle,
        [Parameter(Mandatory = $true)][object[]]$Entries
    )

    $slide = $Presentation.Slides.Add($Presentation.Slides.Count + 1, 12)
    $width = $Presentation.PageSetup.SlideWidth
    $height = $Presentation.PageSetup.SlideHeight

    $bg = $slide.Shapes.AddShape(1, 0, 0, $width, $height)
    Set-SolidFill -Shape $bg -Hex "#F8FAFC"
    $bg.Line.Visible = 0

    $topBand = $slide.Shapes.AddShape(1, 0, 0, $width, 26)
    Set-SolidFill -Shape $topBand -Hex "#0F2A56"
    $topBand.Line.Visible = 0

    Add-TextBox -Slide $slide -Left 28 -Top 34 -Width 700 -Height 28 -Text $Title -FontSize 24 -ColorHex "#0F2A56" -Bold
    Add-TextBox -Slide $slide -Left 30 -Top 63 -Width 860 -Height 18 -Text $Subtitle -FontSize 11 -ColorHex "#475569"

    $tableLeft = 24.0
    $tableTop = 92.0
    $tableWidth = 912.0
    $headerHeight = 30.0
    $tableHeight = 420.0
    $rowHeight = ($tableHeight - $headerHeight) / $Entries.Count
    $col1Width = 220.0
    $col2Width = 370.0
    $col3Width = $tableWidth - $col1Width - $col2Width

    $headerBg = $slide.Shapes.AddShape(1, $tableLeft, $tableTop, $tableWidth, $headerHeight)
    Set-SolidFill -Shape $headerBg -Hex "#12386E"
    $headerBg.Line.Visible = 0
    Add-TextBox -Slide $slide -Left ($tableLeft + 10) -Top ($tableTop + 5) -Width ($col1Width - 20) -Height 20 -Text "参数名" -FontSize 14 -ColorHex "#FFFFFF" -Bold
    Add-TextBox -Slide $slide -Left ($tableLeft + $col1Width + 10) -Top ($tableTop + 5) -Width ($col2Width - 20) -Height 20 -Text "数学公式" -FontSize 14 -ColorHex "#FFFFFF" -Bold
    Add-TextBox -Slide $slide -Left ($tableLeft + $col1Width + $col2Width + 10) -Top ($tableTop + 5) -Width ($col3Width - 20) -Height 20 -Text "设置值" -FontSize 14 -ColorHex "#FFFFFF" -Bold

    for ($i = 0; $i -lt $Entries.Count; $i++) {
        $rowTop = $tableTop + $headerHeight + ($i * $rowHeight)
        $fillHex = if (($i % 2) -eq 0) { "#EEF4FB" } else { "#F8FAFC" }

        $cell1 = $slide.Shapes.AddShape(1, $tableLeft, $rowTop, $col1Width, $rowHeight)
        Set-SolidFill -Shape $cell1 -Hex $fillHex
        Set-SolidLine -Shape $cell1 -Hex "#D2DCEB" -Weight 0.75

        $cell2 = $slide.Shapes.AddShape(1, $tableLeft + $col1Width, $rowTop, $col2Width, $rowHeight)
        Set-SolidFill -Shape $cell2 -Hex $fillHex
        Set-SolidLine -Shape $cell2 -Hex "#D2DCEB" -Weight 0.75

        $cell3 = $slide.Shapes.AddShape(1, $tableLeft + $col1Width + $col2Width, $rowTop, $col3Width, $rowHeight)
        Set-SolidFill -Shape $cell3 -Hex $fillHex
        Set-SolidLine -Shape $cell3 -Hex "#D2DCEB" -Weight 0.75

        $entry = $Entries[$i]
        Add-TextBox -Slide $slide -Left ($tableLeft + 10) -Top ($rowTop + 5) -Width ($col1Width - 20) -Height 18 -Text ([string]$entry.name) -FontSize 13 -ColorHex "#0F172A" -Bold
        Add-EquationBox -Application $Application -Presentation $Presentation -Slide $slide -Left ($tableLeft + 10) -Top ($rowTop + 22) -Width ($col1Width - 20) -Height ($rowHeight - 26) -Expression ([string]$entry.symbol) | Out-Null
        Add-EquationBox -Application $Application -Presentation $Presentation -Slide $slide -Left ($tableLeft + $col1Width + 10) -Top ($rowTop + 7) -Width ($col2Width - 20) -Height ($rowHeight - 12) -Expression ([string]$entry.formula) | Out-Null
        Add-TextBox -Slide $slide -Left ($tableLeft + $col1Width + $col2Width + 10) -Top ($rowTop + 7) -Width ($col3Width - 20) -Height ($rowHeight - 12) -Text ([string]$entry.value) -FontSize 11 -ColorHex "#334155" -VerticalAnchor 3
    }

    Add-TextBox -Slide $slide -Left 28 -Top 520 -Width 880 -Height 14 -Text "注：第二列为 PowerPoint 原生公式对象；第三列使用当前主线基准值，扫描变量补充范围。" -FontSize 9 -ColorHex "#64748B"
    return $slide
}

function Add-NotesSlide {
    param(
        [Parameter(Mandatory = $true)]$Presentation,
        [Parameter(Mandatory = $true)][object]$StudyManifest,
        [Parameter(Mandatory = $true)][object]$ResolvedConfig
    )

    $slide = $Presentation.Slides.Add($Presentation.Slides.Count + 1, 12)
    $width = $Presentation.PageSetup.SlideWidth
    $height = $Presentation.PageSetup.SlideHeight

    $bg = $slide.Shapes.AddShape(1, 0, 0, $width, $height)
    Set-SolidFill -Shape $bg -Hex "#FFFFFF"
    $bg.Line.Visible = 0

    $topBand = $slide.Shapes.AddShape(1, 0, 0, $width, 24)
    Set-SolidFill -Shape $topBand -Hex "#0F2A56"
    $topBand.Line.Visible = 0

    Add-TextBox -Slide $slide -Left 28 -Top 34 -Width 680 -Height 28 -Text "来源与说明" -FontSize 24 -ColorHex "#0F2A56" -Bold

    $card1 = $slide.Shapes.AddShape(1, 26, 88, 430, 160)
    Set-SolidFill -Shape $card1 -Hex "#F8FAFC"
    Set-SolidLine -Shape $card1 -Hex "#D6E0EF" -Weight 1
    Add-TextBox -Slide $slide -Left 42 -Top 102 -Width 390 -Height 24 -Text "当前值来源" -FontSize 18 -ColorHex "#0F2A56" -Bold
    $sourceText = ("1. models/linear/acoustic_field/config/params.json`r`n2. 结构参考配置补齐与当前主线基线`r`n3. scripts/comsol_common.ps1 中当前质量档位规则（Quality = {0}）" -f [string]$StudyManifest.quality)
    Add-TextBox -Slide $slide -Left 42 -Top 134 -Width 390 -Height 96 -Text $sourceText -FontSize 12 -ColorHex "#334155"

    $card2 = $slide.Shapes.AddShape(1, 482, 88, 452, 160)
    Set-SolidFill -Shape $card2 -Hex "#F8FAFC"
    Set-SolidLine -Shape $card2 -Hex "#D6E0EF" -Weight 1
    Add-TextBox -Slide $slide -Left 498 -Top 102 -Width 412 -Height 24 -Text "扫描参数口径" -FontSize 18 -ColorHex "#0F2A56" -Bold
    $scanText = ("L_free：基准 {0} cm；范围 {1}`r`nx0_ratio：基准 {2}；范围 {3}`r`nb：基准 {4} cm；范围 {5}`r`nh：基准 {6} mm；范围 {7}`r`nJ：基准 {8} N·s；范围 {9}" -f `
        (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.L_free_cm) -Format "0.##"), `
        (Format-RangeDisplay -Values $StudyManifest.scan_values.l_free_values_cm -Unit "cm" -Format "0.##"), `
        (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.x0_ratio) -Format "0.##"), `
        (Format-RangeDisplay -Values $StudyManifest.scan_values.x0_ratios -Unit "" -Format "0.##"), `
        (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.b_cm) -Format "0.##"), `
        (Format-RangeDisplay -Values $StudyManifest.scan_values.width_values_cm -Unit "cm" -Format "0.##"), `
        (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.h_mm) -Format "0.##"), `
        (Format-RangeDisplay -Values $StudyManifest.scan_values.thickness_values_mm -Unit "mm" -Format "0.##"), `
        (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.J_Ns) -Format "0.##"), `
        (Format-RangeDisplay -Values $StudyManifest.scan_values.impulse_values_ns -Unit "N·s" -Format "0.##"))
    Add-TextBox -Slide $slide -Left 498 -Top 134 -Width 412 -Height 100 -Text $scanText -FontSize 12 -ColorHex "#334155"

    $card3 = $slide.Shapes.AddShape(1, 26, 274, 908, 212)
    Set-SolidFill -Shape $card3 -Hex "#FFF9ED"
    Set-SolidLine -Shape $card3 -Hex "#E7C487" -Weight 1
    Add-TextBox -Slide $slide -Left 42 -Top 288 -Width 360 -Height 24 -Text "PPT 组织规则" -FontSize 18 -ColorHex "#7C4A03" -Bold
    $rulesText = ("- 仅保留 acoustic_field 当前主线。`r`n- 所有参数页统一为 [参数名 / 数学公式 / 设置值]。`r`n- 第一列中的符号与第二列公式都使用 PowerPoint 原生 OfficeMath 对象。`r`n- 扫描参数使用 [基准值 + 范围] 展示；非扫描参数给出当前主线值。`r`n- 当前主线空气域设置：air_radius = {0}，mic_distance = {1}，acoustic_source_model = {2}。" -f `
        (Format-QuantityDisplay -Text ([string]$ResolvedConfig.acoustics.air_radius) -DisplayUnit "cm" -Format "0.##"), `
        (Format-QuantityDisplay -Text ([string]$ResolvedConfig.acoustics.mic_distance) -DisplayUnit "cm" -Format "0.##"), `
        [string]$ResolvedConfig.acoustics.acoustic_source_model)
    Add-TextBox -Slide $slide -Left 42 -Top 320 -Width 872 -Height 148 -Text $rulesText -FontSize 12 -ColorHex "#7C4A03"

    return $slide
}

$studyManifest = Read-JsonUtf8 -Path $StudyManifestPath
$resolvedConfig = New-ResolvedBaselineConfig -StudyManifest $studyManifest
$baseline = $studyManifest.baseline

$tauSeconds = (Convert-QuantityString -Text ([string]$resolvedConfig.excitation.tau_imp)).value
$jBaseline = [double]$baseline.J_Ns
$useImpulse = [double]$resolvedConfig.excitation.use_impulse
$fimpPeak = $useImpulse * $jBaseline / ($tauSeconds * [Math]::Sqrt([Math]::PI))
$areaMm2 = ([double]$baseline.b_cm * 10.0) * [double]$baseline.h_mm
$inertiaMm4 = ([double]$baseline.b_cm * 10.0) * [Math]::Pow([double]$baseline.h_mm, 3) / 12.0
$srcRadiusCm = 0.5 * [double]$baseline.b_cm
$tImpMs = 5.0 * $tauSeconds * 1000.0

$slide1Entries = @()
$slide1Entries += (New-Entry -Name "总长度" -Symbol "L_(total)" -Formula "L_(total)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.geometry.L_total) -DisplayUnit "cm" -Format "0.##"))
$slide1Entries += (New-Entry -Name "自由端长度" -Symbol "L_(free)" -Formula "L_(free)" -Value ("基准：{0} cm`r`n范围：{1}" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm) -Format "0.##"), (Format-RangeDisplay -Values $studyManifest.scan_values.l_free_values_cm -Unit "cm" -Format "0.##")))
$slide1Entries += (New-Entry -Name "计算长度别名" -Symbol "L" -Formula "L=L_(free)" -Value ("{0} cm (= L_free)" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm) -Format "0.##")))
$slide1Entries += (New-Entry -Name "梁宽度" -Symbol "b" -Formula "b" -Value ("基准：{0} cm`r`n范围：{1}" -f (Format-InvariantNumber -Value ([double]$baseline.b_cm) -Format "0.##"), (Format-RangeDisplay -Values $studyManifest.scan_values.width_values_cm -Unit "cm" -Format "0.##")))
$slide1Entries += (New-Entry -Name "梁厚度" -Symbol "h" -Formula "h" -Value ("基准：{0} mm`r`n范围：{1}" -f (Format-InvariantNumber -Value ([double]$baseline.h_mm) -Format "0.##"), (Format-RangeDisplay -Values $studyManifest.scan_values.thickness_values_mm -Unit "mm" -Format "0.##")))
$slide1Entries += (New-Entry -Name "梁厚度别名" -Symbol "h_(beam)" -Formula "h_(beam)=h" -Value ("{0} mm (= h)" -f (Format-InvariantNumber -Value ([double]$baseline.h_mm) -Format "0.##")))
$slide1Entries += (New-Entry -Name "材料密度" -Symbol "ρ" -Formula "ρ" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.material.rho) -DisplayUnit "kg/m^3" -Format "0"))
$slide1Entries += (New-Entry -Name "杨氏模量" -Symbol "E" -Formula "E" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.material.E) -DisplayUnit "GPa" -Format "0.###"))

$slide2Entries = @()
$slide2Entries += (New-Entry -Name "泊松比" -Symbol "ν" -Formula "ν" -Value ([string]$resolvedConfig.material.nu))
$slide2Entries += (New-Entry -Name "根部边界" -Symbol "BC_(root)" -Formula "BC_(root)" -Value ([string]$resolvedConfig.boundary.root))
$slide2Entries += (New-Entry -Name "自由端边界" -Symbol "BC_(tip)" -Formula "BC_(tip)" -Value ([string]$resolvedConfig.boundary.tip))
$slide2Entries += (New-Entry -Name "激励模式" -Symbol "mode_(exc)" -Formula "mode_(exc)" -Value ([string]$resolvedConfig.excitation.mode))
$slide2Entries += (New-Entry -Name "撞击位置" -Symbol "x_0" -Formula "x_0=η_x L_(free)" -Value ("基准：η_x = {0}，x_0 = {1} cm`r`n范围：η_x = {2}" -f (Format-InvariantNumber -Value ([double]$baseline.x0_ratio) -Format "0.##"), (Format-InvariantNumber -Value ([double]$baseline.x0_cm) -Format "0.##"), (Format-RangeDisplay -Values $studyManifest.scan_values.x0_ratios -Unit "" -Format "0.##")))
$slide2Entries += (New-Entry -Name "是否启用冲量" -Symbol "χ_(imp)" -Formula "χ_(imp)∈{0,1}" -Value ("{0} (启用)" -f ([string]$resolvedConfig.excitation.use_impulse)))
$slide2Entries += (New-Entry -Name "冲量" -Symbol "J" -Formula "J" -Value ("基准：{0} N·s`r`n范围：{1}" -f (Format-InvariantNumber -Value ([double]$baseline.J_Ns) -Format "0.##"), (Format-RangeDisplay -Values $studyManifest.scan_values.impulse_values_ns -Unit "N·s" -Format "0.##")))
$slide2Entries += (New-Entry -Name "初始自由端位移" -Symbol "u_(tip,0)" -Formula "u_(tip,0)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.excitation.initial_tip_displacement) -DisplayUnit "m" -Format "0"))

$slide3Entries = @()
$slide3Entries += (New-Entry -Name "脉冲宽度参数" -Symbol "τ_(imp)" -Formula "τ_(imp)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.excitation.tau_imp) -DisplayUnit "ms" -Format "0.###"))
$slide3Entries += (New-Entry -Name "脉冲形状标签" -Symbol "s_(pulse)" -Formula "s_(pulse)" -Value ([string]$resolvedConfig.excitation.pulse_shape))
$slide3Entries += (New-Entry -Name "保留模态数" -Symbol "N_(modes)" -Formula "N_(modes)" -Value ([string]$resolvedConfig.studies.eigen_modes))
$slide3Entries += (New-Entry -Name "本征搜索阶数" -Symbol "N_(search)" -Formula "N_(search)" -Value ([string]$resolvedConfig.studies.eigen_search_modes))
$slide3Entries += (New-Entry -Name "本征 shift" -Symbol "f_(shift)" -Formula "f_(shift)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.studies.eig_shift) -DisplayUnit "Hz" -Format "0"))
$slide3Entries += (New-Entry -Name "瞬态结束时间" -Symbol "T_(end)" -Formula "T_(end)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.studies.time_end) -DisplayUnit "ms" -Format "0.###"))
$slide3Entries += (New-Entry -Name "时间步长" -Symbol "Δt" -Formula "Δt" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.studies.time_step) -DisplayUnit "μs" -Format "0.###"))
$slide3Entries += (New-Entry -Name "模态采样点数" -Symbol "N_(x)" -Formula "N_(x)" -Value ([string]$resolvedConfig.studies.mode_points))

$slide4Entries = @()
$slide4Entries += (New-Entry -Name "梁网格单元数" -Symbol "N_(e)" -Formula "N_(e)" -Value ([string]$resolvedConfig.mesh.numelem))
$slide4Entries += (New-Entry -Name "是否启用空气域" -Symbol "χ_(air)" -Formula "χ_(air)∈{0,1}" -Value ("{0} (启用)" -f (([string]$resolvedConfig.acoustics.use_air_domain).ToLowerInvariant())))
$slide4Entries += (New-Entry -Name "外空气球半径" -Symbol "R_(air)" -Formula "R_(air)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.acoustics.air_radius) -DisplayUnit "cm" -Format "0.##"))
$slide4Entries += (New-Entry -Name "麦克风距离" -Symbol "d_(mic)" -Formula "d_(mic)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.acoustics.mic_distance) -DisplayUnit "cm" -Format "0.##"))
$slide4Entries += (New-Entry -Name "空气密度" -Symbol "ρ_(air)" -Formula "ρ_(air)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.acoustics.rho_air) -DisplayUnit "kg/m^3" -Format "0.###"))
$slide4Entries += (New-Entry -Name "空气声速" -Symbol "c_(air)" -Formula "c_(air)" -Value (Format-QuantityDisplay -Text ([string]$resolvedConfig.acoustics.c_air) -DisplayUnit "m/s" -Format "0"))
$slide4Entries += (New-Entry -Name "声源模型" -Symbol "model_(src)" -Formula "model_(src)" -Value ([string]$resolvedConfig.acoustics.acoustic_source_model))
$slide4Entries += (New-Entry -Name "内源球半径" -Symbol "r_(src)" -Formula "r_(src)=0.5 b" -Value ("{0} cm (= 0.5 b)" -f (Format-InvariantNumber -Value $srcRadiusCm -Format "0.##")))

$slide5Entries = @()
$slide5Entries += (New-Entry -Name "声源中心 x 坐标" -Symbol "x_(src)" -Formula "x_(src)=L_(free)" -Value ("{0} cm (= L_free)" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm) -Format "0.##")))
$slide5Entries += (New-Entry -Name "声源中心 y 坐标" -Symbol "y_(src)" -Formula "y_(src)=0" -Value "0")
$slide5Entries += (New-Entry -Name "声源中心 z 坐标" -Symbol "z_(src)" -Formula "z_(src)=0" -Value "0")
$slide5Entries += (New-Entry -Name "外空气球中心 x" -Symbol "x_(air)" -Formula "x_(air)=x_(src)" -Value ("{0} cm (= x_src)" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm) -Format "0.##")))
$slide5Entries += (New-Entry -Name "外空气球中心 y" -Symbol "y_(air)" -Formula "y_(air)=0" -Value "0")
$slide5Entries += (New-Entry -Name "外空气球中心 z" -Symbol "z_(air)" -Formula "z_(air)=0" -Value "0")
$slide5Entries += (New-Entry -Name "麦克风 x 坐标" -Symbol "x_(mic)" -Formula "x_(mic)=x_(src)" -Value ("{0} cm (= x_src)" -f (Format-InvariantNumber -Value ([double]$baseline.L_free_cm) -Format "0.##")))
$slide5Entries += (New-Entry -Name "麦克风 y 坐标" -Symbol "y_(mic)" -Formula "y_(mic)=0" -Value "0")

$micDistanceText = (Format-QuantityDisplay -Text ([string]$resolvedConfig.acoustics.mic_distance) -DisplayUnit "cm" -Format "0.##")
$micDistanceValue = $micDistanceText.Split(" ")[0]

$slide6Entries = @()
$slide6Entries += (New-Entry -Name "麦克风 z 坐标" -Symbol "z_(mic)" -Formula "z_(mic)=d_(mic)" -Value ("{0} cm (= mic_distance)" -f $micDistanceValue))
$slide6Entries += (New-Entry -Name "梁截面积" -Symbol "A" -Formula "A=b h_(beam)" -Value ("{0} mm^2" -f (Format-InvariantNumber -Value $areaMm2 -Format "0.###")))
$slide6Entries += (New-Entry -Name "截面惯性矩" -Symbol "I" -Formula "I=(b h_(beam)^3)/12" -Value ("{0} mm^4" -f (Format-InvariantNumber -Value $inertiaMm4 -Format "0.###")))
$slide6Entries += (New-Entry -Name "冲击中心时刻" -Symbol "t_(imp)" -Formula "t_(imp)=5 τ_(imp)" -Value ("{0} ms" -f (Format-InvariantNumber -Value $tImpMs -Format "0.###")))
$slide6Entries += (New-Entry -Name "冲击载荷表达式" -Symbol "F_(imp)(t)" -Formula "F_(imp)=(χ_(imp) J)/(τ_(imp) √π) e^(-((t-t_(imp))^2)/(τ_(imp)^2))" -Value ("时变函数`r`n基线峰值系数约：{0} N" -f (Format-InvariantNumber -Value $fimpPeak -Format "0.###")))

$slides = @(
    [pscustomobject]@{ title = "几何与材料参数（1/6）"; subtitle = "空气域主线的几何、截面与材料参数。"; entries = $slide1Entries },
    [pscustomobject]@{ title = "边界与激励参数（2/6）"; subtitle = "空气域模型沿用梁结构边界条件，并以冲击载荷驱动。"; entries = $slide2Entries },
    [pscustomobject]@{ title = "求解控制参数（3/6）"; subtitle = "本页对应当前 Quality 档位下的求解步长、模态数量与导出采样设置。"; entries = $slide3Entries },
    [pscustomobject]@{ title = "空气域与声源参数（4/6）"; subtitle = "空气域只围绕 acoustic_field 主线，采用 surface_velocity 声源模型。"; entries = $slide4Entries },
    [pscustomobject]@{ title = "位置参数（5/6）"; subtitle = "声源中心、外空气球中心与麦克风位置都由 beam tip 与 mic_distance 派生。"; entries = $slide5Entries },
    [pscustomobject]@{ title = "派生参数（6/6）"; subtitle = "这些量不单独扫描，但会直接进入 COMSOL 方程或声源边界表达式。"; entries = $slide6Entries }
)

$application = $null
$presentation = $null
$tempPath = [System.IO.Path]::ChangeExtension($PptPath, ".tmp.pptx")

try {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    $application = New-Object -ComObject PowerPoint.Application
    $application.Visible = -1
    $presentation = $application.Presentations.Add()
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540

    Add-CoverSlide -Application $application -Presentation $presentation -StudyManifest $studyManifest | Out-Null
    foreach ($slideSpec in $slides) {
        Add-ParameterSlide -Application $application -Presentation $presentation -Title $slideSpec.title -Subtitle $slideSpec.subtitle -Entries $slideSpec.entries | Out-Null
    }
    Add-NotesSlide -Presentation $presentation -StudyManifest $studyManifest -ResolvedConfig $resolvedConfig | Out-Null

    $presentation.SaveAs($tempPath)
    $presentation.Close()
    $presentation = $null
    $application.Quit()
    $application = $null

    Move-Item -LiteralPath $tempPath -Destination $PptPath -Force
    Write-Host ("Generated PPT: {0}" -f $PptPath)
}
finally {
    if ($null -ne $presentation) {
        try { $presentation.Close() } catch { }
    }
    if ($null -ne $application) {
        try { $application.Quit() } catch { }
    }
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}
