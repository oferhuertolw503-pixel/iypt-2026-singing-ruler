---
title: Design Digital Filter
description: Design and analyze digital filters using modern, stable MATLAB APIs with minimal specs
tags: [matlab, signal-processing, filter-design, iir, fir, sos, lowpass, highpass, bandpass, bandstop, designfilt, sosfilt, ctffilt, filtfilt, filterAnalyzer]
release: R2024b+ (recommended for CTF); Earlier releases can use SOS
notes:
---

# Design Digital Filter

Design and analyze digital filters (lowpass/highpass/bandpass/bandstop) using modern, stable MATLAB APIs with minimal specs. Be numerically robust by default.

## Metadata

- **Tags:** `matlab` `signal-processing` `filter-design` `iir` `fir` `sos` `lowpass` `highpass` `bandpass` `bandstop` `designfilt` `sosfilt` `ctffilt` `filtfilt` `filterAnalyzer`
- **MATLAB Release:** R2024b+ (recommended for CTF); Earlier releases can use SOS
- **Required Toolboxes:** Signal Processing Toolbox, (optional) DSP System Toolbox
## The Prompt

```markdown
You are an expert MATLAB DSP engineer.

Design and apply a DIGITAL FILTER using MATLAB’s high-level, stable APIs.

**Use numerically robust forms:** default to SOS or CTF for IIR; `[b,a]` is acceptable for low‑order IIR in double precision; FIR returns `b` with `a=1`. Expose a `digitalFilter` object when possible.

=== SPECS ===
• Type: "lowpass" | "highpass" | "bandpass" | "bandstop"
• Fs (Hz): <number>
• Bands (Hz): LP/HP → Fpass=<number>; BP/BS → Fpass=[f1 f2]; optional Fstop=...
• Performance (dB): StopbandAtten=Rs; optional PassbandRipple=Rp
• Phase/latency: "zero-phase (offline)" | "causal (real-time)"
• Linear phase required: true | false

=== DO ===
1) **API selection**
   • Simple specs → use lowpass/highpass/bandpass/bandstop; return `[y,d]`.
   • Custom/multiband → use `designfilt(...)` to create `digitalFilter d` (FIR for linear phase; else IIR).
2) **Stability**
   • Offline zero‑phase → `filtfilt(d,x)` (or `filtfilt(sos,g,x)` for IIR coefficients).
   • Streaming → `sosfilt(sos,x)` / `dsp.SOSFilter` or `ctffilt(B,A,x)` when available.
3) **Validation (Hz‑aware)**
   • Use `freqz(d,[],Fs)` and `grpdelay(d,[],Fs)`.
   • Report: order/length, −3 dB cutoff(s), peak passband ripple (dB), minimum stopband attenuation (dB).
4) **Demo**
   • Build a representative test signal; show before/after (time + Welch PSD).
5) **Deliver**
   • Provide one complete, runnable MATLAB script (single code block).
   • 3–5 bullets on design trade‑offs and whether specs were met.

(Notes: keep frequency axes in Hz using `freqz(...,Fs)`; use `filtfilt` for zero‑phase offline; for streaming, use SOS/System objects or CTF. Keep notches moderate to avoid ringing.)
```
---
## Usage Tips

- **Pin the sample rate.** Always set `SampleRate=Fs` in designs; plot in Hz via `freqz(...,Fs)` / `grpdelay(...,Fs)`.
- **FIR vs IIR.** Choose FIR for strict linear phase (equiripple); otherwise IIR is more efficient. Quote the in‑band group delay.
- **Offline vs streaming.** Use `filtfilt` for zero‑phase offline; for streaming use SOS/System objects or `ctffilt` when available. Manage state across chunks.
- **Notches.** Avoid ultra‑high‑Q notches that ring. For multiple tones, prefer several modest bandstops.
- **Long FIRs.** Switch to `fftfilt` (overlap‑add) beyond a length threshold.
- **Report achieved specs.** Measure ripple/attenuation and −3 dB points from `freqz` data and state the numbers explicitly.
- **Coefficients Depracated** The Coefficients property of digitalFilter object has been replaced by the Numerator and Denominator properties

---

## Example Usage

### Example 1 — Minimal lowpass (auto min‑order)

```
Design a digital filter in MATLAB with:

- Type: lowpass
- Sample rate: 48e3 Hz
- Fpass: 8e3 Hz, Fstop: 10e3 Hz
- StopbandAtten: 80 dB
- Phase/latency: "zero-phase (offline)"
- Linear phase required: false

Include (full call + checks):
```

```matlab
[y,d] = lowpass(x, 8e3, 48e3, StopbandAttenuation=80, ImpulseResponse="iir", Steepness=0.85);
y0 = filtfilt(d,x);
figure; freqz(d,[],48e3); grid on
figure; grpdelay(d,[],48e3); grid on
```

---

### Example 2 — Speech band-pass via `designfilt` (IIR, min‑order)

```
Design a bandpass filter for speech:

- Type: bandpass
- Sample rate: 44100 Hz
- Fpass: [300 3400] Hz
- Fstop: [200 3900] Hz
- PassbandRipple: 1 dB, StopbandAtten: 60 dB
- Phase/latency: "causal (real-time)"
- Linear phase required: false

Include (full call using scalar 1/2 names + streaming path):
```

```matlab
Fs = 44100;
d = designfilt("bandpassiir", ...
    StopbandFrequency1=200,  PassbandFrequency1=300, ...
    PassbandFrequency2=3400, StopbandFrequency2=3900, ...
    PassbandRipple=1, ...
    StopbandAttenuation1=60, StopbandAttenuation2=60, ...
    SampleRate=Fs, DesignMethod="ellip");  % min-order from Rp/Rs

%  Extraction + streaming (CTF preferred; SOS fallback)
B = d.Numerator; A = d.Denominator;              % CTF (per-section rows)
y_rt = ctffilt(B, A, x);                         % CTF streaming (R2024b+)


% Hz-aware analysis (offline)
y0 = filtfilt(d,x);
figure; freqz(d,[],Fs); grid on
figure; grpdelay(d,[],Fs); grid on
```

*Fixed‑order, 3‑dB edges alternative:*

```matlab
d = designfilt("bandpassiir", FilterOrder=10, ...
    HalfPowerFrequency1=300, HalfPowerFrequency2=3400, ...
    SampleRate=Fs, DesignMethod="butter");
```

---

### Example 3 — Linear‑phase FIR with Filter Analyzer overlay

```
Design a linear-phase FIR lowpass:

- Type: lowpass
- Sample rate: 10e3 Hz
- Fpass: 1e3 Hz, Fstop: 1.2e3 Hz
- StopbandAtten: 70 dB
- Phase/latency: "zero-phase (offline)"
- Linear phase required: true

Include (full call + overlay vs IIR):
```

```matlab
Fs = 1e4;

% FIR (linear phase, equiripple)
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=1e3, StopbandFrequency=1.2e3, ...
    PassbandRipple=0.2, StopbandAttenuation=70, ...
    SampleRate=Fs, DesignMethod="equiripple");

% IIR comparator (elliptic, min‑order)
d_iir = designfilt("lowpassiir", ...
    PassbandFrequency=1e3, StopbandFrequency=1.2e3, ...
    PassbandRipple=0.2, StopbandAttenuation=70, ...
    SampleRate=Fs, DesignMethod="ellip");

% Zero‑phase check and overlay in Filter Analyzer
y0 = filtfilt(d_fir,x);
% 'FilterNames' values must contain valid MATLAB variable names
fa = filterAnalyzer(d_fir, d_iir, FilterNames=["FIR_equiripple","IIR_ellip"], ...
                    Analysis="magnitude", OverlayAnalysis="phase", ...
                    SampleRates=Fs);
```

---

## Filter Design Methods

### High‑level one‑liners (minimum‑order; returns `[y,d]`)

```matlab
% Lowpass / Highpass (set ImpulseResponse="fir" for strict linear phase)
[y,d] = lowpass(x, Fpass, Fs, StopbandAttenuation=Rs, ImpulseResponse="iir", Steepness=0.85);
[yh,dh] = highpass(x, Fpass, Fs, StopbandAttenuation=Rs, ImpulseResponse="iir", Steepness=0.85);

% Bandpass / Bandstop (passband given as [f1 f2])
[yb,db] = bandpass(x, [f1 f2], Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");
[yn,dn] = bandstop(x, [f1 f2], Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");
```

> **Notes:** One-liners pick minimum order from the attenuation target (and optional `Steepness`). Use `ImpulseResponse="fir"` for linear phase.

---

### FIR via `designfilt` (linear phase)

```matlab
% Lowpass FIR (equiripple, Hz‑aware)
d = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, SampleRate=Fs, ...
    DesignMethod="equiripple");

% Highpass FIR (equiripple)
d = designfilt("highpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, SampleRate=Fs, ...
    DesignMethod="equiripple");

% Bandpass FIR (equiripple)
d = designfilt("bandpassfir", ...
    PassbandFrequency=[f1 f2], StopbandFrequency=[fs1 fs2], ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, SampleRate=Fs, ...
    DesignMethod="equiripple");

% Bandstop FIR (weighted LS example)
d = designfilt("bandstopfir", ...
    FilterOrder=32, ...
    PassbandFrequency1=400, StopbandFrequency1=500, ...
    StopbandFrequency2=700, PassbandFrequency2=850, ...
    DesignMethod="ls", ...
    PassbandWeight1=1, StopbandWeight=3, PassbandWeight2=5, ...
    SampleRate=2000);
```

> **Notes:** Equiripple uses ripple/attenuation (Rp/Rs). LS form uses band weights—handy when some passbands matter more.

---

### IIR via `designfilt`

```matlab
% Lowpass IIR (minimum order from Rp/Rs; low latency)
d = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, SampleRate=Fs, ...
    DesignMethod="ellip");

% Bandpass IIR (ripple/attenuation SPEC‑SET: scalar edges with 1/2 names)
d = designfilt("bandpassiir", ...
    StopbandFrequency1=fs1,  PassbandFrequency1=f1, ...
    PassbandFrequency2=f2,   StopbandFrequency2=fs2, ...
    PassbandRipple=Rp, ...
    StopbandAttenuation1=Rs, StopbandAttenuation2=Rs, ...
    SampleRate=Fs, DesignMethod="ellip");

% Bandpass IIR (fixed‑order half‑power SPEC‑SET: 3‑dB edges)
d = designfilt("bandpassiir", FilterOrder=N, ...
    HalfPowerFrequency1=f1, HalfPowerFrequency2=f2, ...
    SampleRate=Fs, DesignMethod="butter");

% Notch IIR (center/Q)
d = designfilt("notchiir", CenterFrequency=f0, QualityFactor=Q, SampleRate=Fs);
```

> **Notes:** For **IIR bandpass/bandstop**, ripple/attenuation designs require **scalar** edge properties with `…1`/`…2` names. Vectors (e.g., `PassbandFrequency=[f1 f2]`) will error. Use the **HalfPower** spec‑set for fixed‑order, 3‑dB‑edge designs.

---

## Application Patterns

```matlab
% 1) Get coefficients from the digitalFilter object d
B = d.Numerator;                          % Lx3 per-section [b0 b1 b2]
A = d.Denominator;                        % Lx3 per-section [a0 a1 a2]
sos = [B A];                              % Lx6 [b0 b1 b2 a0 a1 a2] (for SOS APIs)
L  = size(B,1);                           % number of biquad sections (FYI)

% 2) Offline checks (zero-phase + response)
% These are for verification/analysis only (not for real-time use).
y0 = filtfilt(d, x);                      % zero-phase reference
figure; freqz(d, [], Fs); grid on;        % magnitude/phase
title('High-pass IIR (designfilt): |H(f)| & phase');
figure; grpdelay(d, [], Fs); grid on;
title('High-pass IIR (designfilt): group delay');

% 3) Streaming options (choose one)

% 3A) CTF path — explicit state (pass state across frames)
%     Use this if you want to keep CTF form end-to-end.
%     One-shot (whole signal, no frames):
y_rt_ctf_all = ctffilt(B, A, x);          % processes entire x (no external state)

%     Frame-by-frame (real-time style) with state carryover:
frameLen = 1024;                          % example frame size
state_ctf = [];                           % first call -> internally zero state
N = numel(x);
y_rt_ctf = zeros(N,1);
p = 1;
while p <= N
    q = min(p+frameLen-1, N);
    [y_rt_ctf(p:q), state_ctf] = ctffilt(B, A, x(p:q), state_ctf);
    p = q + 1;
end

% 3B) SOS System object — state handled internally for you
%     Works great for streaming and codegen; no manual state.
sosFilt = dsp.SOSFilter('Numerator', B, 'Denominator', A);

%     One-shot (whole signal):
y_rt_sos_all = sosFilt(x);

%     Frame-by-frame:
reset(sosFilt);                           % ensure known start for demo
p = 1;
y_rt_sos = zeros(N,1);
while p <= N
    q = min(p+frameLen-1, N);
    y_rt_sos(p:q) = sosFilt(x(p:q));      % internal state preserved across calls
    p = q + 1;
end

% (Optional) Quick comparison plot (offline)
% figure; plot([y0 y_rt_ctf y_rt_sos]); legend('filtfilt reference','CTF stream','SOS stream'); grid on;
```
## Analysis Pattern
```matlab
%% Analysis with Filter Analyzer 
Fs = 44100;

% Designs (variables are valid identifiers)
hpIIR_ellip = designfilt("highpassiir", ...
    StopbandFrequency   = 200, ...
    PassbandFrequency   = 300, ...
    StopbandAttenuation = 60, ...
    PassbandRipple      = 1, ...
    SampleRate          = Fs, ...
    DesignMethod        = "ellip");

hpFIR_equiripple = designfilt("highpassfir", ...
    StopbandFrequency   = 200, ...
    PassbandFrequency   = 300, ...
    StopbandAttenuation = 70, ...
    PassbandRipple      = 0.5, ...
    SampleRate          = Fs, ...
    DesignMethod        = "equiripple");

% Frequency-domain display options
optsMag = filterAnalysisOptions("magnitude","phase", ...
    FrequencyNormalizationMode = "unnormalized", ...
    ReferenceSampleRateMode    = "specify", ...
    ReferenceSampleRate        = Fs, ...
    FrequencyRange             = "onesided", ...
    FrequencyScale             = "log", ...
    NFFT                       = 4096, ...
    NormalizeMagnitude         = true);

% Use valid identifiers for FilterNames as well
filterNames = ["HP_IIR_ellip" "HP_FIR_equiripple"];

[fa, disp1] = filterAnalyzer(hpIIR_ellip, hpFIR_equiripple, ...
    FilterNames     = filterNames, ...
    SampleRates     = [Fs Fs], ...
    AnalysisOptions = optsMag);

% Time-domain display (impulse + step)
optsTD = filterAnalysisOptions("impulse","step", ...
    ResponseLengthMode = "specify", ...
    ResponseLength     = 512);
disp2 = addDisplays(fa, AnalysisOptions = optsTD, FilterNames=filterNames);
```
## Related Prompts

- [Analyze Signal Spectrum](analyze-signal-spectrum.md) - Analyze filtered signals in the frequency domain

## References

### General Tutorials
- [Practical Introduction to Digital Filtering](https://www.mathworks.com/help/signal/ug/practical-introduction-to-digital-filtering.html) - Comprehensive filtering overview
- [Practical Introduction to Digital Filter Design](https://www.mathworks.com/help/signal/ug/practical-introduction-to-digital-filter-design.html) - Design methodology guide
- [Digital Filtering Function Index](https://www.mathworks.com/help/signal/digital-filtering.html) - Complete function reference

### High-Level Filter Functions
- [lowpass](https://www.mathworks.com/help/signal/ref/lowpass.html) - Lowpass filter with automatic design
- [highpass](https://www.mathworks.com/help/signal/ref/highpass.html) - Highpass filter with automatic design
- [bandpass](https://www.mathworks.com/help/signal/ref/bandpass.html) - Bandpass filter with automatic design
- [bandstop](https://www.mathworks.com/help/signal/ref/bandstop.html) - Bandstop filter with automatic design

### Filter Design & Objects
- [designfilt](https://www.mathworks.com/help/signal/ref/designfilt.html) - Unified filter design interface
- [digitalFilter](https://www.mathworks.com/help/signal/ref/digitalfilter.html) - Digital filter object
- [Filter Analyzer App](https://www.mathworks.com/help/signal/ref/filteranalyzer-app.html) - Interactive filter analysis tool
- [filterAnalyzer](https://www.mathworks.com/help/signal/ref/filteranalyzer.html) - Programmatic filter analysis

### Filter Implementation
- [sosfilt](https://www.mathworks.com/help/signal/ref/sosfilt.html) - Second-order sections filtering
- [ctffilt](https://www.mathworks.com/help/signal/ref/ctffilt.html) - Cascaded transfer function filtering (R2024b+)
- [dsp.SOSFilter](https://www.mathworks.com/help/dsp/ref/dsp.sosfilter-system-object.html) - SOS filter System object
- [butter](https://www.mathworks.com/help/signal/ref/butter.html) - Butterworth filter design
- [fftfilt](https://www.mathworks.com/help/signal/ref/fftfilt.html) - FFT-based FIR filtering for long filters

### Analysis & Validation
- [freqz](https://www.mathworks.com/help/signal/ref/freqz.html) - Frequency response of digital filter
- [grpdelay](https://www.mathworks.com/help/signal/ref/grpdelay.html) - Group delay of digital filter
- [filtfilt](https://www.mathworks.com/help/signal/ref/filtfilt.html) - Zero-phase digital filtering

### Special Topics
- [Design of Peaking and Notching Filters](https://www.mathworks.com/help/dsp/ug/design-of-peaking-and-notching-filters.html) - Notch/peak filter design guide
