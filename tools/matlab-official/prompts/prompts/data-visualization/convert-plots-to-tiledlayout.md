---
title: Convert Multiple Plots to Tiled Layout
description: Transform separate figure windows or subplots into a modern tiled layout using tiledlayout and nexttile
tags: [matlab, visualization, plotting, layout, graphics, tiledlayout, figures, publication]
release: R2019b+ (tiledlayout introduced)
notes:
---

# Convert Multiple Plots to Tiled Layout

Convert multiple separate plots or traditional subplot arrangements into a modern tiled layout using MATLAB's tiledlayout and nexttile functions for cleaner, more flexible multi-panel figures.

## Metadata

- **Tags:** `matlab` `visualization` `plotting` `layout` `graphics` `tiledlayout` `figures` `publication`
- **MATLAB Release:** R2019b+ (tiledlayout introduced)
- **Required Toolboxes:** None (Core MATLAB)

## The Prompt

```text
Convert the following MATLAB plots into a tiled layout using tiledlayout and nexttile:

1. Analyze the existing plotting code
2. Create an appropriate tiledlayout with optimal grid dimensions
3. Replace figure() calls or subplot() with nexttile
4. Preserve all plot properties and customizations
5. Add shared labels and title if appropriate
6. Optimize spacing between tiles
7. Include any shared colorbars or legends
8. Maintain aspect ratios where important

Requirements:
- Use 'flow' layout if the number of plots is unknown
- Set appropriate padding ('compact', 'normal', or 'loose')
- Add tile labels (a, b, c) for publication-ready figures
- Include sgtitle for overall figure title
- Consider shared axes where appropriate

[PASTE YOUR EXISTING PLOTTING CODE HERE]

Generate the complete updated code with the tiled layout implementation.
```

## Usage Tips

1. **Grid dimensions:** Let the AI determine optimal grid size based on your number of plots, or specify if you have preferences (e.g., 2x2, 3x1)
2. **Layout options:** Mention if you want 'flow' (automatic), 'horizontal', or 'vertical' arrangement
3. **Spacing:** Specify if you need 'compact' for publication or 'loose' for presentations
4. **Shared elements:** Indicate if you want shared colorbars, legends, or axis labels
5. **Export ready:** Request export-optimized settings if creating publication figures

## Example Usage

### Example 1: Basic 1x2 Grid Layout

```text
Convert the following MATLAB plots into a tiled layout using tiledlayout and nexttile:

Current code:
figure; surf(peaks(20));
figure; contour(peaks(20));

Requirements:
- Create a 1x2 tiled layout
- Use 'compact' padding for publication
- Add subplot labels (a), (b)
- Add overall title "Peak Function Visualizations"
```

### Example 2: Complex Layout with Shared Colorbar

```text
Convert the following MATLAB plots into a tiled layout using tiledlayout and nexttile:

[X,Y,Z] = peaks(20);

% Plot 1: Surface
figure;
surf(X,Y,Z);
colorbar;
title('3D Surface');

% Plot 2: Contour
figure;
contour(X,Y,Z);
colorbar;
title('Contour Plot');

% Plot 3: Image
figure;
imagesc(Z);
colorbar;
title('Heat Map');

% Plot 4: 3D Line
figure;
plot3(X,Y,Z);
title('3D Line Plot');

Requirements:
- Create a 2x2 tiled layout
- Use a single shared colorbar for the first three plots
- Add axis labels for all plots
- Use 'normal' padding
```

## Expected Output

The AI should generate code that:

- Creates a figure with tiledlayout
- Uses nexttile for each plot
- Preserves all original plot properties
- Implements requested shared elements
- Includes proper spacing and labels

Example structure:
```matlab
figure('Position', [100, 100, 800, 600]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Tile 1
nexttile
surf(X,Y,Z)
title('(a) Surface Plot')

% Tile 2
nexttile
contour(X,Y,Z)
title('(b) Contour Plot')

% Overall title
sgtitle('Multi-Panel Figure')
```

## Common Patterns

```matlab
% Pattern 1: Flow layout for unknown number of plots
t = tiledlayout('flow');

% Pattern 2: Spanning tiles for emphasis
nexttile([2 1]); % Spans 2 rows, 1 column

% Pattern 3: Shared colorbar
nexttile(1); surf(Z);
nexttile(2); imagesc(Z);
c = colorbar;
c.Layout.Tile = 'east'; % Shared on right

% Pattern 4: Linked axes
ax1 = nexttile; plot(x,y1);
ax2 = nexttile; plot(x,y2);
linkaxes([ax1,ax2],'x');
```

## Related Prompts

- [Optimize MATLAB Code Performance](../programming/optimize-code-performance.md) - Optimize plotting code for large datasets
- [Create Live Scripts](../live-scripts-documentation/generate-plain-text-live-script.md) - Document your visualization process

## References

- [MATLAB Documentation: tiledlayout](https://www.mathworks.com/help/matlab/ref/tiledlayout.html)
- [MATLAB Documentation: nexttile](https://www.mathworks.com/help/matlab/ref/nexttile.html)
- [MATLAB Documentation: Combine Multiple Plots](https://www.mathworks.com/help/matlab/creating_plots/combine-multiple-plots.html)
- [MathWorks Blog: tiledlayout Introduction](https://blogs.mathworks.com/graphics-and-apps/2019/10/16/intro-tiledlayout/)
