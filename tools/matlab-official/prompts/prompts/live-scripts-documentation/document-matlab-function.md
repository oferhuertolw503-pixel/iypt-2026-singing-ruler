---
title: Document MATLAB Function
description: Generate comprehensive documentation for MATLAB functions following MathWorks standards
tags: [matlab, documentation, help, comments, examples, function]
release: All releases
notes:
---

# Document MATLAB Function

Generate comprehensive documentation for MATLAB functions including syntax, examples, and See Also sections following MathWorks documentation standards.

## Metadata

- **Tags:** `matlab` `documentation` `help` `comments` `examples` `function`
- **MATLAB Release:** All releases
- **Required Toolboxes:** None

## The Prompt

```text
Create comprehensive documentation for the following MATLAB function. Include:

1. H1 line (first comment line with brief description)
2. Syntax section showing all calling forms
3. Description section with detailed explanation
4. Input Arguments section with types and descriptions
5. Output Arguments section with types and descriptions
6. Examples section with 2-3 practical examples
7. See Also section with related functions

Format using standard MATLAB help style with proper indentation and spacing.

Function to document: [FUNCTION_NAME]
```

## Usage Tips

1. **Provide the function signature** or paste the entire function code for best results
2. **Mention specific use cases** if you want examples tailored to your application
3. **Request specific formatting** if you need particular doc styles (e.g., for publishing)
4. **Include edge cases** you want documented

## Example Usage

### Example 1: Document Existing Function

```
Function to document: myFilter(signal, cutoffFreq, fs)

This function applies a lowpass butterworth filter to a signal.
```

### Example 2: Document with Specific Requirements

```
Function to document: calculateMetrics(data, options)

Include examples for:
- Basic usage with default options
- Advanced usage with custom parameters
- Error handling scenarios

Mention related functions: preprocessData, visualizeMetrics
```

### Example 3: Generate Function and Documentation Together

```
Create a MATLAB function that performs principal component analysis on a data matrix and returns the principal components, explained variance, and scores. Include full documentation with:

1. H1 line
2. Syntax for all calling forms (with and without optional outputs)
3. Detailed description of PCA algorithm used
4. Input/output argument documentation
5. Three examples: basic usage, retaining specific variance, and visualization
6. See Also section with related functions like pca, svd, cov
```

## Expected Output Structure

The AI should generate documentation in this format:

```matlab
function [output1, output2] = myFunction(input1, input2, options)
%MYFUNCTION Brief one-line description
%   MYFUNCTION(INPUT1, INPUT2) detailed description of what the function
%   does with two inputs.
%
%   [OUTPUT1, OUTPUT2] = MYFUNCTION(INPUT1, INPUT2, OPTIONS) extended
%   description with optional arguments and multiple outputs.
%
%   Syntax:
%       output1 = myFunction(input1, input2)
%       [output1, output2] = myFunction(input1, input2, options)
%
%   Description:
%       Detailed explanation of the function's purpose and behavior.
%
%   Input Arguments:
%       input1 - Description of first input (type, size, units)
%       input2 - Description of second input (type, size, units)
%       options - (optional) Structure with fields:
%           field1 - Description (default: value)
%           field2 - Description (default: value)
%
%   Output Arguments:
%       output1 - Description of first output (type, size, units)
%       output2 - Description of second output (type, size, units)
%
%   Examples:
%       % Example 1: Basic usage
%       result = myFunction(data1, data2);
%
%       % Example 2: With options
%       opts.field1 = value;
%       [result, info] = myFunction(data1, data2, opts);
%
%   See Also:
%       relatedFunction1, relatedFunction2, relatedToolboxFunction
%
%   References:
%       [1] Author, "Paper Title", Journal, Year

% Function implementation follows...
```

## Best Practices

- **H1 Line:** Keep under 80 characters, use UPPERCASE function name
- **Wrapping:** Wrap long lines at ~75 characters with proper continuation
- **Examples:** Include practical, runnable examples
- **Types:** Specify expected data types (double, char, table, etc.)
- **Sizes:** Mention expected dimensions (scalar, vector, M-by-N matrix)
- **Units:** Document physical units where applicable
- **Defaults:** Show default values for optional arguments
- **Cross-references:** Link to related functions users might need

## Related Prompts

- [Generate Plain Text Live Scripts](generate-plain-text-live-script.md) - For tutorial-style documentation
- [Create Unit Tests](../programming/create-unit-tests.md) - Tests complement documentation

## References

- [MATLAB Documentation: Add Help for Your Program](https://www.mathworks.com/help/matlab/matlab_prog/add-help-for-your-program.html)
- [MATLAB Documentation: Create Help Summary](https://www.mathworks.com/help/matlab/matlab_prog/create-help-summary-files-contents-m.html)