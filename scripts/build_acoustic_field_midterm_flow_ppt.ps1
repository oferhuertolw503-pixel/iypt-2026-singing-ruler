[CmdletBinding()]
param(
    [string]$ReferencePptPath = "",
    [string]$StudyManifestPath = "",
    [string]$StudySummaryPath = "",
    [string]$BaselineSummaryPath = "",
    [string]$BaselineResolvedConfigPath = "",
    [string]$OutputPptPath = "",
    [string]$PreviewDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($ReferencePptPath)) {
    $ReferencePptPath = Join-Path $repoRoot "ppt\巨型发声板-正方-徐银.pptx"
}
if ([string]::IsNullOrWhiteSpace($StudyManifestPath)) {
    $StudyManifestPath = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\study_manifest.json"
}
if ([string]::IsNullOrWhiteSpace($StudySummaryPath)) {
    $StudySummaryPath = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\summary.json"
}
if ([string]::IsNullOrWhiteSpace($BaselineSummaryPath)) {
    $BaselineSummaryPath = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\cases\baseline\summary.json"
}
if ([string]::IsNullOrWhiteSpace($BaselineResolvedConfigPath)) {
    $BaselineResolvedConfigPath = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\cases\baseline\params_resolved.json"
}
if ([string]::IsNullOrWhiteSpace($OutputPptPath)) {
    $OutputPptPath = Join-Path $repoRoot "ppt\空气域COMSOL仿真流程_中期汇报.pptx"
}
if ([string]::IsNullOrWhiteSpace($PreviewDir)) {
    $PreviewDir = Join-Path $repoRoot ".codex_tmp\midterm_flow_preview"
}

function Read-JsonUtf8 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Format-InvariantNumber {
    param(
        [Parameter(Mandatory = $true)][double]$Value,
        [string]$Format = "0.##"
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
        [string]$Format = "0.##"
    )

    $quantity = Convert-QuantityString -Text $Text
    $value = $quantity.value

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

    return ("{0} {1}" -f (Format-InvariantNumber -Value $value -Format $Format), $DisplayUnit)
}

function Format-RangeDisplay {
    param(
        [Parameter(Mandatory = $true)][double[]]$Values,
        [string]$Unit = "",
        [string]$Format = "0.##"
    )

    $minValue = ($Values | Measure-Object -Minimum).Minimum
    $maxValue = ($Values | Measure-Object -Maximum).Maximum
    $core = "{0}-{1}" -f (Format-InvariantNumber -Value $minValue -Format $Format), (Format-InvariantNumber -Value $maxValue -Format $Format)
    if ([string]::IsNullOrWhiteSpace($Unit)) {
        return $core
    }
    return ("{0} {1}" -f $core, $Unit)
}

function Get-RgbValue {
    param([Parameter(Mandatory = $true)][string]$Hex)

    $clean = $Hex.TrimStart("#")
    $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    return ($r -bor ($g -shl 8) -bor ($b -shl 16))
}

function Set-TextStyle {
    param(
        [Parameter(Mandatory = $true)]$TextRange,
        [string]$FontName = "Microsoft YaHei",
        [double]$FontSize = 18,
        [string]$ColorHex = "#0F2A56",
        [switch]$Bold
    )

    $TextRange.Font.Name = $FontName
    $TextRange.Font.Size = $FontSize
    $TextRange.Font.Fill.ForeColor.RGB = Get-RgbValue -Hex $ColorHex
    if ($Bold) {
        $TextRange.Font.Bold = -1
    }
    else {
        $TextRange.Font.Bold = 0
    }
}

function Get-ShapeText {
    param([Parameter(Mandatory = $true)]$Shape)

    try {
        if ($Shape.HasTextFrame -eq -1 -or $Shape.TextFrame2.HasText -eq -1) {
            return [string]$Shape.TextFrame2.TextRange.Text
        }
    }
    catch {
    }
    return ""
}

function Find-FirstShapeByText {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    foreach ($shape in @($Slide.Shapes)) {
        $text = Get-ShapeText -Shape $shape
        if (-not [string]::IsNullOrWhiteSpace($text) -and $text.Contains($Pattern)) {
            return $shape
        }
    }

    throw "Shape text containing '$Pattern' was not found on slide $($Slide.SlideIndex)."
}

function Remove-ShapeIfExists {
    param([object]$Shape)

    if ($null -ne $Shape) {
        try { $Shape.Delete() } catch { }
    }
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
    $shape.Left = $Left
    $shape.Top = $Top
    $shape.Width = $Width
    $shape.Height = $Height
    $shape.LockAspectRatio = 0
    $shape.Fill.Visible = 0
    $shape.Line.Visible = 0
    $shape.TextFrame.AutoSize = 0
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame2.MarginLeft = 0
    $shape.TextFrame2.MarginRight = 0
    $shape.TextFrame2.MarginTop = 0
    $shape.TextFrame2.MarginBottom = 0
    $shape.TextFrame2.WordWrap = -1
    $shape.TextFrame2.VerticalAnchor = $VerticalAnchor
    $shape.TextFrame2.AutoSize = 0
    $shape.TextFrame2.TextRange.Text = $Text
    Set-TextStyle -TextRange $shape.TextFrame2.TextRange -FontName $FontName -FontSize $FontSize -ColorHex $ColorHex -Bold:$Bold
    $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = $Alignment
    $shape.Width = $Width
    $shape.Height = $Height
    return $shape
}

function Add-Card {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [string]$FillHex = "#F7F9FD",
        [string]$LineHex = "#D8E0EB",
        [double]$LineWeight = 1.0,
        [int]$ShapeType = 5
    )

    $shape = $Slide.Shapes.AddShape($ShapeType, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = -1
    $shape.Fill.Solid()
    $shape.Fill.ForeColor.RGB = Get-RgbValue -Hex $FillHex
    $shape.Line.Visible = -1
    $shape.Line.ForeColor.RGB = Get-RgbValue -Hex $LineHex
    $shape.Line.Weight = $LineWeight
    return $shape
}

function Add-Tag {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $tag = Add-Card -Slide $Slide -Left $Left -Top $Top -Width $Width -Height $Height -FillHex "#EFC881" -LineHex "#EFC881" -LineWeight 1.0 -ShapeType 1
    $tag.TextFrame2.TextRange.Text = $Text
    $tag.TextFrame2.MarginLeft = 8
    $tag.TextFrame2.MarginRight = 8
    $tag.TextFrame2.MarginTop = 3
    $tag.TextFrame2.MarginBottom = 3
    $tag.TextFrame2.VerticalAnchor = 3
    Set-TextStyle -TextRange $tag.TextFrame2.TextRange -FontName "Microsoft YaHei" -FontSize 14 -ColorHex "#0F2A56" -Bold
    $tag.TextFrame2.TextRange.ParagraphFormat.Alignment = 2
    return $tag
}

function Add-PictureShape {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][string]$ImagePath,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height
    )

    return $Slide.Shapes.AddPicture($ImagePath, $false, $true, $Left, $Top, $Width, $Height)
}

function Add-Line {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$X1,
        [Parameter(Mandatory = $true)][double]$Y1,
        [Parameter(Mandatory = $true)][double]$X2,
        [Parameter(Mandatory = $true)][double]$Y2,
        [string]$Hex = "#0F2A56",
        [double]$Weight = 2.0,
        [switch]$Dashed,
        [switch]$ArrowEnd
    )

    $line = $Slide.Shapes.AddLine($X1, $Y1, $X2, $Y2)
    $line.Line.ForeColor.RGB = Get-RgbValue -Hex $Hex
    $line.Line.Weight = $Weight
    if ($Dashed) {
        $line.Line.DashStyle = 4
    }
    if ($ArrowEnd) {
        $line.Line.EndArrowheadStyle = 3
        $line.Line.EndArrowheadLength = 2
        $line.Line.EndArrowheadWidth = 2
    }
    return $line
}

function Add-FlowBox {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Top,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Body
    )

    $card = Add-Card -Slide $Slide -Left $Left -Top $Top -Width $Width -Height $Height -FillHex "#F8FAFC" -LineHex "#D7E0EE" -LineWeight 1.2
    Add-TextBox -Slide $Slide -Left ($Left + 12) -Top ($Top + 10) -Width ($Width - 24) -Height 24 -Text $Title -FontSize 14.5 -ColorHex "#0F2A56" -Bold | Out-Null
    Add-TextBox -Slide $Slide -Left ($Left + 12) -Top ($Top + 33) -Width ($Width - 24) -Height ($Height - 43) -Text $Body -FontSize 10.8 -ColorHex "#334155" | Out-Null
    return $card
}

function Set-ExistingTextBox {
    param(
        [Parameter(Mandatory = $true)]$Shape,
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$FontName = "Microsoft YaHei",
        [double]$FontSize = 18,
        [string]$ColorHex = "#0F2A56",
        [switch]$Bold
    )

    $Shape.TextFrame2.TextRange.Text = $Text
    Set-TextStyle -TextRange $Shape.TextFrame2.TextRange -FontName $FontName -FontSize $FontSize -ColorHex $ColorHex -Bold:$Bold
}

function Update-PageNumbers {
    param([Parameter(Mandatory = $true)]$Presentation)

    foreach ($slide in @($Presentation.Slides)) {
        foreach ($shape in @($slide.Shapes)) {
            if ($shape.Type -eq 14 -and $shape.Top -ge 500) {
                try {
                    $shape.TextFrame.TextRange.Text = [string]$slide.SlideIndex
                }
                catch {
                }
            }
        }
    }
}

function Remove-MainRegionShapes {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [double]$TopMin = 60,
        [double]$TopMax = 490
    )

    $targets = @()
    foreach ($shape in @($Slide.Shapes)) {
        if ($shape.Top -ge $TopMin -and $shape.Top -le $TopMax) {
            $targets += $shape
        }
    }

    foreach ($shape in $targets) {
        Remove-ShapeIfExists -Shape $shape
    }
}

function Set-CoverSlide {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][hashtable]$Paths
    )

    $photoShape = $null
    foreach ($shape in @($Slide.Shapes)) {
        if ($shape.Type -eq 13 -and $shape.Left -lt 0 -and $shape.Width -gt 500) {
            $photoShape = $shape
            break
        }
    }
    Remove-ShapeIfExists -Shape $photoShape

    $leftPanel = $Slide.Shapes.AddShape(1, 0, 0, 430, 540)
    $leftPanel.Fill.Visible = -1
    $leftPanel.Fill.Solid()
    $leftPanel.Fill.ForeColor.RGB = Get-RgbValue -Hex "#F3F4F6"
    $leftPanel.Line.Visible = 0
    $leftPanel.ZOrder(5) | Out-Null

    Add-PictureShape -Slide $Slide -ImagePath $Paths["amplitude"] -Left 0 -Top 0 -Width 430 -Height 280 | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["mode"] -Left 0 -Top 280 -Width 215 -Height 260 | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["fft"] -Left 215 -Top 280 -Width 215 -Height 260 | Out-Null

    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "7.巨型发声板") -Text "空气域 COMSOL`r`n仿真流程" -FontName "Microsoft YaHei" -FontSize 30 -ColorHex "#F4CC7A" -Bold
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "Giant soundboard") -Text "（Acoustic-Field Modeling Flow）" -FontName "Aptos" -FontSize 15 -ColorHex "#D7DFEA"

    $pillShape = Find-FirstShapeByText -Slide $Slide -Pattern "主控 / 徐银"
    $pillShape.TextFrame2.TextRange.Text = "线性空气域主线"
    Set-TextStyle -TextRange $pillShape.TextFrame2.TextRange -FontName "Microsoft YaHei" -FontSize 13 -ColorHex "#0F2A56" -Bold
    $pillShape.TextFrame2.TextRange.ParagraphFormat.Alignment = 2

    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "学校 | 中国石油大学（华东）") -Text "中期汇报 | 参数选取 / 模型构建（COMSOL） / 汇总后处理（MATLAB）" -FontName "Microsoft YaHei" -FontSize 14 -ColorHex "#FFFFFF"
}

function Set-AgendaSlide {
    param([Parameter(Mandatory = $true)]$Slide)

    $replacements = @(
        [pscustomobject]@{ old = "预实验"; new = "参数选取"; font = "Microsoft YaHei"; size = 22; color = "#0F2A56"; bold = $true },
        [pscustomobject]@{ old = "理论研究"; new = "模型构建"; font = "Microsoft YaHei"; size = 22; color = "#0F2A56"; bold = $true },
        [pscustomobject]@{ old = "实验探究"; new = "求解与导出"; font = "Microsoft YaHei"; size = 22; color = "#0F2A56"; bold = $true },
        [pscustomobject]@{ old = "课题总结"; new = "当前结果"; font = "Microsoft YaHei"; size = 22; color = "#0F2A56"; bold = $true },
        [pscustomobject]@{ old = "参考文献及附录"; new = "参数扫描"; font = "Microsoft YaHei"; size = 22; color = "#0F2A56"; bold = $true },
        [pscustomobject]@{ old = "Pre-experiment"; new = "（Parameter selection）"; font = "Aptos"; size = 13; color = "#B7BBC1"; bold = $false },
        [pscustomobject]@{ old = "Theoretical inquiry"; new = "（Model construction）"; font = "Aptos"; size = 13; color = "#B7BBC1"; bold = $false },
        [pscustomobject]@{ old = "Experimental inquiry"; new = "（Solve and export）"; font = "Aptos"; size = 13; color = "#B7BBC1"; bold = $false },
        [pscustomobject]@{ old = "Summary of the topic"; new = "（Current results）"; font = "Aptos"; size = 13; color = "#B7BBC1"; bold = $false },
        [pscustomobject]@{ old = "References and Appendices"; new = "（Parameter study）"; font = "Aptos"; size = 13; color = "#B7BBC1"; bold = $false }
    )

    foreach ($entry in $replacements) {
        Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern $entry.old) -Text $entry.new -FontName $entry.font -FontSize $entry.size -ColorHex $entry.color -Bold:([bool]$entry.bold)
    }
}

function Set-DividerSlide {
    param([Parameter(Mandatory = $true)]$Slide)

    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "第二部分") -Text "第二部分" -FontName "Microsoft YaHei" -FontSize 26 -ColorHex "#FFFFFF" -Bold
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "理论研究") -Text "空气域模型" -FontName "Microsoft YaHei" -FontSize 42 -ColorHex "#0F2A56" -Bold
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "THEORETICAL INQUIRY") -Text "（Acoustic Field Modeling）" -FontName "Aptos" -FontSize 18 -ColorHex "#B5BAC2"
}

function Set-ParameterSlide {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][object]$StudyManifest,
        [Parameter(Mandatory = $true)][object]$BaselineSummary,
        [Parameter(Mandatory = $true)][object]$ResolvedConfig
    )

    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "3.3 探究施加频率对声音的影响") -Text "2.6 空气域参数选取" -FontName "Microsoft YaHei" -FontSize 26 -ColorHex "#F4CC7A" -Bold
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "实验步骤") -Text "参数口径" -FontName "Microsoft YaHei" -FontSize 18 -ColorHex "#0F2A56" -Bold

    $sourceModel = "surface_velocity"
    if ($ResolvedConfig.PSObject.Properties["acoustics"] -and $ResolvedConfig.acoustics.PSObject.Properties["acoustic_source_model"]) {
        $sourceModel = [string]$ResolvedConfig.acoustics.acoustic_source_model
    }

    $body = @(
        ("结构基线：自由端长度（L_free）= {0} cm，撞击比值（x0/L）= {1}，宽度（b）= {2} cm，厚度（h）= {3} mm。" -f `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.L_free_cm) -Format "0.##"), `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.x0_ratio) -Format "0.##"), `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.b_cm) -Format "0.##"), `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.h_mm) -Format "0.##")),
        ("激励基线：冲量（J）= {0} N·s，冲击激励（impact）作用于 x0 = {1} cm。" -f `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.J_Ns) -Format "0.##"), `
            (Format-InvariantNumber -Value ([double]$StudyManifest.baseline.x0_cm) -Format "0.##")),
        ("空气域：半径（R_air）= {0}，麦克风距离（d_mic）= {1}，声源模型为表面速度源（{2}）。" -f `
            (Format-QuantityDisplay -Text ([string]$BaselineSummary.air_radius) -DisplayUnit "m" -Format "0.##"), `
            (Format-QuantityDisplay -Text ([string]$BaselineSummary.mic_distance) -DisplayUnit "m" -Format "0.##"), `
            $sourceModel),
        ("求解设置：{0} 阶模态，梁单元数（numelem）= {1}，时间步长（Δt）= {2}。" -f `
            ([string]$ResolvedConfig.studies.eigen_modes), `
            ([string]$ResolvedConfig.mesh.numelem), `
            (Format-QuantityDisplay -Text ([string]$ResolvedConfig.studies.time_step) -DisplayUnit "μs" -Format "0.###")),
        "扫描口径统一采用单变量设计（one-at-a-time），基准算例（baseline）只运行一次。"
    ) -join "`r`n"
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "选取长宽分别为40、20cm") -Text $body -FontName "Microsoft YaHei" -FontSize 12.5 -ColorHex "#1F2937"

    foreach ($shape in @($Slide.Shapes)) {
        if ($shape.Type -eq 13 -and $shape.Left -lt 300 -and $shape.Top -gt 120 -and $shape.Top -lt 390) {
            Remove-ShapeIfExists -Shape $shape
        }
    }
    foreach ($text in @("图15  波形图", "图16  降噪前后频谱对比图")) {
        try {
            Remove-ShapeIfExists -Shape (Find-FirstShapeByText -Slide $Slide -Pattern $text)
        }
        catch {
        }
    }

    $leftCards = @(
        [pscustomobject]@{ top = 133; title = "结构基线"; body = "自由端（L_free）= 20 cm`r`n宽度（b）= 3 cm`r`n厚度（h）= 1 mm" },
        [pscustomobject]@{ top = 236; title = "激励基线"; body = "撞击比值（x0/L）= 0.85`r`n冲量（J）= 0.08 N·s`r`n冲击（impact）" },
        [pscustomobject]@{ top = 339; title = "空气域"; body = "半径（R_air）= 0.5 m`r`n距离（d_mic）= 0.06 m`r`n表面速度源（surface_velocity）" }
    )
    foreach ($cardSpec in $leftCards) {
        $card = Add-Card -Slide $Slide -Left 36 -Top $cardSpec.top -Width 238 -Height 78 -FillHex "#F8FAFC" -LineHex "#D6DEEA" -LineWeight 1.0
        Add-TextBox -Slide $Slide -Left 50 -Top ($cardSpec.top + 10) -Width 210 -Height 20 -Text $cardSpec.title -FontSize 15 -ColorHex "#0F2A56" -Bold
        Add-TextBox -Slide $Slide -Left 50 -Top ($cardSpec.top + 30) -Width 210 -Height 40 -Text $cardSpec.body -FontSize 11.5 -ColorHex "#334155"
    }

    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "表3 施加频率变化数据表") -Text "扫描参数基准与范围" -FontName "Microsoft YaHei" -FontSize 16 -ColorHex "#0F2A56" -Bold

    $tableShape = $null
    foreach ($shape in @($Slide.Shapes)) {
        try {
            if ($shape.HasTable -eq -1) {
                $tableShape = $shape
                break
            }
        }
        catch {
        }
    }
    if ($null -eq $tableShape) {
        throw "Parameter slide table was not found."
    }

    $values = @(
        @("参数", "自由端`r`n（L_free）", "撞击位置`r`n（x0_ratio）", "宽度`r`n（b）", "厚度`r`n（h）", "冲量`r`n（J）"),
        @("基准", "20 cm", "0.85", "3 cm", "1 mm", "0.08 N·s"),
        @("范围", "11-29 cm", "0.30-0.95", "0.5-5.5 cm", "0.5-5 mm", "0.02-0.22 N·s"),
        @("设计", "长度单扫", "位置单扫", "宽度单扫", "厚度单扫", "冲量单扫"),
        @("固定项", "其余回到基准算例`r`n（baseline）", "其余回到基准算例`r`n（baseline）", "其余回到基准算例`r`n（baseline）", "其余回到基准算例`r`n（baseline）", "其余回到基准算例`r`n（baseline）")
    )

    for ($r = 1; $r -le $tableShape.Table.Rows.Count; $r++) {
        for ($c = 1; $c -le $tableShape.Table.Columns.Count; $c++) {
            $cellShape = $tableShape.Table.Cell($r, $c).Shape
            $cellShape.TextFrame.TextRange.Text = $values[$r - 1][$c - 1]
            $cellShape.Fill.Visible = -1
            $cellShape.Fill.Solid()
            if ($r -eq 1) {
                $cellShape.Fill.ForeColor.RGB = Get-RgbValue -Hex "#102B57"
                $cellShape.TextFrame.TextRange.Font.Color.RGB = Get-RgbValue -Hex "#FFFFFF"
                $cellShape.TextFrame.TextRange.Font.Bold = -1
                $cellShape.TextFrame.TextRange.Font.Size = 13
            }
            else {
                $fillHex = if (($r % 2) -eq 0) { "#F4F6FA" } else { "#E9EEF6" }
                $cellShape.Fill.ForeColor.RGB = Get-RgbValue -Hex $fillHex
                $cellShape.TextFrame.TextRange.Font.Color.RGB = Get-RgbValue -Hex "#1F2937"
                $cellShape.TextFrame.TextRange.Font.Bold = 0
                $cellShape.TextFrame.TextRange.Font.Size = 11
            }
            $cellShape.TextFrame.TextRange.Font.Name = "Microsoft YaHei"
            $cellShape.TextFrame.TextRange.ParagraphFormat.Alignment = 2
        }
    }
}

function Set-TwoColumnHeaderSlide {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Summary
    )

    Remove-MainRegionShapes -Slide $Slide
    Set-ExistingTextBox -Shape (Find-FirstShapeByText -Slide $Slide -Pattern "2.6 Comsol数值模拟") -Text $Title -FontName "Microsoft YaHei" -FontSize 24 -ColorHex "#F4CC7A" -Bold
    Add-TextBox -Slide $Slide -Left 16 -Top 73 -Width 820 -Height 48 -Text $Summary -FontSize 13 -ColorHex "#1F2937"
    Add-Line -Slide $Slide -X1 428 -Y1 132 -X2 428 -Y2 448 -Hex "#12386E" -Weight 2.2 -Dashed | Out-Null
}

function Set-BuildFlowSlide {
    param([Parameter(Mandatory = $true)]$Slide)

    $summary = "参数脚本（PowerShell）负责解析参数与输出目录；建模批处理（COMSOL Java）负责构建、求解与 CSV 导出；后处理（MATLAB）通过清单（manifest）统一汇总。"
    Set-TwoColumnHeaderSlide -Slide $Slide -Title "2.7 空气域模型构建与求解流程" -Summary $summary

    Add-Tag -Slide $Slide -Left 48 -Top 136 -Width 256 -Height 28 -Text "构建流程（Build Flow）" | Out-Null
    $flowBoxes = @(
        [pscustomobject]@{ left = 24; top = 170; width = 176; height = 52; title = "输入（Inputs）"; body = "参数文件（params.json）`r`n实验清单（study_manifest.json）" },
        [pscustomobject]@{ left = 218; top = 170; width = 176; height = 52; title = "参数脚本（PowerShell）"; body = "build_comsol_model.ps1`r`nparam_study.ps1" },
        [pscustomobject]@{ left = 24; top = 242; width = 176; height = 52; title = "建模求解（COMSOL Java）"; body = "Linear_Acoustic_Field.java" },
        [pscustomobject]@{ left = 218; top = 242; width = 176; height = 52; title = "求解导出（Solve & Export）"; body = "模型文件（.mph）+ 频率 CSV`r`n位移 / 模态 / 麦克风 CSV" },
        [pscustomobject]@{ left = 121; top = 316; width = 176; height = 56; title = "后处理（MATLAB）"; body = "run_matlab_model.ps1`r`nrun_matlab_manifest(...)" }
    )
    foreach ($box in $flowBoxes) {
        Add-FlowBox -Slide $Slide -Left $box.left -Top $box.top -Width $box.width -Height $box.height -Title $box.title -Body $box.body | Out-Null
    }

    Add-Line -Slide $Slide -X1 200 -Y1 196 -X2 217 -Y2 196 -Hex "#D9A85C" -Weight 2.5 -ArrowEnd | Out-Null
    Add-Line -Slide $Slide -X1 112 -Y1 222 -X2 112 -Y2 241 -Hex "#D9A85C" -Weight 2.5 -ArrowEnd | Out-Null
    Add-Line -Slide $Slide -X1 306 -Y1 222 -X2 306 -Y2 241 -Hex "#D9A85C" -Weight 2.5 -ArrowEnd | Out-Null
    Add-Line -Slide $Slide -X1 200 -Y1 268 -X2 217 -Y2 268 -Hex "#D9A85C" -Weight 2.5 -ArrowEnd | Out-Null
    Add-Line -Slide $Slide -X1 209 -Y1 295 -X2 209 -Y2 315 -Hex "#D9A85C" -Weight 2.5 -ArrowEnd | Out-Null

    Add-Tag -Slide $Slide -Left 560 -Top 134 -Width 204 -Height 28 -Text "物理场节点（Physics）" | Out-Null
    $physicsCard = Add-Card -Slide $Slide -Left 472 -Top 168 -Width 408 -Height 116 -FillHex "#F8FAFC" -LineHex "#D8E0EB" -LineWeight 1.0
    Add-TextBox -Slide $Slide -Left 490 -Top 184 -Width 376 -Height 92 -Text "1. Euler-Bernoulli 梁提供结构位移与模态基底。`r`n2. 球形空气域包围梁尖端（beam tip），声源模型为表面速度源（surface_velocity）。`r`n3. 麦克风位于 z = 麦克风距离（mic_distance），输出麦克风声压时程。" -FontSize 11.5 -ColorHex "#334155"

    Add-Tag -Slide $Slide -Left 544 -Top 294 -Width 236 -Height 28 -Text "算例输出合同（Case Bundle）" | Out-Null
    $contractCard = Add-Card -Slide $Slide -Left 490 -Top 326 -Width 353 -Height 108 -FillHex "#F8FAFC" -LineHex "#D8E0EB" -LineWeight 1.0
    Add-TextBox -Slide $Slide -Left 506 -Top 340 -Width 321 -Height 88 -Text "模型文件（.mph）`r`n频率文件（frequencies.csv）`r`n位移时程（tip_timeseries.csv）`r`n模态形状（mode_shapes.csv）`r`n麦克风时程（mic_pressure_timeseries.csv）" -FontSize 11.5 -ColorHex "#334155"
}

function Set-ResultsSlide {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][object]$BaselineSummary,
        [Parameter(Mandatory = $true)][hashtable]$Paths
    )

    $summary = ("基准算例（baseline case）：L_free = 20 cm，x0/L = 0.85，b = 3 cm，h = 1 mm，J = 0.08 N·s。`r`n当前结果：一阶频率（f1）= {0} Hz，二阶频率（f2）= {1} Hz，三阶频率（f3）= {2} Hz，声压级（SPL）= {3} dB，麦克风主频 = {4} Hz。" -f `
        (Format-InvariantNumber -Value ([double]$BaselineSummary.f1_hz) -Format "0.00"), `
        (Format-InvariantNumber -Value ([double]$BaselineSummary.f2_hz) -Format "0.00"), `
        (Format-InvariantNumber -Value ([double]$BaselineSummary.f3_hz) -Format "0.00"), `
        (Format-InvariantNumber -Value ([double]$BaselineSummary.spl_db) -Format "0.00"), `
        (Format-InvariantNumber -Value ([double]$BaselineSummary.f_dom_hz) -Format "0.00"))
    Set-TwoColumnHeaderSlide -Slide $Slide -Title "2.8 基准算例（baseline case）结果" -Summary $summary

    $leftFrame = Add-Card -Slide $Slide -Left 24 -Top 150 -Width 372 -Height 242 -FillHex "#FFF9ED" -LineHex "#F8C0A1" -LineWeight 1.8
    Add-Tag -Slide $Slide -Left 94 -Top 138 -Width 226 -Height 28 -Text "一阶模态（Mode Shape）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["mode"] -Left 36 -Top 164 -Width 348 -Height 210 | Out-Null

    Add-Tag -Slide $Slide -Left 554 -Top 126 -Width 252 -Height 28 -Text "前 6 阶固有频率（Modes 1-6）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["frequencies"] -Left 476 -Top 160 -Width 404 -Height 146 | Out-Null

    Add-Tag -Slide $Slide -Left 570 -Top 286 -Width 204 -Height 28 -Text "麦克风频谱（FFT）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["fft"] -Left 490 -Top 320 -Width 353 -Height 126 | Out-Null
}

function Set-ScanSlide {
    param(
        [Parameter(Mandatory = $true)]$Slide,
        [Parameter(Mandatory = $true)][object]$StudySummary,
        [Parameter(Mandatory = $true)][hashtable]$Paths
    )

    $summary = ("全参数实验（all study）采用单变量设计（one-at-a-time）：基准算例（baseline）1 个，J / L_free / x0_ratio / b / h 各 10 个变参算例（case），总计 {0} 个。`r`n真实性核查结果：{1}/{2} 个算例同时具备 .mph、COMSOL 日志与 4 个原始 CSV；MATLAB 统一输出 3 张总览图（overview）与 4 张 CSV。" -f `
        ([string]$StudySummary.case_count), `
        ([string]$StudySummary.provenance_check.case_count_verified_real_comsol), `
        ([string]$StudySummary.provenance_check.case_count_total))
    Set-TwoColumnHeaderSlide -Slide $Slide -Title "2.9 参数扫描流程与汇总输出" -Summary $summary

    Add-Card -Slide $Slide -Left 24 -Top 150 -Width 372 -Height 242 -FillHex "#FFF9ED" -LineHex "#F8C0A1" -LineWeight 1.8 | Out-Null
    Add-Tag -Slide $Slide -Left 76 -Top 138 -Width 272 -Height 28 -Text "振幅实验总览（Amplitude Overview）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["amplitude"] -Left 36 -Top 164 -Width 348 -Height 210 | Out-Null

    Add-Tag -Slide $Slide -Left 534 -Top 126 -Width 304 -Height 28 -Text "频率实验总览（Frequency Overview）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["frequency"] -Left 476 -Top 160 -Width 404 -Height 146 | Out-Null

    Add-Tag -Slide $Slide -Left 550 -Top 286 -Width 268 -Height 28 -Text "音色实验总览（Timbre Overview）" | Out-Null
    Add-PictureShape -Slide $Slide -ImagePath $Paths["timbre"] -Left 490 -Top 320 -Width 353 -Height 126 | Out-Null
}

function Assert-PathExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

$studyManifest = Read-JsonUtf8 -Path $StudyManifestPath
$studySummary = Read-JsonUtf8 -Path $StudySummaryPath
$baselineSummary = Read-JsonUtf8 -Path $BaselineSummaryPath
$baselineResolved = Read-JsonUtf8 -Path $BaselineResolvedConfigPath

$paths = @{
    amplitude = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\figures\linear_amplitude_overview.png"
    frequency = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\figures\linear_frequency_overview.png"
    timbre = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\figures\linear_timbre_overview.png"
    mode = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\cases\baseline\figures\pgmode_mode01.png"
    frequencies = Join-Path $repoRoot "outputs\linear\sweep\study_all_one_at_a_time_coarse_20260418_233835\cases\baseline\figures\frequencies_bar.png"
    fft = Join-Path $repoRoot "outputs\linear\acoustic_field\figures\mic_pressure_fft.png"
}

foreach ($path in @($ReferencePptPath, $StudyManifestPath, $StudySummaryPath, $BaselineSummaryPath, $BaselineResolvedConfigPath) + $paths.Values) {
    Assert-PathExists -Path $path
}

$application = $null
$reference = $null
$presentation = $null

try {
    if (Test-Path -LiteralPath $OutputPptPath) {
        Remove-Item -LiteralPath $OutputPptPath -Force
    }

    $application = New-Object -ComObject PowerPoint.Application
    $application.Visible = -1

    $reference = $application.Presentations.Open($ReferencePptPath, $false, $true, $false)
    $reference.SaveCopyAs($OutputPptPath)
    $reference.Close()
    $reference = $null

    $presentation = $application.Presentations.Open($OutputPptPath, $false, $false, $false)

    $keepIndexes = @(1, 2, 10, 19, 25)
    for ($i = $presentation.Slides.Count; $i -ge 1; $i--) {
        if ($keepIndexes -notcontains $i) {
            $presentation.Slides.Item($i).Delete()
        }
    }

    $presentation.Slides.Item(5).MoveTo(4)
    $presentation.Slides.Item(5).Duplicate() | Out-Null
    $presentation.Slides.Item(5).Duplicate() | Out-Null

    Set-CoverSlide -Slide $presentation.Slides.Item(1) -Paths $paths
    Set-AgendaSlide -Slide $presentation.Slides.Item(2)
    Set-DividerSlide -Slide $presentation.Slides.Item(3)
    Set-ParameterSlide -Slide $presentation.Slides.Item(4) -StudyManifest $studyManifest -BaselineSummary $baselineSummary -ResolvedConfig $baselineResolved
    Set-BuildFlowSlide -Slide $presentation.Slides.Item(5)
    Set-ResultsSlide -Slide $presentation.Slides.Item(6) -BaselineSummary $baselineSummary -Paths $paths
    Set-ScanSlide -Slide $presentation.Slides.Item(7) -StudySummary $studySummary -Paths $paths

    Update-PageNumbers -Presentation $presentation

    $presentation.Save()
    if (Test-Path -LiteralPath $PreviewDir) {
        Remove-Item -LiteralPath $PreviewDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null
    $presentation.Export($PreviewDir, "PNG", 1365, 768)
    $presentation.Close()
    $presentation = $null

    $verify = $application.Presentations.Open($OutputPptPath, $false, $true, $false)
    $verify.Close()

    Write-Host ("Generated PPT: {0}" -f $OutputPptPath)
    Write-Host ("Preview Dir: {0}" -f $PreviewDir)
}
finally {
    if ($null -ne $presentation) {
        try { $presentation.Close() } catch { }
    }
    if ($null -ne $reference) {
        try { $reference.Close() } catch { }
    }
    if ($null -ne $application) {
        try { $application.Quit() } catch { }
    }
}
