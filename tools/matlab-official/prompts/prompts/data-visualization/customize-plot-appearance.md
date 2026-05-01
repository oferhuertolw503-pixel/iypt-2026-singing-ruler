---
title: Customize Plot Appearance for Publication Quality
description: Create professionally styled plots with custom colors, fonts, markers, and layout
tags: [matlab, visualization, styling, publication, graphics, customization]
release: All releases
notes:
---

# Customize Plot Appearance for Publication Quality

Transform basic MATLAB plots into publication-ready figures with custom colors, fonts, line styles, and professional styling.

## Metadata

- **Tags:** `matlab` `visualization` `styling` `publication` `graphics` `customization`
- **MATLAB Release:** All releases
- **Required Toolboxes:** None

## The Prompt

```text
Customize a MATLAB plot with professional styling following these guidelines:

STYLING BEST PRACTICES:
1. Use dot notation for all property access (e.g., ax.FontSize = 12)
2. Set properties after creating plot objects, not during creation when possible
3. Use consistent color schemes (colorbrewer, built-in schemes, or custom)
4. Specify line widths for visibility (typically 1.5-2.5 for main data)
5. Use marker sizes that balance visibility and clarity (30-100 for scatter)
6. Set font sizes appropriate for the medium (12-14 for screen, 10-12 for print)

COLOR SCHEMES:
- Built-in: 'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter'
- Professional: Use hex colors or RGB triplets for precise control
- Accessibility: Consider colorblind-friendly palettes

TYPOGRAPHY:
- Title: FontSize 14-16, FontWeight 'bold'
- Axis labels: FontSize 12-14
- Tick labels: FontSize 10-12
- Legend: FontSize 10-12
- Use consistent font family throughout

LAYOUT ELEMENTS:
- Grid: Add for easier reading (grid on)
- Box: Keep axes box on for professional look
- Legends: Position to avoid data obscuration
- Margins: Use tight layout or adjust position manually

LINE AND MARKER STYLES:
- LineWidth: 1.5-2.5 for primary data
- LineStyle: '-', '--', '-.', ':' for differentiation
- Markers: 'o', 's', 'd', '^', 'v', '+', 'x'
- MarkerSize: 6-10 for line plots, 30-100 for scatter

Customize a plot for: [DESCRIBE YOUR PLOT AND DESIRED APPEARANCE]

Include:
- Data generation or input
- Plot creation
- Comprehensive styling (colors, fonts, lines, markers)
- Labels, title, legend
- Grid and layout optimization
```

## Usage Tips

1. **Specify the plot type:** Line plot, scatter, bar, surface, etc.
2. **Describe style preferences:** Colors, themes, professional/casual tone
3. **Mention target medium:** Screen display, print publication, presentation slides
4. **Request specific elements:** Grid lines, legends, annotations, error bars
5. **Provide examples:** Reference existing plots or color schemes you like

## Example Usage

### Example 1: Conference Presentation Plot

```text
Customize a MATLAB plot with professional styling following these guidelines:

STYLING BEST PRACTICES:
1. Use dot notation for all property access (e.g., ax.FontSize = 12)
2. Set properties after creating plot objects, not during creation when possible
3. Use consistent color schemes (colorbrewer, built-in schemes, or custom)
4. Specify line widths for visibility (typically 1.5-2.5 for main data)
5. Use marker sizes that balance visibility and clarity (30-100 for scatter)
6. Set font sizes appropriate for the medium (12-14 for screen, 10-12 for print)

COLOR SCHEMES:
- Built-in: 'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter'
- Professional: Use hex colors or RGB triplets for precise control
- Accessibility: Consider colorblind-friendly palettes

TYPOGRAPHY:
- Title: FontSize 14-16, FontWeight 'bold'
- Axis labels: FontSize 12-14
- Tick labels: FontSize 10-12
- Legend: FontSize 10-12
- Use consistent font family throughout

LAYOUT ELEMENTS:
- Grid: Add for easier reading (grid on)
- Box: Keep axes box on for professional look
- Legends: Position to avoid data obscuration
- Margins: Use tight layout or adjust position manually

LINE AND MARKER STYLES:
- LineWidth: 1.5-2.5 for primary data
- LineStyle: '-', '--', '-.', ':' for differentiation
- Markers: 'o', 's', 'd', '^', 'v', '+', 'x'
- MarkerSize: 6-10 for line plots, 30-100 for scatter

Customize a plot for: A line plot comparing three algorithms' performance over time.
Use bold, high-contrast colors suitable for projector display.
Large fonts (16pt title, 14pt labels).
Thick lines (LineWidth 3).
Add legend in upper right.
Use grid lines for clarity.
White background.

Include:
- Data generation or input
- Plot creation
- Comprehensive styling (colors, fonts, lines, markers)
- Labels, title, legend
- Grid and layout optimization
```

### Example 2: Journal Publication Figure

```text
Customize a MATLAB plot with professional styling following these guidelines:

STYLING BEST PRACTICES:
1. Use dot notation for all property access (e.g., ax.FontSize = 12)
2. Set properties after creating plot objects, not during creation when possible
3. Use consistent color schemes (colorbrewer, built-in schemes, or custom)
4. Specify line widths for visibility (typically 1.5-2.5 for main data)
5. Use marker sizes that balance visibility and clarity (30-100 for scatter)
6. Set font sizes appropriate for the medium (12-14 for screen, 10-12 for print)

COLOR SCHEMES:
- Built-in: 'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter'
- Professional: Use hex colors or RGB triplets for precise control
- Accessibility: Consider colorblind-friendly palettes

TYPOGRAPHY:
- Title: FontSize 14-16, FontWeight 'bold'
- Axis labels: FontSize 12-14
- Tick labels: FontSize 10-12
- Legend: FontSize 10-12
- Use consistent font family throughout

LAYOUT ELEMENTS:
- Grid: Add for easier reading (grid on)
- Box: Keep axes box on for professional look
- Legends: Position to avoid data obscuration
- Margins: Use tight layout or adjust position manually

LINE AND MARKER STYLES:
- LineWidth: 1.5-2.5 for primary data
- LineStyle: '-', '--', '-.', ':' for differentiation
- Markers: 'o', 's', 'd', '^', 'v', '+', 'x'
- MarkerSize: 6-10 for line plots, 30-100 for scatter

Customize a plot for: A scatter plot with error bars showing experimental vs. predicted values.
Use grayscale-friendly colors (black, gray shades).
Include diagonal reference line y=x.
Font size 11pt throughout.
Square markers, size 40, filled.
Add R-squared value as text annotation.
Tight layout, no wasted space.
Export-ready at 300 DPI.

Include:
- Data generation or input
- Plot creation
- Comprehensive styling (colors, fonts, lines, markers)
- Labels, title, legend
- Grid and layout optimization
```

### Example 3: Data Dashboard Style

```text
Customize a MATLAB plot with professional styling following these guidelines:

STYLING BEST PRACTICES:
1. Use dot notation for all property access (e.g., ax.FontSize = 12)
2. Set properties after creating plot objects, not during creation when possible
3. Use consistent color schemes (colorbrewer, built-in schemes, or custom)
4. Specify line widths for visibility (typically 1.5-2.5 for main data)
5. Use marker sizes that balance visibility and clarity (30-100 for scatter)
6. Set font sizes appropriate for the medium (12-14 for screen, 10-12 for print)

COLOR SCHEMES:
- Built-in: 'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter'
- Professional: Use hex colors or RGB triplets for precise control
- Accessibility: Consider colorblind-friendly palettes

TYPOGRAPHY:
- Title: FontSize 14-16, FontWeight 'bold'
- Axis labels: FontSize 12-14
- Tick labels: FontSize 10-12
- Legend: FontSize 10-12
- Use consistent font family throughout

LAYOUT ELEMENTS:
- Grid: Add for easier reading (grid on)
- Box: Keep axes box on for professional look
- Legends: Position to avoid data obscuration
- Margins: Use tight layout or adjust position manually

LINE AND MARKER STYLES:
- LineWidth: 1.5-2.5 for primary data
- LineStyle: '-', '--', '-.', ':' for differentiation
- Markers: 'o', 's', 'd', '^', 'v', '+', 'x'
- MarkerSize: 6-10 for line plots, 30-100 for scatter

Customize a plot for: A bar chart showing monthly sales data.
Use a modern color scheme (blues and teals).
Clean, minimal style with light gray background.
Horizontal grid lines only.
Value labels on top of each bar.
No box around axes.
Professional corporate look.

Include:
- Data generation or input
- Plot creation
- Comprehensive styling (colors, fonts, lines, markers)
- Labels, title, legend
- Grid and layout optimization
```

### Example 4: Multi-Series Line Plot

```text
Customize a MATLAB plot with professional styling following these guidelines:

STYLING BEST PRACTICES:
1. Use dot notation for all property access (e.g., ax.FontSize = 12)
2. Set properties after creating plot objects, not during creation when possible
3. Use consistent color schemes (colorbrewer, built-in schemes, or custom)
4. Specify line widths for visibility (typically 1.5-2.5 for main data)
5. Use marker sizes that balance visibility and clarity (30-100 for scatter)
6. Set font sizes appropriate for the medium (12-14 for screen, 10-12 for print)

COLOR SCHEMES:
- Built-in: 'parula', 'jet', 'hsv', 'hot', 'cool', 'spring', 'summer', 'autumn', 'winter'
- Professional: Use hex colors or RGB triplets for precise control
- Accessibility: Consider colorblind-friendly palettes

TYPOGRAPHY:
- Title: FontSize 14-16, FontWeight 'bold'
- Axis labels: FontSize 12-14
- Tick labels: FontSize 10-12
- Legend: FontSize 10-12
- Use consistent font family throughout

LAYOUT ELEMENTS:
- Grid: Add for easier reading (grid on)
- Box: Keep axes box on for professional look
- Legends: Position to avoid data obscuration
- Margins: Use tight layout or adjust position manually

LINE AND MARKER STYLES:
- LineWidth: 1.5-2.5 for primary data
- LineStyle: '-', '--', '-.', ':' for differentiation
- Markers: 'o', 's', 'd', '^', 'v', '+', 'x'
- MarkerSize: 6-10 for line plots, 30-100 for scatter

Customize a plot for: Temperature data from 5 sensors over 24 hours.
Use distinct colors from 'lines' colormap.
Different line styles for each sensor.
Add markers every 4 hours.
Legend with sensor names outside plot area.
Time-formatted x-axis.
Include shaded regions for day/night.

Include:
- Data generation or input
- Plot creation
- Comprehensive styling (colors, fonts, lines, markers)
- Labels, title, legend
- Grid and layout optimization
```

## Expected Output

The AI will generate code like this:

```matlab
% Create data
x = linspace(0, 10, 100);
y1 = sin(x);
y2 = cos(x);
y3 = sin(x) .* exp(-x/10);

% Create figure with specific size
figure('Position', [100 100 800 600]);
ax = axes;

% Create plot objects
h1 = plot(ax, x, y1, 'LineWidth', 2);
hold(ax, 'on');
h2 = plot(ax, x, y2, 'LineWidth', 2);
h3 = plot(ax, x, y3, 'LineWidth', 2);
hold(ax, 'off');

% Customize colors
h1.Color = [0 0.4470 0.7410];  % Blue
h2.Color = [0.8500 0.3250 0.0980];  % Orange
h3.Color = [0.4660 0.6740 0.1880];  % Green

% Customize line styles
h2.LineStyle = '--';
h3.LineStyle = '-.';

% Axis styling
ax.FontSize = 12;
ax.LineWidth = 1.2;
ax.Box = 'on';
grid(ax, 'on');
ax.GridAlpha = 0.3;

% Labels and title
ax.XLabel.String = 'Time (seconds)';
ax.XLabel.FontSize = 14;
ax.YLabel.String = 'Amplitude';
ax.YLabel.FontSize = 14;
title(ax, 'Signal Comparison', 'FontSize', 16, 'FontWeight', 'bold');

% Legend
legend(ax, {'Signal 1', 'Signal 2', 'Signal 3'}, ...
    'Location', 'best', 'FontSize', 11);

% Set limits
xlim(ax, [0 10]);
ylim(ax, [-1.2 1.2]);
```

## Color Palette Examples

**Professional Blue Palette:**
```matlab
colors = [
    0.0000, 0.4470, 0.7410;  % Dark blue
    0.3010, 0.7450, 0.9330;  % Light blue
    0.0000, 0.2470, 0.5410;  % Navy
];
```

**Colorblind-Friendly Palette:**
```matlab
colors = [
    0.0000, 0.0000, 0.0000;  % Black
    0.9000, 0.6000, 0.0000;  % Orange
    0.3500, 0.7000, 0.9000;  % Sky blue
    0.0000, 0.6000, 0.5000;  % Teal
];
```

**Warm Palette:**
```matlab
colors = [
    0.8500, 0.3250, 0.0980;  % Orange
    0.9290, 0.6940, 0.1250;  % Yellow
    0.6350, 0.0780, 0.1840;  % Red
];
```

## Advanced Styling Techniques

**Custom colormap for surfaces:**
```matlab
customMap = [linspace(0,1,256)', linspace(0,0.5,256)', linspace(1,0,256)'];
colormap(ax, customMap);
```

**Transparent fills:**
```matlab
fill(x, y, 'b', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
```

**Annotations and text:**
```matlab
text(ax, 5, 0.8, 'Peak', 'FontSize', 12, 'FontWeight', 'bold');
annotation('arrow', [0.3 0.4], [0.6 0.7]);
```

**Dual y-axes:**
```matlab
yyaxis left
plot(x, y1);
ax.YColor = 'b';
yyaxis right
plot(x, y2);
ax.YColor = 'r';
```

## Export Settings

**For publications:**
```matlab
% Set figure properties
set(gcf, 'Color', 'w');
set(gcf, 'PaperPositionMode', 'auto');

% Export
exportgraphics(gcf, 'figure.png', 'Resolution', 300);
```

**For presentations:**
```matlab
% Larger fonts and thicker lines
set(gcf, 'Position', [100 100 1920 1080]);
exportgraphics(gcf, 'slide.png', 'Resolution', 150);
```

## Best Practices

- **Consistency:** Use the same styling across all figures in a publication/presentation
- **Contrast:** Ensure sufficient contrast for readability
- **Simplicity:** Avoid excessive decoration; let data speak
- **Accessibility:** Consider colorblind viewers; use patterns/line styles too
- **Resolution:** Export at appropriate resolution for target medium

## Troubleshooting

**Problem:** Colors look different when exported
**Solution:** Set figure background to white: `set(gcf, 'Color', 'w')`

**Problem:** Text too small in exported figure
**Solution:** Increase font sizes or use larger figure size before export

**Problem:** Legend obscures data
**Solution:** Position legend outside plot area or use 'best' location

**Problem:** Plot looks cluttered
**Solution:** Reduce number of grid lines, increase white space, simplify

## Related Prompts

- [Create Custom Multi-Panel Visualizations with Tiledlayout](create-custom-tiledlayout.md) - For styled multi-panel figures
- [Create High-Performance Animated Plots](create-animated-plots.md) - For styling animated visualizations

## References

- [MATLAB Documentation: Formatting and Annotation](https://www.mathworks.com/help/matlab/formatting-and-annotation.html)
- [MATLAB Documentation: Graphics Object Properties](https://www.mathworks.com/help/matlab/graphics-object-properties.html)
- [MATLAB Documentation: Colormaps](https://www.mathworks.com/help/matlab/ref/colormap.html)
- [MATLAB Documentation: exportgraphics](https://www.mathworks.com/help/matlab/ref/exportgraphics.html)
