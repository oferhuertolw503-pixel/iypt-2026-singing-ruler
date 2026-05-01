---
title: Generate C Code from MATLAB
description: Prepare MATLAB functions for C/C++ code generation using MATLAB Coder
tags: [matlab, code-generation, matlab-coder, c-code, embedded, deployment]
release: Requires MATLAB Coder
notes:
---

# Generate C Code from MATLAB

Prepare MATLAB functions for C/C++ code generation using MATLAB Coder with proper compatibility checks and type specifications.

## Metadata

- **Tags:** `matlab` `code-generation` `matlab-coder` `c-code` `embedded` `deployment`
- **MATLAB Release:** Requires MATLAB Coder
- **Required Toolboxes:** MATLAB Coder

## The Prompt

```text
Prepare MATLAB function for C code generation using MATLAB Coder:

Steps:
1. Review function for code generation compatibility
2. Add %#codegen directive
3. Specify input types using coder.typeof or -args
4. Replace unsupported functions with code generation compatible alternatives
5. Add assertions for array sizes and types
6. Create test script with representative inputs
7. Generate C code using codegen command
8. Provide build script for compilation

Function to convert:
[PASTE FUNCTION HERE]

Target: [Desktop/Embedded/MEX]
Input specifications: [TYPES AND SIZES]
```

## Usage Tips

1. **Provide complete function:** Include all dependencies
2. **Specify target platform:** Desktop, embedded, MEX file
3. **Mention constraints:** Fixed-point, memory limits, real-time
4. **Request specific optimizations:** Speed, memory, code size

## Example Usage

### Example 1: Simple Algorithm

```
Prepare MATLAB function for C code generation using MATLAB Coder:

Function to convert:
function y = computeAverage(x)
    y = sum(x) / length(x);
end

Target: Desktop C code
Input specifications: x is double array of size 1-by-N where N is variable (up to 1000)

Include all 8 steps listed above.
```

### Example 2: Signal Processing Function

```
Prepare MATLAB function for C code generation using MATLAB Coder:

Function to convert:
function filtered = filterSignal(signal, filterCoeffs)
    % Apply FIR filter to signal
    filtered = filter(filterCoeffs, 1, signal);
end

Target: Embedded C code (ARM Cortex-M4)
Input specifications:
- signal: double array, size [1024 x 1], fixed size
- filterCoeffs: double array, size [64 x 1], fixed size

Requirements:
- Use fixed-size arrays for all variables
- Optimize for speed
- Generate standalone C code (not MEX)
- Include example main() function for testing
```

### Example 3: Image Processing with Variable Sizes

```
Prepare MATLAB function for C code generation:

Function to convert:
function enhanced = enhanceImage(img)
    % Simple image enhancement
    enhanced = imadjust(img);
    enhanced = medfilt2(enhanced);
end

Target: MEX file for MATLAB
Input specifications: img is uint8 or double, size [M x N] where M and N are variable (up to 2048)

Include:
- Replace imadjust if not supported
- Replace medfilt2 if not supported
- Add input validation
- Generate MEX file
- Provide test script comparing MATLAB vs MEX performance
```

## Code Generation Pattern

### Add Codegen Directive
```matlab
function y = myFunction(x) %#codegen
    % Function implementation
end
```

### Define Input Types
```matlab
% In separate script
% For fixed-size arrays
x_type = coder.typeof(0, [100 1]);

% For variable-size arrays
x_type = coder.typeof(0, [1024 1], [1]);  % Upper bound 1024, lower bound 1

% Generate code
codegen myFunction -args {x_type}
```

### Add Assertions
```matlab
function y = myFunction(x) %#codegen
    % Assert input properties
    assert(isa(x, 'double'));
    assert(isreal(x));
    assert(size(x, 1) <= 1024);

    % Function implementation
    y = process(x);
end
```

### Replace Unsupported Functions
```matlab
% Check if function is supported
% Use coder.target to conditionally execute code

if coder.target('MATLAB')
    % Use MATLAB function
    y = someFunction(x);
else
    % Use codegen-compatible alternative
    y = alternativeFunction(x);
end
```

## Common Replacements

### Variable-Size Arrays
```matlab
% Instead of dynamic allocation:
% output = [];
% for i = 1:n
%     output = [output; process(i)];
% end

% Use preallocated array:
output = zeros(n, 1);
for i = 1:n
    output(i) = process(i);
end
```

### Cell Arrays and Structures
```matlab
% Replace cell arrays with structures or fixed-size arrays
% Replace dynamic structures with fixed-field structures
```

### Unsupported Functions
Check MATLAB Coder compatibility and use alternatives:
- Graphics functions → Remove or wrap in `coder.target('MATLAB')`
- Some toolbox functions → Use algorithmic alternatives
- `eval`, `feval` → Not supported

## Generation Commands

### MEX File
```matlab
codegen myFunction -args {x_type} -o myFunction_mex
```

### Standalone C Library
```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C';
codegen -config cfg myFunction -args {x_type}
```

### C++ Code
```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C++';
codegen -config cfg myFunction -args {x_type}
```

### With Optimizations
```matlab
cfg = coder.config('lib');
cfg.OptimizeFor = 'Speed';  % or 'Memory'
cfg.EnableOpenMP = true;     % Parallel code
codegen -config cfg myFunction -args {x_type}
```

## Testing Pattern

```matlab
% Create test script
x_test = randn(100, 1);

% Generate MEX
codegen myFunction -args {coder.typeof(x_test)}

% Compare results
y_matlab = myFunction(x_test);
y_mex = myFunction_mex(x_test);
assert(isequal(y_matlab, y_mex), 'Results do not match');

% Benchmark
t_matlab = timeit(@() myFunction(x_test));
t_mex = timeit(@() myFunction_mex(x_test));
fprintf('Speedup: %.2fx\n', t_matlab/t_mex);
```

## Related Prompts

- [Optimize MATLAB Code Performance](../programming/optimize-code-performance.md) - Optimize before code generation
- [Create Robust Error Handling](../programming/robust-error-handling.md) - Add validation for inputs
- [Create Unit Tests](../programming/create-unit-tests.md) - Validate generated code

## References

- [MATLAB Documentation: MATLAB Coder](https://www.mathworks.com/help/coder/)
- [MATLAB Documentation: Code Generation Compatibility](https://www.mathworks.com/help/coder/ug/functions-and-objects-supported-for-cc-code-generation.html)