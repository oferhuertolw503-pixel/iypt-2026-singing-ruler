---
title: Optimize MATLAB Code Performance
description: Analyze and optimize MATLAB code using vectorization, preallocation, and built-in functions
tags: [matlab, performance, optimization, vectorization, profiling, memory]
release: All releases
notes:
---

# Optimize MATLAB Code Performance

Analyze and optimize MATLAB code for better performance using vectorization, preallocation, and built-in functions. Perfect for speeding up slow code and reducing execution time.

## Metadata

- **Tags:** `matlab` `performance` `optimization` `vectorization` `profiling` `memory`
- **MATLAB Release:** All releases
- **Required Toolboxes:** None

## The Prompt

```text
Review the following MATLAB code and optimize it for performance. Focus on:

1. Vectorization - Replace loops with vectorized operations where possible
2. Preallocation - Preallocate arrays before loops
3. Built-in Functions - Use optimized MATLAB built-ins instead of manual implementations
4. Memory Efficiency - Reduce memory allocations and copies
5. Profiling Suggestions - Recommend specific lines to profile if unclear

Provide the optimized code with comments explaining each optimization.

Code to optimize:
[PASTE CODE HERE]
```

## Usage Tips

1. **Include complete code** with function signatures and variable initialization
2. **Mention bottlenecks** if you've already profiled the code
3. **Specify constraints** (e.g., memory limitations, required MATLAB version)
4. **Request benchmarks** if you want timing comparisons

## Example Usage

### Example 1: Basic Loop Optimization

```
Code to optimize:

result = [];
for i = 1:10000
    result = [result; sin(i) * cos(i)];
end
```

### Example 2: Matrix Operations

```
Review the following MATLAB code and optimize it for performance.

Code to optimize:

function output = processData(matrix)
    [m, n] = size(matrix);
    output = zeros(m, n);
    for i = 1:m
        for j = 1:n
            output(i,j) = sqrt(matrix(i,j)^2 + matrix(i,j));
        end
    end
end
```

### Example 3: Data Processing Pipeline

```
Review the following MATLAB code and optimize it for performance. This code processes sensor data and I need it to run in real-time (< 100ms per batch).

Code to optimize:

function filtered = processSensorData(rawData, threshold)
    % rawData is 1000x100 double
    filtered = [];
    for i = 1:size(rawData, 1)
        row = rawData(i, :);
        if mean(row) > threshold
            normalized = (row - min(row)) / (max(row) - min(row));
            filtered = [filtered; normalized];
        end
    end
end
```

## Common Optimizations to Expect

### Preallocation
```matlab
% Before
result = [];
for i = 1:n
    result = [result; computeValue(i)];
end

% After
result = zeros(n, 1);
for i = 1:n
    result(i) = computeValue(i);
end
```

### Vectorization
```matlab
% Before
for i = 1:length(x)
    y(i) = x(i)^2 + 2*x(i) + 1;
end

% After
y = x.^2 + 2*x + 1;
```

### Built-in Functions
```matlab
% Before
total = 0;
for i = 1:length(data)
    total = total + data(i);
end

% After
total = sum(data);
```

### Memory Efficiency
```matlab
% Before
temp = largeMatrix;
result = process(temp);

% After (operate in-place when possible)
result = process(largeMatrix);
```

## Performance Tips

- **Profile first:** Use `profile on` and `profile viewer` to find bottlenecks
- **Vectorize outer loops:** Most performance gain comes from vectorizing outermost loops
- **Use implicit expansion:** MATLAB's implicit expansion (R2016b+) simplifies array operations
- **Avoid growing arrays:** Never grow arrays in loops
- **Use appropriate data types:** Consider `single` vs `double`, sparse matrices, tables
- **Batch operations:** Process data in batches rather than element-by-element
- **Use JIT-friendly code:** Simple loops with primitive operations JIT-compile well

## Related Prompts

- [Create Robust Error Handling](robust-error-handling.md) - For adding validation without sacrificing performance
- [Create Unit Tests](create-unit-tests.md) - For testing that optimizations don't break functionality

## References

- [MATLAB Documentation: Performance and Memory](https://www.mathworks.com/help/matlab/performance-and-memory.html)
- [MATLAB Documentation: Vectorization](https://www.mathworks.com/help/matlab/matlab_prog/vectorization.html)