---
title: Create Programmatic MATLAB App
description: Build interactive MATLAB apps programmatically using uifigure and UI components for various purposes
tags: [matlab, app-building, ui, programmatic, uifigure, interactive, gui, callbacks, uicomponents]
release: R2016a+ (uifigure introduced)
notes:
---

# Create Programmatic MATLAB App

Build interactive MATLAB apps programmatically using uifigure and UI components for data visualization, calculations, parameter tuning, data analysis, and more.

## Metadata

- **Tags:** `matlab` `app-building` `ui` `programmatic` `uifigure` `interactive` `gui` `callbacks` `uicomponents`
- **MATLAB Release:** R2016a+ (uifigure introduced)
- **Required Toolboxes:** None (Core MATLAB)

## The Prompt

```text
Create a MATLAB programmatic app for [PURPOSE]:

Core Requirements:
1. Create a uifigure window with appropriate title and size
2. Add UI components: [SPECIFY: dropdowns, buttons, sliders, text fields, axes, tables, etc.]
3. Implement layout using [CHOOSE: uigridlayout, flow layout, or custom positioning]
4. Define callback functions for user interactions
5. Include [FUNCTIONALITY: data visualization, calculations, file operations, etc.]

Specific Features:
- [FEATURE 1: e.g., Real-time updates as parameters change]
- [FEATURE 2: e.g., Input validation and error handling]
- [FEATURE 3: e.g., Export or save functionality]
- [FEATURE 4: e.g., Reset or clear options]

The app should:
- Provide immediate feedback to user actions
- Handle errors gracefully with user-friendly messages
- Use appropriate layout for optimal screen usage
- Follow MATLAB app development best practices
- Include clear comments explaining the code structure

Generate the complete MATLAB code for this programmatic app.
```

## Usage Tips

1. **Component Selection:**
   - Dropdowns: For selecting from predefined options
   - Edit fields: For numeric or text input
   - Sliders: For continuous parameter adjustment
   - Buttons: To trigger actions or calculations
   - Tables: For displaying/editing tabular data
   - Checkboxes/Radio buttons: For boolean or exclusive options

2. **Layout Strategy:**
   - Grid layout: Best for structured, aligned components
   - Flow layout: Automatic arrangement for simple apps
   - Custom positioning: Full control over component placement

3. **Data Management:**
   - Use `fig.UserData` for simple data storage
   - Create struct for organized data management
   - Use nested functions to share variables

4. **Callback Organization:**
   - Keep callbacks as nested functions for variable access
   - Separate UI logic from computational logic
   - Use helper functions for complex operations

5. **Performance:**
   - Use `ValueChangingFcn` for real-time slider updates
   - Debounce rapid updates if needed
   - Preallocate data structures

## Example Usage

### Example 1: Plot Type Selector App (Data Visualization)

```text
Create a MATLAB programmatic app for selecting and displaying different plot types:

Core Requirements:
1. Create a uifigure window titled "Plot Viewer"
2. Add dropdown menu with plot types (Surf, Mesh, Waterfall, Contour, Imagesc)
3. Include UIAxes for displaying the selected plot
4. Use grid layout for clean organization
5. Include data visualization using peaks function

Specific Features:
- Immediate plot update when selection changes
- Consistent axes properties across plot types
- Window size of 600x500 pixels
- Label showing current plot type

The app should update the visualization immediately when the user selects a different plot type from the dropdown.
```

### Example 2: Scientific Calculator App (Computation)

```text
Create a MATLAB programmatic app for a scientific calculator:

Core Requirements:
1. Create a uifigure window titled "Calculator"
2. Add two numeric edit fields for input values
3. Dropdown for operations (Add, Subtract, Multiply, Divide, Power, Log, Sin, Cos)
4. Button to perform calculation
5. Label to display results

Specific Features:
- Input validation for numeric values
- Error handling for invalid operations (division by zero, log of negative)
- Clear button to reset all fields
- Keyboard shortcuts for common operations

Layout should use grid with inputs at top, operation selection in middle, and result display at bottom.
```

### Example 3: Parameter Tuning App (Control)

```text
Create a MATLAB programmatic app for tuning filter parameters:

Core Requirements:
1. Create a uifigure with title "Filter Designer"
2. Add sliders for cutoff frequency (0.1 to 0.9) and filter order (1 to 10)
3. Dropdown for filter type (Lowpass, Highpass, Bandpass)
4. Two UIAxes: original signal and filtered signal
5. Include signal processing with real-time updates

Specific Features:
- Generate noisy test signal
- Update filtered signal as sliders move (ValueChangingFcn)
- Checkbox to show/hide frequency response
- Reset button to restore defaults
- Export button to save filter coefficients

Use grid layout with controls on left (300px) and plots on right.
```

### Example 4: Data Analysis App (File Processing)

```text
Create a MATLAB programmatic app for CSV data analysis:

Core Requirements:
1. Create uifigure titled "Data Analyzer"
2. Button to browse and load CSV files
3. UITable to display loaded data
4. Dropdown to select column for analysis
5. UIAxes for histogram visualization

Specific Features:
- Display statistics: mean, median, std, min, max
- Handle missing data gracefully
- Export analysis results to text file
- Clear data button
- Support for multiple file formats (.csv, .txt, .xlsx)

Layout: Top toolbar for file operations, center table for data, bottom panel for statistics and plot.
```

## Expected Output

The AI should generate code structured like:

```matlab
function myApp
    % Create main figure and components
    fig = uifigure('Name', 'App Title', 'Position', [100 100 800 600]);

    % Create layout
    gl = uigridlayout(fig, [rows cols]);
    gl.RowHeight = {'fit', '1x', 'fit'};
    gl.ColumnWidth = {'fit', '1x'};

    % Create UI components
    component1 = uicomponent(gl);
    component1.Layout.Row = 1;
    component1.Layout.Column = 1;

    % Set callbacks
    component1.CallbackProperty = @callbackFunction;

    % Initialize app
    initializeApp();

    % Nested callback functions
    function callbackFunction(src, event)
        % Handle user interaction
    end

    function initializeApp()
        % Set initial state
    end
end
```

## Common Patterns

```matlab
% Pattern 1: Generic callback structure
function handleAction(src, event, additionalArgs)
    try
        % Perform action
        result = processData(src.Value);
        updateDisplay(result);
    catch ME
        uialert(fig, ME.message, 'Error');
    end
end

% Pattern 2: App data storage
fig.UserData = struct(...
    'data', [], ...
    'settings', struct(), ...
    'handles', struct() ...
);

% Pattern 3: Flexible grid layout
gl = uigridlayout(fig, 'RowHeight', {'fit', '1x', 'fit'}, ...
                       'ColumnWidth', {200, '1x'}, ...
                       'Padding', [10 10 10 10]);

% Pattern 4: Real-time slider updates
slider.ValueChangingFcn = @(src,evt) updateLive(evt.Value);
slider.ValueChangedFcn = @(src,evt) updateFinal(src.Value);

% Pattern 5: File loading pattern
function loadFile(~, ~)
    [file, path] = uigetfile({'*.csv;*.txt;*.xlsx', 'Data Files'});
    if file ~= 0
        fullPath = fullfile(path, file);
        data = readData(fullPath);
        processAndDisplay(data);
    end
end

% Pattern 6: Component enable/disable
function setUIState(enabled)
    button.Enable = enabled;
    dropdown.Enable = enabled;
    slider.Enable = enabled;
end
```

## Best Practices

- **Architecture:** Separate UI creation, callbacks, and business logic
- **Code Organization:** Use nested functions for callbacks to access shared variables
- **User Experience:** Provide immediate feedback, validate inputs, handle errors gracefully
- **Performance:** Optimize for responsive UI, use efficient data structures
- **Maintainability:** Comment code clearly, use meaningful variable names, follow consistent style

## Variations

### Minimal App Template

```text
Create the simplest possible MATLAB app with:
- Single input control
- One action button
- Display area for results
- Basic error handling
```

### Advanced Multi-Panel App

```text
Create a complex app with:
- Multiple tabs or panels
- Interconnected components
- Data persistence
- Advanced visualizations
- Export capabilities
```

## Related Prompts

- [Convert Multiple Plots to Tiled Layout](../data-visualization/convert-plots-to-tiledlayout.md) - For static multi-panel figures
- [Create Robust Error Handling](../programming/robust-error-handling.md) - For adding comprehensive error handling
- [Optimize MATLAB Code Performance](../programming/optimize-code-performance.md) - For handling large datasets efficiently

## References

- [MATLAB Documentation: Create Programmatic App](https://www.mathworks.com/help/matlab/creating_guis/create-and-run-a-simple-programmatic-app.html)
- [MATLAB Documentation: App Building Components](https://www.mathworks.com/help/matlab/app-building-components.html)
- [MATLAB Documentation: uifigure](https://www.mathworks.com/help/matlab/ref/uifigure.html)
- [MATLAB Documentation: uigridlayout](https://www.mathworks.com/help/matlab/ref/uigridlayout.html)