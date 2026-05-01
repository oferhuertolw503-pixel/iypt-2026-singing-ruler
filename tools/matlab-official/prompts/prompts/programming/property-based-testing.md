---
title: Property-Based Testing
description: Create property-based tests to verify function behavior across input ranges
tags: [matlab, testing, property-based-testing, verification, invariants, fuzzing]
release: All releases
notes:
---

# Property-Based Testing

Create property-based tests that verify function behavior across input ranges by testing mathematical properties and invariants.

## Metadata

- **Tags:** `matlab` `testing` `property-based-testing` `verification` `invariants` `fuzzing`
- **MATLAB Release:** All releases
- **Required Toolboxes:** None

## The Prompt

```text
Create property-based tests for the following MATLAB function:

Test properties to verify:
1. Identify mathematical properties that should hold (e.g., commutativity, associativity)
2. Define invariants that must be preserved
3. Generate random test inputs across valid ranges
4. Verify properties hold for all generated inputs
5. Use tolerance for floating-point comparisons
6. Document the properties being tested

Include tests for:
- Boundary conditions
- Symmetric/commutative properties
- Inverse operations (if applicable)
- Size/shape preservation

Function to test:
[PASTE FUNCTION HERE]
```

## Usage Tips

1. **Identify mathematical properties:** Commutativity, associativity, idempotence, etc.
2. **Define invariants:** What should always be true about the output?
3. **Specify input ranges:** Valid ranges for random input generation
4. **Request number of trials:** How many random inputs to test

## Example Usage

### Example 1: Sorting Function

```
Create property-based tests for the following MATLAB function:

Function to test:
function sorted = customSort(array)
    sorted = sort(array);
end

Test properties to verify:
1. Output is sorted (each element <= next element)
2. Output contains same elements as input (permutation)
3. Output has same length as input
4. Output is same type as input

Generate 1000 random test cases with:
- Array sizes from 0 to 1000
- Different data types (double, int32, etc.)
- Arrays with duplicates
- Already sorted/reverse sorted arrays
```

### Example 2: Matrix Operations

```
Create property-based tests for matrix multiplication:

Function to test:
function C = matrixMultiply(A, B)
    C = A * B;
end

Test properties:
1. Associativity: (AB)C = A(BC)
2. Distributivity: A(B+C) = AB + AC
3. Identity: AI = A
4. Dimension rules: size(A*B) = [size(A,1), size(B,2)]
5. Non-commutativity: usually AB ≠ BA

Generate random matrices of compatible sizes (up to 100x100).
Test with 500 random cases.
Use relative tolerance of 1e-10 for floating-point comparisons.
```

### Example 3: Signal Processing

```
Create property-based tests for a filter function:

Function to test:
function filtered = applyFilter(signal, h)
    filtered = conv(signal, h, 'same');
end

Test properties:
1. Linearity: filter(a*x + b*y) = a*filter(x) + b*filter(y)
2. Time-invariance: filtering delayed signal = delayed filtered signal
3. Causality properties
4. Energy/power relationships
5. Output length equals input length (using 'same')

Generate:
- Random signals (lengths 10-1000)
- Random filter kernels (lengths 3-50)
- Test with 200 random combinations
- Include DC, sinusoidal, and noise signals
```

## Property-Based Testing Pattern

```matlab
function testFunctionProperties()
    % Property-based tests for myFunction

    numTrials = 1000;
    tolerance = 1e-10;

    for trial = 1:numTrials
        % Generate random input
        n = randi([1, 100]);
        input = randn(n, 1);

        % Apply function
        output = myFunction(input);

        % Test Property 1: Size preservation
        assert(isequal(size(input), size(output)), ...
               'Property violation: Size not preserved');

        % Test Property 2: Specific invariant
        assert(abs(sum(output) - sum(input)) < tolerance, ...
               'Property violation: Sum not preserved');

        % Test Property 3: Output bounds
        assert(all(output >= 0), ...
               'Property violation: Negative values in output');
    end

    fprintf('All %d trials passed!\n', numTrials);
end
```

## Common Properties to Test

### Algebraic Properties
```matlab
% Commutativity: f(a,b) = f(b,a)
assert(isequal(func(a, b), func(b, a)));

% Associativity: f(f(a,b),c) = f(a,f(b,c))
assert(isequal(func(func(a,b),c), func(a,func(b,c))));

% Identity: f(a, identity) = a
assert(isequal(func(a, identity), a));

% Idempotence: f(f(a)) = f(a)
assert(isequal(func(func(a)), func(a)));
```

### Inverse Properties
```matlab
% Inverse operation: inverse(f(a)) = a
encoded = encode(data);
decoded = decode(encoded);
assert(isequal(decoded, data));

% Symmetry: if f(a) = b, then f(b) = a
encrypted = encrypt(plaintext, key);
decrypted = decrypt(encrypted, key);
assert(isequal(decrypted, plaintext));
```

### Structural Properties
```matlab
% Size preservation
assert(isequal(size(input), size(output)));

% Type preservation
assert(isa(output, class(input)));

% Monotonicity: if a < b, then f(a) <= f(b)
if a < b
    assert(func(a) <= func(b));
end

% Boundedness: output in valid range
assert(all(output >= lowerBound & output <= upperBound));
```

### Numerical Properties
```matlab
% Sum preservation
assert(abs(sum(output(:)) - sum(input(:))) < tol);

% Energy preservation (Parseval's theorem for FFT)
assert(abs(sum(abs(fft(x)).^2) - length(x)*sum(abs(x).^2)) < tol);

% Mean preservation
assert(abs(mean(output) - mean(input)) < tol);
```

## Random Input Generation

```matlab
% Random arrays with different characteristics
function testData = generateTestData(n)
    choice = randi(5);
    switch choice
        case 1  % Uniform random
            testData = rand(n, 1);
        case 2  % Normal distribution
            testData = randn(n, 1);
        case 3  % Integer values
            testData = randi([-100, 100], n, 1);
        case 4  % Sparse data
            testData = sprand(n, 1, 0.1);
        case 5  % Edge cases
            testData = [0; inf; -inf; eps; realmax];
    end
end
```

## Shrinking Failed Inputs

```matlab
function minimalFailingInput = shrinkInput(failingInput, testFunction)
    % Try to find smaller input that still fails
    current = failingInput;

    while true
        % Try smaller variations
        candidates = generateSmallerInputs(current);
        found = false;

        for i = 1:length(candidates)
            if ~testFunction(candidates{i})
                current = candidates{i};
                found = true;
                break;
            end
        end

        if ~found
            break;
        end
    end

    minimalFailingInput = current;
end
```

## Integration with Unit Tests

```matlab
classdef PropertyBasedTest < matlab.unittest.TestCase
    methods (Test)
        function testCommutativeProperty(testCase)
            for trial = 1:100
                a = randn();
                b = randn();
                testCase.verifyEqual(myFunc(a,b), myFunc(b,a), ...
                    'AbsTol', 1e-10);
            end
        end
    end
end
```

## Related Prompts

- [Create Unit Tests with MATLAB Test](create-unit-tests.md) - For traditional unit testing
- [Create Robust Error Handling](../matlab-core-programming/robust-error-handling.md) - For testing error conditions

## References

- [Property-Based Testing Concepts](https://en.wikipedia.org/wiki/Property_testing)
- [QuickCheck](https://en.wikipedia.org/wiki/QuickCheck) - Original property-based testing framework