---
title: Analyze Signal Spectrum
description: Perform frequency-domain analysis with MATLAB Signal Processing Toolbox using nonparametric spectral estimators and helper measurements.
tags: [matlab, signal-processing, spectral-estimation, psd, pspectrum, pwelch, pmtm, periodogram, spectrogram, cpsd, coherence, transfer-function]
release: Requires Signal Processing Toolbox (most functions). Some examples also reference DSP System Toolbox.
notes: 
---

# Analyze Signal Spectrum

Perform frequency-domain analysis using MATLAB’s **nonparametric** spectral estimators and related helpers. Emphasize **built-in analyzers** (`pspectrum`, `pwelch`, `pmtm`, `periodogram`) and measurements (`findpeaks`, `bandpower`, `obw`, `meanfreq`, `medfreq`, `powerbw`, `thd`, `sinad`, `snr`), plus cross-spectral workflows (`cpsd`, `tfestimate`, `mscohere`).

## Metadata

- **Tags:** `matlab` `signal-processing` `spectral-estimation` `psd` `pspectrum` `pwelch` `pmtm` `periodogram` `spectrogram` `coherence`
- **MATLAB Release:** Signal Processing Toolbox (core functions)
- **Required Toolboxes:** Signal Processing Toolbox (most examples).

## The Prompt

```text
Create MATLAB code to analyze the spectral content of a uniformly sampled signal using toolbox estimators and measurements.

Requirements (prioritized, tool-first):
1) Choose an estimator: pspectrum (quick/time-frequency), pwelch (PSD), pmtm (low-variance), or periodogram (basic).
2) Report method, window/tapers, overlap (if any), and the effective resolution bandwidth (RBW).
3) Plot frequency axes in Hz and use correct units on y-axis (Power in dB or PSD in dB/Hz). Label window/tapers and averaging.
4) (Optional) List top-K peaks with frequencies and levels; tie peak spacing/prominence to RBW.
5) (Optional) Compute band/channel power in user-specified bands; report occupied bandwidth (obw) and optionally mean/median/power bandwidth.
6) (Optional) For two-signal workflows, estimate transfer function (tfestimate) and coherence (mscohere); optionally include cross-PSD (cpsd).
7) Provide a short textual summary with key findings (method, RBW, dominant components, band powers, metrics).

Signal details: [DESCRIBE SIGNAL]
Sampling rate: [VALUE] Hz
Intent: [spectrum | PSD | spectrogram | FRF/coherence]
Options: RBW≈[VALUE] Hz | bands=[f1 f2; ...] Hz | nPeaks=[K] | metrics=[SNR SINAD THD] | time/freq limits=[...]
```

## Usage Tips

1. **Start with intent.** Use `pspectrum` for a quick look or a spectrogram; `pwelch` for general PSD/noise floor; `pmtm` when lines are dense or SNR is low; `periodogram` for a fast baseline.
2. **Speak in RBW.** If you need to resolve close tones, increase segment length (or tighten `FrequencyResolution` for `pspectrum`). Zero‑padding only refines the display grid, not the actual resolution.
3. **Be explicit with units.** Power spectrum (dB) vs PSD (dB/Hz) differ; annotate plots accordingly.
4. **Combine helpers.** After estimating a spectrum/PSD, use `findpeaks`, `bandpower`, `obw`, and, for tonal signals, `snr`/`thd`/`sinad`.
5. **Two-signal analysis.** For input–output data, pair `tfestimate` with `mscohere` and access `cpsd` as needed to diagnose dynamics.
6. **Nonuniform sampling.** Use `plomb` (Lomb–Scargle) for irregular time bases.
7. **One‑ vs two‑sided spectra.** Real signals often yield one‑sided spectra in toolbox functions; complex signals use two‑sided.
8. **Windows & averaging.** Always state window/tapers, overlap, and averaging, because they affect noise floors and RBW.
9. **Coherence‑gated interpretation.** When using `tfestimate`, rely on `mscohere` to judge trustworthy frequency regions.

## Example Usage

### Example 1 — Quick Power Spectrum + Peaks + Bandpower
```
Task:
- Use pspectrum for a one-shot look at a vibration record (Fs=25 kHz).
- RBW ≈ 50 Hz. Report top 5 peaks. Compute band power in [500 1500] Hz.

Requirements:
- Plot power spectrum (dB), label method and RBW.
- Use findpeaks with MinPeakDistance ≥ RBW; display a table of frequencies and levels.
- Report bandpower in requested band.
```

### Example 2 — Clean PSD with Welch + Occupied Bandwidth
```
Task:
- Estimate PSD of a 10-s sensor trace at Fs=2 kHz using pwelch.
- Aim for RBW ≈ 0.5 Hz. Overlay PSD and annotate 99% occupied bandwidth.

Requirements:
- Choose window/overlap; state segment length, overlap %, RBW, and window.
- Plot PSD in dB/Hz. Use obw to report BW and [flo, fhi].
- List top 3 peaks with frequencies and PSD levels.
```

### Example 3 — Multitaper PSD (Dense Lines) + Harmonic Metrics
```
Task:
- A waveform with multiple near-spaced tones in noise (Fs=96 kHz, 2 s).
- Use pmtm to reduce variance and resolve lines; compute THD/SINAD/SNR.

Requirements:
- Plot PSD in dB/Hz; show taper parameters if specified.
- Return a small table with fundamental, harmonics, THD, SINAD, and SNR.
```

### Example 4 — Time–Frequency View + Sliding Bandpower
```
Task:
- Speech-like signal, Fs from file. Show spectrogram 0–8 kHz, then compute
  bandpower in the formant region [500 3500] Hz over time.

Requirements:
- Use pspectrum(...,'spectrogram') with time/frequency limits and colorbar.
- Compute and plot the bandpower vs. time trace for the specified band.
```

### Example 5 — Input–Output FRF + Coherence (Two-Signal Workflow)
```
Task:
- Given input x and output y (Fs=10 kHz), estimate transfer function magnitude
  and coherence; ensure estimates are trustworthy.

Requirements:
- Use tfestimate(x,y,...) to get FRF; compute mscohere(x,y,...) in the same
  configuration. Plot |H(f)| and coherence on aligned frequency axes.
- Include a note: interpret FRF only where coherence is high.
```

### Example 6 — Uneven Sampling (Lomb–Scargle)
```
Task:
- Signal with missing/irregular timestamps. Estimate PSD and find dominant
  frequency near 1 Hz.

Requirements:
- Use plomb(x,t) (or plomb(x) if t is implicit) and report the main peak.
- Plot PSD with frequency in Hz; list the top peak frequency and level.
```

## Nonparametric Spectral Estimation — Cheat Sheet

| Goal | Primary function(s) | Notes |
|---|---|---|
| Quick power spectrum | `pspectrum(x,Fs)` | Use `FrequencyResolution` to set target RBW; `'spectrogram'` option for time–frequency |
| PSD (general) | `pwelch(x,window,overlap,nfft,Fs)` | One‑sided for real signals; report window, overlap, RBW |
| Low‑variance PSD | `pmtm(x,[],nfft,Fs)` | Multitaper (Slepian tapers) reduces variance; useful for dense lines |
| Baseline PSD | `periodogram(x,[],nfft,Fs)` | Basic estimator; sharpened with reassignment if needed |
| Peaks | `findpeaks(Y,F,...)` | Tie `MinPeakDistance` ≳ RBW; use `MinPeakProminence` to suppress noise |
| Band/Channel power | `bandpower(x,Fs,[f1 f2])` | Integrates power in a band directly from the signal |
| Occupied bandwidth | `obw(x,Fs,p)` | 99% by default; choose `p` as needed (e.g., 90%) |
| Mean/median/3 dB BW | `meanfreq`, `medfreq`, `powerbw` | Report alongside PSD for characterization |
| Distortion & SNR | `thd`, `sinad`, `snr` | After identifying the fundamental/harmonics |
| Cross‑spectrum & FRF | `cpsd`, `tfestimate`, `mscohere` | Use same window/overlap/nfft across functions; interpret FRF only where coherence is high |
| Nonuniform sampling | `plomb(x,Fs)` or `plomb(x,t)` | Lomb–Scargle PSD for irregular time bases |

## Related Prompts

- [Design Digital Filter](design-digital-filter.md) - Design filters to preprocess signals before spectral analysis

## References

### Spectral Estimation Functions
- [pspectrum](https://www.mathworks.com/help/signal/ref/pspectrum.html) - Analyze signals in the frequency and time-frequency domains
- [pwelch](https://www.mathworks.com/help/signal/ref/pwelch.html) - Welch's power spectral density estimate
- [pmtm](https://www.mathworks.com/help/signal/ref/pmtm.html) - Multitaper power spectral density estimate
- [periodogram](https://www.mathworks.com/help/signal/ref/periodogram.html) - Periodogram power spectral density estimate
- [plomb](https://www.mathworks.com/help/signal/ref/plomb.html) - Lomb-Scargle periodogram for unevenly sampled data

### Peak and Band Analysis
- [findpeaks](https://www.mathworks.com/help/signal/ref/findpeaks.html) - Find local maxima in data
- [bandpower](https://www.mathworks.com/help/signal/ref/bandpower.html) - Band power of signal
- [obw](https://www.mathworks.com/help/signal/ref/obw.html) - Occupied bandwidth of signal
- [meanfreq](https://www.mathworks.com/help/signal/ref/meanfreq.html) - Mean frequency of signal
- [medfreq](https://www.mathworks.com/help/signal/ref/medfreq.html) - Median frequency of signal
- [powerbw](https://www.mathworks.com/help/signal/ref/powerbw.html) - 3-dB bandwidth of signal

### Signal Quality Metrics
- [snr](https://www.mathworks.com/help/signal/ref/snr.html) - Signal-to-noise ratio
- [thd](https://www.mathworks.com/help/signal/ref/thd.html) - Total harmonic distortion
- [sinad](https://www.mathworks.com/help/signal/ref/sinad.html) - Signal-to-noise-and-distortion ratio

### Two-Signal Analysis
- [cpsd](https://www.mathworks.com/help/signal/ref/cpsd.html) - Cross power spectral density
- [tfestimate](https://www.mathworks.com/help/signal/ref/tfestimate.html) - Transfer function estimate
- [mscohere](https://www.mathworks.com/help/signal/ref/mscohere.html) - Magnitude-squared coherence

### General Documentation
- [Nonparametric Methods](https://www.mathworks.com/help/signal/nonparametric-methods.html) - Overview of spectral estimation techniques
