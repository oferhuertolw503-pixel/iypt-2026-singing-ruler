---
title: Process and Enhance Images
description: Perform image enhancement, filtering, and segmentation operations
tags: [matlab, image-processing, computer-vision, enhancement, segmentation, filtering]
release: Requires Image Processing Toolbox
notes:
---

# Process and Enhance Images

Perform image processing operations including enhancement, filtering, and segmentation.

## Metadata

- **Tags:** `matlab` `image-processing` `computer-vision` `enhancement` `segmentation` `filtering`
- **MATLAB Release:** Requires Image Processing Toolbox
- **Required Toolboxes:** Image Processing Toolbox

## The Prompt

```text
Create a MATLAB script to process and enhance images:

Tasks:
1. Read the image using imread
2. Convert to appropriate color space if needed
3. Apply enhancement: [histogram equalization/contrast adjustment/noise reduction]
4. Apply filtering: [gaussian/median/edge detection]
5. Perform segmentation if needed: [thresholding/watershed/active contours]
6. Display original and processed images side by side
7. Add metrics to quantify improvement (PSNR, SSIM, etc.)

Image type: [grayscale/RGB/multispectral]
Processing goal: [DESCRIBE GOAL]
```

## Usage Tips

1. **Describe image characteristics:** Low contrast, noisy, specific features to enhance
2. **State processing goal:** Enhance edges, reduce noise, segment objects
3. **Mention output format:** Display, save to file, further analysis
4. **Request specific metrics:** PSNR, SSIM, SNR for quality assessment

## Example Usage

### Example 1: Basic Enhancement

```
Create a MATLAB script to enhance a low-contrast grayscale image:

Tasks:
1. Read the image using imread
2. Apply histogram equalization
3. Apply contrast adjustment (imadjust)
4. Apply mild gaussian smoothing
5. Display original and processed images side by side
6. Show histograms before and after
7. Calculate PSNR and SSIM if reference available

Image type: grayscale medical image (X-ray)
Processing goal: Improve visibility of bone structures
```

### Example 2: Noise Reduction

```
Create a MATLAB script for noise reduction:

Image type: RGB color photograph with salt-and-pepper noise
Processing goal: Remove noise while preserving edges

Tasks:
- Read noisy image
- Convert to grayscale for processing (keep original for comparison)
- Apply median filter for noise removal
- Apply bilateral filter to preserve edges
- Apply edge detection (Canny) to verify edge preservation
- Display original, noisy, and filtered images
- Calculate PSNR improvement
```

### Example 3: Segmentation

```
Create a MATLAB script for image segmentation:

Image type: RGB image of cells under microscope
Processing goal: Segment and count individual cells

Tasks:
1. Read image and convert to grayscale
2. Enhance contrast with adaptive histogram equalization (adapthisteq)
3. Remove background using morphological operations
4. Apply Otsu's thresholding for binary segmentation
5. Use watershed algorithm to separate touching cells
6. Label and count individual cells
7. Display original image with cell boundaries overlaid
8. Output cell count and average cell size
```

## Common Operations

### Enhancement
```matlab
% Histogram equalization
enhanced = histeq(grayImage);

% Contrast adjustment
adjusted = imadjust(grayImage, [low_in high_in], [low_out high_out]);

% Adaptive histogram equalization
enhanced = adapthisteq(grayImage);

% Gamma correction
gamma_corrected = imadjust(grayImage, [], [], gamma);
```

### Filtering
```matlab
% Gaussian smoothing
smoothed = imgaussfilt(image, sigma);

% Median filter (good for salt-and-pepper noise)
filtered = medfilt2(image, [m n]);

% Bilateral filter (edge-preserving)
filtered = imbilatfilt(image);

% Wiener filter (adaptive noise removal)
filtered = wiener2(image, [m n]);
```

### Edge Detection
```matlab
% Canny edge detector
edges = edge(grayImage, 'Canny');

% Sobel edge detector
edges = edge(grayImage, 'Sobel');

% Prewitt edge detector
edges = edge(grayImage, 'Prewitt');
```

### Segmentation
```matlab
% Otsu's thresholding
level = graythresh(grayImage);
bw = imbinarize(grayImage, level);

% Watershed segmentation
D = bwdist(~bw);
D = -D;
L = watershed(D);

% Active contours
mask = activecontour(image, initialMask, iterations);
```

### Morphological Operations
```matlab
% Erosion
eroded = imerode(bw, strel('disk', radius));

% Dilation
dilated = imdilate(bw, strel('disk', radius));

% Opening (remove small objects)
opened = imopen(bw, strel('disk', radius));

% Closing (fill small holes)
closed = imclose(bw, strel('disk', radius));
```

## Quality Metrics

```matlab
% Peak Signal-to-Noise Ratio
psnrValue = psnr(processed, reference);

% Structural Similarity Index
ssimValue = ssim(processed, reference);

% Mean Squared Error
mseValue = immse(processed, reference);
```

## Display Pattern

```matlab
figure;
subplot(1,2,1);
imshow(original);
title('Original Image');

subplot(1,2,2);
imshow(processed);
title('Processed Image');
```

## Related Prompts

- [Build Neural Network](../ai-data-science-statistics/build-neural-network.md) - For deep learning-based image processing
- [Analyze Signal Spectrum](../signal-processing-communications/analyze-signal-spectrum.md) - For 2D frequency analysis

## References

- [MATLAB Documentation: Image Processing Toolbox](https://www.mathworks.com/help/images/)
- [MATLAB Documentation: Image Enhancement](https://www.mathworks.com/help/images/image-enhancement.html)