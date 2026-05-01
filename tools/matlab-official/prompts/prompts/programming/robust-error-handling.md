---
title: Create Robust Error Handling
description: Add comprehensive error handling and input validation to MATLAB functions
tags: [matlab, error-handling, validation, robustness, arguments, try-catch]
release: R2019b+ for arguments block, all releases for other features
notes:
---

# Create Robust Error Handling

Add comprehensive error handling and input validation to MATLAB functions to make them production-ready and user-friendly.

## Metadata

- **Tags:** `matlab` `error-handling` `validation` `robustness` `arguments` `try-catch`
- **MATLAB Release:** R2019b+ (for arguments block), earlier releases without arguments block
- **Required Toolboxes:** None

## The Prompt

```text
Add robust error handling and input validation to this MATLAB function:

Requirements:
1. Use arguments block for input validation (R2019b+)
2. Add validateattributes or validation functions for inputs
3. Include try-catch blocks for operations that might fail
4. Provide meaningful error messages with error IDs
5. Add assert statements for critical assumptions
6. Include size and type checks for arrays

Maintain the function's original behavior while making it production-ready.

Function code:
[PASTE FUNCTION HERE]
```

## Usage Tips

1. **Specify MATLAB version** if you need backwards compatibility
2. **Mention expected failure modes** if you know specific edge cases
3. **Request warning vs error** for non-critical validation failures
4. **Include usage context** (e.g., user-facing vs internal function)

## Example Usage

### Example 1: Simple Function

```
Function code:

function result = calculateAverage(data)
    result = sum(data) / length(data);
end
```

### Example 2: Function with Multiple Inputs

```
Add robust error handling and input validation to this MATLAB function for R2019b+:

Function code:

function filtered = applyFilter(signal, filterCoeffs, method)
    if strcmp(method, 'fir')
        filtered = filter(filterCoeffs, 1, signal);
    else
        filtered = filter(1, filterCoeffs, signal);
    end
end
```

### Example 3: Matrix Processing Function

```
Add robust error handling and input validation to this MATLAB function. The function will be called by users, so provide helpful error messages.

Function code:

function [U, S, V] = customSVD(matrix, rank)
    [U, S, V] = svd(matrix);
    U = U(:, 1:rank);
    S = S(1:rank, 1:rank);
    V = V(:, 1:rank);
end
```

## Expected Output Pattern

### With Arguments Block (R2019b+)
```matlab
function result = calculateAverage(data, options)
%CALCULATEAVERAGE Compute average of data array

    arguments
        data (:,:) double {mustBeNumeric, mustBeReal, mustBeNonempty}
        options.Method (1,1) string {mustBeMember(options.Method, ["mean", "median"])} = "mean"
        options.IgnoreNaN (1,1) logical = false
    end

    try
        if options.IgnoreNaN
            result = mean(data, 'omitnan');
        else
            result = mean(data);
        end
    catch ME
        error('calculateAverage:ComputationFailed', ...
              'Failed to compute average: %s', ME.message);
    end

    assert(isfinite(result), 'calculateAverage:InfiniteResult', ...
           'Result is infinite. Check input data for extreme values.');
end
```

### Without Arguments Block (Pre-R2019b)
```matlab
function result = calculateAverage(data)
%CALCULATEAVERAGE Compute average of data array

    % Input validation
    validateattributes(data, {'numeric'}, ...
                      {'real', 'nonempty', 'finite'}, ...
                      'calculateAverage', 'data');

    % Check for NaN values
    if any(isnan(data(:)))
        warning('calculateAverage:NaNValues', ...
                'Input contains NaN values which will propagate to result.');
    end

    try
        result = mean(data(:));
    catch ME
        error('calculateAverage:ComputationFailed', ...
              'Failed to compute average: %s', ME.message);
    end

    assert(isfinite(result), 'calculateAverage:InfiniteResult', ...
           'Result is infinite. Check input data for extreme values.');
end
```

## Validation Best Practices

### Use Arguments Block (R2019b+)
- **Built-in validators:** `mustBeNumeric`, `mustBePositive`, `mustBeInteger`, etc.
- **Custom validators:** Create `mustBe*` functions for domain-specific validation
- **Size constraints:** Specify with `(m,n)` or `(:,n)` for flexible dimensions

### Use validateattributes (All versions)
```matlab
validateattributes(var, classes, attributes, funcName, varName)
% classes: {'numeric'}, {'double', 'single'}, etc.
% attributes: {'scalar'}, {'vector'}, {'2d'}, {'positive'}, etc.
```

### Error IDs
Use format: `functionName:ErrorType`
```matlab
error('myFunction:InvalidInput', 'Message here')
```

### Try-Catch for External Operations
Wrap operations that might fail:
- File I/O
- Network operations
- Calls to other toolboxes
- Numerical operations that might fail

## Related Prompts

- [Optimize MATLAB Code Performance](optimize-code-performance.md) - Balance validation with performance
- [Create Unit Tests](create-unit-tests.md) - Test error handling paths

## References

- [MATLAB Documentation: Function Argument Validation](https://www.mathworks.com/help/matlab/matlab_prog/function-argument-validation-1.html)
- [MATLAB Documentation: validateattributes](https://www.mathworks.com/help/matlab/ref/validateattributes.html)