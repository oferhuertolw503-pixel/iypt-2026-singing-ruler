---
title: Create Unit Tests
description: Write comprehensive unit tests using the matlab.unittest framework
tags: [matlab, testing, unit-tests, matlab-test, verification, unittest, quality]
release: R2013a+ (matlab.unittest framework)
notes:
---

# Create Unit Tests

Write unit tests using MATLAB's testing framework for reliable, maintainable code.

## Metadata

- **Tags:** `matlab` `testing` `unit-tests` `matlab-test` `verification` `unittest` `quality`
- **MATLAB Release:** R2013a+ (matlab.unittest framework)
- **Required Toolboxes:** None (unittest is in base MATLAB)

## The Prompt

```text
Create unit tests for the following MATLAB function using the matlab.unittest framework:

Test requirements:
1. Create test class inheriting from matlab.unittest.TestCase
2. Write test methods for normal operation cases
3. Write test methods for edge cases
4. Write test methods for error conditions
5. Use assertions: verifyEqual, verifyError, verifyWarning, verifyTrue
6. Use test fixtures if setup/teardown needed
7. Add parameterized tests for multiple input combinations
8. Include docstrings for each test method

Function to test:
[PASTE FUNCTION HERE]

Expected test coverage: >90% line coverage
```

## Usage Tips

1. **Provide complete function:** Include function signature and implementation
2. **Mention known edge cases:** Helps create comprehensive tests
3. **Specify coverage goals:** Line coverage, branch coverage targets
4. **Request specific test types:** Performance tests, integration tests, etc.

## Example Usage

### Example 1: Simple Function

```
Create unit tests for the following MATLAB function using the matlab.unittest framework:

Function to test:
function result = calculateSum(a, b)
    % Calculate sum of two numbers
    result = a + b;
end

Test requirements:
1-8 as listed above, plus:
- Test with positive numbers
- Test with negative numbers
- Test with zero
- Test with non-scalar inputs (arrays)
- Test with mixed types (int and double)

Expected test coverage: >95% line coverage
```

### Example 2: Signal Processing Function

```
Create unit tests for the following MATLAB function:

Function to test:
function filtered = lowpassFilter(signal, cutoff, fs)
    % Apply lowpass filter to signal
    % Inputs:
    %   signal - input signal vector
    %   cutoff - cutoff frequency (Hz)
    %   fs - sampling frequency (Hz)

    validateattributes(signal, {'numeric'}, {'vector', 'real', 'finite'});
    validateattributes(cutoff, {'numeric'}, {'scalar', 'positive', 'real'});
    validateattributes(fs, {'numeric'}, {'scalar', 'positive', 'real'});

    assert(cutoff < fs/2, 'Cutoff must be less than Nyquist frequency');

    [b, a] = butter(6, cutoff/(fs/2));
    filtered = filter(b, a, signal);
end

Test requirements (1-8 plus):
- Test valid inputs produce correct output shape
- Test error for invalid inputs (empty, NaN, Inf)
- Test error for cutoff >= Nyquist
- Test DC component is attenuated
- Use parameterized tests for different cutoff values
- Setup/teardown for test signal generation
```

### Example 3: Class with State

```
Create comprehensive unit tests for this class:

classdef DataProcessor
    properties
        data
        processingMethod
    end

    methods
        function obj = DataProcessor(initialData)
            obj.data = initialData;
            obj.processingMethod = 'mean';
        end

        function result = process(obj)
            switch obj.processingMethod
                case 'mean'
                    result = mean(obj.data);
                case 'median'
                    result = median(obj.data);
                otherwise
                    error('Unknown method');
            end
        end

        function obj = setMethod(obj, method)
            obj.processingMethod = method;
        end
    end
end

Include tests for:
- Constructor with valid and invalid inputs
- Each processing method
- Method switching
- State persistence
- Error conditions
```

## Test Class Pattern

```matlab
classdef FunctionNameTest < matlab.unittest.TestCase
    % Test class for functionName

    properties (TestParameter)
        % Parameterized test data
        validInput = {1, 2, 3};
        expectedOutput = {2, 4, 6};
    end

    properties
        % Test fixtures
        testData
    end

    methods (TestMethodSetup)
        function createTestData(testCase)
            % Setup before each test
            testCase.testData = magic(5);
        end
    end

    methods (Test)
        function testNormalOperation(testCase)
            % Test normal operation
            result = functionName(testCase.testData);
            testCase.verifyEqual(result, expected);
        end

        function testEdgeCase(testCase)
            % Test edge case
            result = functionName([]);
            testCase.verifyEqual(result, 0);
        end

        function testErrorCondition(testCase)
            % Test error is thrown
            testCase.verifyError(@() functionName(-1), ...
                                'functionName:InvalidInput');
        end

        function testParameterized(testCase, validInput, expectedOutput)
            % Parameterized test
            result = functionName(validInput);
            testCase.verifyEqual(result, expectedOutput);
        end
    end
end
```

## Common Assertions

```matlab
% Equality
testCase.verifyEqual(actual, expected);
testCase.verifyEqual(actual, expected, 'AbsTol', 1e-6);

% Boolean
testCase.verifyTrue(condition);
testCase.verifyFalse(condition);

% Errors and Warnings
testCase.verifyError(@() func(), 'expectedErrorID');
testCase.verifyWarning(@() func(), 'expectedWarningID');

% Size and Class
testCase.verifySize(actual, [m n]);
testCase.verifyClass(actual, 'double');

% Approximate equality
testCase.verifyEqual(actual, expected, 'RelTol', 0.01);

% Not equal
testCase.verifyNotEqual(actual, notExpected);

% Empty/Not empty
testCase.verifyEmpty(actual);
testCase.verifyNotEmpty(actual);

% Numeric comparisons
testCase.verifyGreaterThan(actual, minimum);
testCase.verifyLessThan(actual, maximum);
```

## Running Tests

```matlab
% Run all tests in a file
results = runtests('FunctionNameTest');

% Run specific test
results = runtests('FunctionNameTest/testNormalOperation');

% Run with code coverage
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin

runner = TestRunner.withTextOutput;
runner.addPlugin(CodeCoveragePlugin.forFile('functionName.m'));
results = runner.run(FunctionNameTest);

% Display coverage
disp(results);
```

## Fixtures

```matlab
methods (TestMethodSetup)
    function setupOnce(testCase)
        % Run once before all tests
        testCase.testData = loadData();
    end
end

methods (TestMethodTeardown)
    function teardownOnce(testCase)
        % Run once after all tests
        clearData();
    end
end
```

## Parameterized Tests

```matlab
properties (TestParameter)
    inputValue = {1, 2, 3, 4, 5};
    inputType = {'double', 'single', 'int32'};
end

methods (Test)
    function testWithParameters(testCase, inputValue, inputType)
        % Test runs for each combination
        data = cast(inputValue, inputType);
        result = myFunction(data);
        testCase.verifyClass(result, inputType);
    end
end
```

## Related Prompts

- [Property-Based Testing](property-based-testing.md) - For more comprehensive testing
- [Create Robust Error Handling](../matlab-core-programming/robust-error-handling.md) - What to test
- [Optimize MATLAB Code Performance](../matlab-core-programming/optimize-code-performance.md) - Performance testing

## References

- [MATLAB Documentation: Unit Testing Framework](https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html)
- [MATLAB Documentation: Write Simple Test Case](https://www.mathworks.com/help/matlab/matlab_prog/write-simple-test-case-with-functions.html)
