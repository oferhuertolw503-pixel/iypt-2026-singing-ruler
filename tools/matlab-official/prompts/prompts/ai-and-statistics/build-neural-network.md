---
title: Build Neural Network with Deep Learning Toolbox
description: Create and train neural networks for classification and regression tasks
tags: [matlab, deep-learning, neural-network, ai, training, classification, regression]
release: Requires Deep Learning Toolbox
notes:
---

# Build Neural Network with Deep Learning Toolbox

Create and train neural networks for classification, regression, or other tasks using Deep Learning Toolbox.

## Metadata

- **Tags:** `matlab` `deep-learning` `neural-network` `ai` `training` `classification` `regression`
- **MATLAB Release:** Requires Deep Learning Toolbox
- **Required Toolboxes:** Deep Learning Toolbox

## The Prompt

```text
Create a MATLAB script to build and train a neural network for [TASK: classification/regression/etc.].

Requirements:
1. Load and preprocess data
2. Define network architecture using layerGraph or layers array
3. Set training options (optimizer, learning rate, epochs, batch size)
4. Train the network with trainnet
5. Evaluate performance on test data
6. Visualize training progress and results
7. Include comments explaining architecture choices

Dataset: [DESCRIBE DATASET]
Input dimensions: [DIMENSIONS]
Output: [OUTPUT DESCRIPTION]
```

## Usage Tips

1. **Be specific about task type:** Classification (how many classes?) or regression
2. **Describe your data:** Image, sequence, tabular, custom format
3. **Mention constraints:** Training time, memory, accuracy requirements
4. **Request specific architectures:** ResNet, LSTM, CNN, custom

## Example Usage

### Example 1: Image Classification

```
Create a MATLAB script to build and train a neural network for image classification.

Requirements:
1. Load and preprocess data
2. Define CNN architecture using layers array
3. Set training options with Adam optimizer
4. Train the network with trainnet
5. Evaluate performance on test data
6. Visualize training progress and confusion matrix
7. Include comments explaining architecture choices

Dataset: 28x28 grayscale images of handwritten digits (0-9)
Input dimensions: 28x28x1
Output: 10 classes (digits 0-9)
```

### Example 2: Time Series Regression

```
Create a MATLAB script to build and train an LSTM network for time series prediction.

Task: Regression (predict next value in sequence)
Dataset: Sensor readings (temperature, pressure, humidity) sampled every minute
Input dimensions: 100 time steps x 3 features
Output: Single predicted value
Requirements: Use LSTM layers, plot predictions vs actual values
```

### Example 3: Custom Architecture

```
Create a MATLAB script to build and train a neural network for binary classification of tabular data.

Dataset: 15 numerical features, 10000 samples
Input dimensions: 1x15 feature vector
Output: Binary classification (0 or 1)

Requirements:
- Use fully connected layers with ReLU activation
- Include dropout for regularization
- Use early stopping based on validation loss
- Plot ROC curve and calculate AUC
- Save the trained model
```

## Common Network Patterns

### Convolutional Neural Network (CNN)
```matlab
% Layer definition for trainnet (without classificationLayer)
layers = [
    imageInputLayer([28 28 1])

    convolution2dLayer(3, 8, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer

    maxPooling2dLayer(2, 'Stride', 2)

    convolution2dLayer(3, 16, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer

    maxPooling2dLayer(2, 'Stride', 2)

    fullyConnectedLayer(10)
    softmaxLayer];

% Train with: net = trainnet(XTrain, YTrain, layers, "crossentropy", options);
```

### LSTM for Sequence Data
```matlab
% Layer definition for trainnet (without classificationLayer)
layers = [
    sequenceInputLayer(numFeatures)
    lstmLayer(128, 'OutputMode', 'last')
    fullyConnectedLayer(numClasses)
    softmaxLayer];

% Train with: net = trainnet(XTrain, YTrain, layers, "crossentropy", options);
```

### Fully Connected (Tabular Data)
```matlab
% Layer definition for trainnet (without classificationLayer)
layers = [
    featureInputLayer(numFeatures)
    fullyConnectedLayer(128)
    reluLayer
    dropoutLayer(0.2)
    fullyConnectedLayer(64)
    reluLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer];

% Train with: net = trainnet(XTrain, YTrain, layers, "crossentropy", options);
```

## Training Options Template

```matlab
% Training options for trainnet
options = trainingOptions('adam', ...
    'InitialLearnRate', 0.001, ...
    'MaxEpochs', 30, ...
    'MiniBatchSize', 128, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {XValidation, YValidation}, ...
    'ValidationFrequency', 30, ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'ExecutionEnvironment', 'auto');

% Train network with trainnet (specify loss function)
% For classification:
net = trainnet(XTrain, YTrain, layers, "crossentropy", options);

% For regression:
% net = trainnet(XTrain, YTrain, layers, "mse", options);
```

## Related Prompts

- [Statistical Analysis with Hypothesis Testing](statistical-analysis-hypothesis-testing.md) - For analyzing model performance
- [Create Unit Tests](../programming/create-unit-tests.md) - For testing data preprocessing

## References

- [MATLAB Documentation: Deep Learning Toolbox](https://www.mathworks.com/help/deeplearning/)
- [MATLAB Documentation: trainnet Function](https://www.mathworks.com/help/deeplearning/ref/trainnet.html)
- [MATLAB Documentation: Create Simple Deep Learning Network](https://www.mathworks.com/help/deeplearning/ug/create-simple-deep-learning-network-for-classification.html)