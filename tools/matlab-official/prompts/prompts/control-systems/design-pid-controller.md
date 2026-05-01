---
title: Design PID Controller
description: Design and tune PID controllers for plant models with stability analysis
tags: [matlab, control-systems, pid, tuning, stability, feedback]
release: Requires Control System Toolbox
notes:
---

# Design PID Controller

Design and tune PID controllers for given plant models with stability analysis and performance evaluation.

## Metadata

- **Tags:** `matlab` `control-systems` `pid` `tuning` `stability` `feedback`
- **MATLAB Release:** Requires Control System Toolbox
- **Required Toolboxes:** Control System Toolbox

## The Prompt

```text
Design a PID controller for the given system in MATLAB:

Requirements:
1. Define the plant transfer function or state-space model
2. Design PID gains using one of the following methods:
   - pidtune() for automatic tuning based on bandwidth or phase margin
   - pidTuner app for interactive GUI-based tuning
   - Manual tuning using classical methods (Ziegler-Nichols, IMC, etc.)
3. Create closed-loop system
4. Analyze step response (rise time, settling time, overshoot)
5. Analyze stability margins (gain and phase margins)
6. Plot Bode diagram and root locus
7. Compare open-loop vs closed-loop performance
8. Provide tuning rationale in comments

Plant model: [TRANSFER FUNCTION OR STATE SPACE]
Performance requirements: [SPECIFY EITHER:
  - Time-domain: RISE TIME, OVERSHOOT, SETTLING TIME
  - Frequency-domain: GAIN MARGIN (dB), PHASE MARGIN (degrees), CROSSOVER FREQUENCY (rad/s)
  - Hybrid: Combine both as needed]
```

## Usage Tips

1. **Provide plant model:** Transfer function, state-space, or physical parameters
2. **Specify requirements:** Concrete performance metrics help tuning
3. **Mention constraints:** Actuator limits, robustness needs, disturbance rejection
4. **Request specific analyses:** Sensitivity, disturbance response, etc.

## Example Usage

### Example 1: Basic PID Design

```
Design a PID controller for the given system in MATLAB:

Requirements:
1. Define the plant transfer function
2. Use pidTuner for automatic tuning
3. Create closed-loop system
4. Analyze step response (rise time, settling time, overshoot)
5. Analyze stability margins (gain and phase margins)
6. Plot Bode diagram and root locus
7. Compare open-loop vs closed-loop performance
8. Provide tuning rationale in comments

Plant model: G(s) = 1/(s^2 + 2s + 1)
Performance requirements:
- Settling time < 5 seconds (for pidtune: use wc ≈ 4/settling_time ≈ 0.8 rad/s)
- Overshoot < 10% (for pidtune: use phase margin ≈ 60-70°)
- Zero steady-state error to step input (ensure integral action in PID)

Alternative (frequency-domain specification):
- Phase margin ≥ 60° (achieves similar overshoot characteristics)
- Gain margin ≥ 8 dB (ensures robustness)
- Crossover frequency ≈ 0.8 rad/s (meets settling time requirement)
```

### Example 2: DC Motor Position Control

```
Design a PID controller for DC motor position control:

Plant model:
- Motor transfer function: θ(s)/V(s) = K/(s(Js + b))
- Parameters: J = 0.01 kg·m², b = 0.1 N·m·s, K = 0.01 N·m/A

Performance requirements:
- Rise time < 0.5 seconds
- Settling time < 2 seconds
- Overshoot < 5%
- No steady-state error

Include:
- PID tuning using pidtune (for fast response: wc > 2 rad/s) or Ziegler-Nichols
- Step response analysis
- Disturbance rejection analysis (step disturbance)
- Bode plot with gain/phase margins
- Closed-loop pole locations
```

### Example 3: Temperature Control with Constraints

```
Design a PI controller for temperature control system:

Plant model: First-order with delay G(s) = 2*exp(-5s)/(10s + 1)

Performance requirements:
- Settling time < 30 seconds
- No overshoot (critical damping preferred)
- Reject disturbances effectively

Constraints:
- Control effort limited to ±10 units
- Must be robust to 20% plant uncertainty

Include:
- PI tuning (no derivative to avoid noise amplification)
- Step response with and without disturbance
- Sensitivity function analysis
- Robustness analysis (gain/phase margins)
- Control effort plot
```

### Example 4: Margin-Based Design

```
Design a PID controller for a chemical process with uncertain dynamics:

Plant model: G(s) = 5/(s^3 + 6s^2 + 11s + 6)

Performance requirements (frequency-domain):
- Phase margin ≥ 60° (ensures robustness to time delays and parameter variations)
- Gain margin ≥ 10 dB (provides 3x safety factor against gain increases)
- Crossover frequency between 0.5-1.5 rad/s (balance responsiveness and noise sensitivity)
- Bandwidth sufficient for disturbance rejection below 0.3 rad/s

Design approach:
1. Use pidtune with explicit phase margin specification
2. Verify gain margin meets requirement
3. If needed, iterate with pidtuneOptions to adjust design focus
4. Validate that time-domain response is acceptable

Include:
- Bode plot with margin annotations
- Nichols chart showing gain/phase relationship
- Closed-loop frequency response (bandwidth, peak)
- Sensitivity function (max sensitivity Ms < 2.0 for robustness)
- Step response (verify no excessive oscillation)
- Robustness analysis to ±30% plant gain variation

Rationale for margin-based design:
- Plant parameters uncertain (typical in chemical processes)
- Time delays may be present (not perfectly modeled)
- Phase margin ensures adequate damping
- Gain margin protects against nonlinearities and saturation effects
```

## PID Design Pattern

```matlab
% Define plant
num = [1];
den = [1 2 1];
G = tf(num, den);

% Option 1: Automatic tuning with pidtune (programmatic)
C = pidtune(G, 'PID');  % Uses default phase margin of 60°
% C = pidtune(G, 'PID', 1.5);  % Target bandwidth of 1.5 rad/s

% Option 2: Interactive tuning with pidTuner (GUI)
% pidTuner(G, 'PID');  % Opens interactive GUI

% Option 3: Manual design
% Kp = 10; Ki = 5; Kd = 2;
% C = pid(Kp, Ki, Kd);

% Closed-loop system
T = feedback(C*G, 1);

% Step response
figure;
step(T);
grid on;
stepinfo(T)

% Bode plot with margins
figure;
margin(C*G);
grid on;

% Root locus
figure;
rlocus(G);
grid on;
```

## Tuning Methods

### pidtune (Automatic, Frequency-Domain)
```matlab
% Basic usage with default phase margin (60°)
C = pidtune(G, 'PID');

% Specify target bandwidth (rad/s)
wc = 1.5;  % Target crossover frequency
C = pidtune(G, 'PID', wc);

% Specify phase margin (degrees) directly
C = pidtune(G, 'PID', 60);

% Advanced options for design focus
opts = pidtuneOptions('DesignFocus', 'disturbance-rejection');
opts.PhaseMargin = 70;  % More conservative
C = pidtune(G, 'PID', opts);

% Get tuning information
[C, info] = pidtune(G, 'PID');
fprintf('Achieved phase margin: %.2f°\n', info.PhaseMargin);
fprintf('Crossover frequency: %.2f rad/s\n', info.CrossoverFrequency);
```

### PID Tuner (Interactive)
```matlab
pidTuner(G, 'pid')  % Opens interactive GUI
```

### Ziegler-Nichols
```matlab
% Find ultimate gain and period
[Gm, Pm, Wcg, Wcp] = margin(G);
Ku = Gm;  % Ultimate gain
Tu = 2*pi/Wcp;  % Ultimate period

% ZN tuning rules
Kp = 0.6*Ku;
Ki = 2*Kp/Tu;
Kd = Kp*Tu/8;
```

### IMC Tuning
```matlab
% Internal Model Control tuning (good for first-order + delay)
tau = 10;  % Plant time constant
lambda = tau/3;  % Desired closed-loop time constant
Kp = (2*tau + delay)/(2*K*lambda);
Ki = Kp/tau;
```

### Margin-Based Design (Robust Control)
```matlab
% Design with specific phase margin requirement
target_pm = 60;  % degrees
C = pidtune(G, 'PID', target_pm);

% Verify achieved margins
[Gm, Pm, Wcg, Wcp] = margin(C*G);
fprintf('Achieved Phase Margin: %.2f° (target: %.2f°)\n', Pm, target_pm);
fprintf('Achieved Gain Margin: %.2f dB (%.2fx)\n', 20*log10(Gm), Gm);
fprintf('Phase Crossover: %.2f rad/s\n', Wcp);
fprintf('Gain Crossover: %.2f rad/s\n', Wcg);

% If gain margin insufficient, iterate with more conservative design
if 20*log10(Gm) < 10  % Less than 10 dB
    opts = pidtuneOptions('PhaseMargin', 70);  % More conservative
    C = pidtune(G, 'PID', opts);
    [Gm, Pm, Wcg, Wcp] = margin(C*G);
    fprintf('Revised Gain Margin: %.2f dB\n', 20*log10(Gm));
end

% Robustness check: Test with plant variations
G_high = 1.3 * G;  % 30% gain increase
G_low = 0.7 * G;   % 30% gain decrease
figure;
margin(C*G, C*G_high, C*G_low);
legend('Nominal', '+30% Gain', '-30% Gain');
title('Robustness to Plant Uncertainty');
```

## Analysis Functions

```matlab
% Step response characteristics
info = stepinfo(T);

% Stability margins
[Gm, Pm, Wcg, Wcp] = margin(L);

% Sensitivity functions
S = feedback(1, L);  % Sensitivity
T = feedback(L, 1);  % Complementary sensitivity

% Pole locations
poles = pole(T);

% Steady-state error
dcgain(T)  % Should be 1 for zero error
```

## Performance Comparison

```matlab
figure;
step(G, 'b', T, 'r');
legend('Open-Loop', 'Closed-Loop');
title('Step Response Comparison');
grid on;
```

## Time-Domain vs Frequency-Domain Specifications

### Conversion Guidelines

**Time-Domain → Frequency-Domain:**
- Overshoot < 10% → Phase margin ≈ 60-70°
- Overshoot < 20% → Phase margin ≈ 45-55°
- Settling time Ts → Crossover frequency ωc ≈ 4/Ts to 6/Ts
- Fast response → Higher ωc, but check noise sensitivity

**Frequency-Domain → Time-Domain (Approximate):**
- Phase margin 60° → Overshoot ≈ 10%, damping ζ ≈ 0.6
- Phase margin 45° → Overshoot ≈ 20%, damping ζ ≈ 0.4
- Bandwidth ωb → Settling time Ts ≈ 4-6/ωb

### When to Use Each Approach

**Use Time-Domain Specifications When:**
- Requirements are naturally expressed as response times
- Plant model is well-known and accurate
- Tracking performance is the primary concern
- Single operating point design

**Use Frequency-Domain Specifications (Margins) When:**
- Plant has significant uncertainty or parameter variations
- Time delays are present or uncertain
- Robustness is critical (safety, expensive equipment)
- Operating over wide range of conditions
- Multiple feedback loops or cascaded systems
- Need to ensure stability with nonlinearities

**Use Hybrid Approach When:**
- Need both fast response AND robustness
- Example: "Settling time < 3s AND phase margin ≥ 50°"
- May require iterative tuning to meet both constraints

## Related Prompts

- [Optimize MATLAB Code Performance](../programming/optimize-code-performance.md) - For real-time control
- [Create Unit Tests](../programming/create-unit-tests.md) - For controller validation

## References

- [MATLAB Documentation: PID Controller](https://www.mathworks.com/help/control/ref/pid.html)
- [MATLAB Documentation: PID Tuning](https://www.mathworks.com/help/control/pid-controller-design.html)
