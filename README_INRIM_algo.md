# INRIM_algo.m

## Overview

This MATLAB script analyzes INRIM QPMU data sampled at **50 frames per second (fps)**. Its purpose is to estimate the dominant oscillation frequency over time from PMU output channels.

The script allows the user to choose one of three channels:

1. Frequency channel
2. Amplitude channel
3. Phase channel

The analysis is performed using a sliding-window method. For each window, the algorithm detects whether the signal is steady, close to the Nyquist frequency, or contains an ordinary oscillatory component visible in the frequency spectrum.

The script is designed for QPMU output quantities.

---

## Input File

The default input file is:

```matlab
inputFile = 'QPMU_500ksps_5SOW_50fps.csv';
```

The CSV file must be placed in the same folder as `INRIM_algo.m`, or the path in `inputFile` must be updated.

Unlike a purely position-based reader, this script reads the table using the original column names:

```matlab
T = readtable(inputFile, ...
    'Delimiter', delim, ...
    'VariableNamingRule', 'preserve', ...
    'ReadVariableNames', true);
```

The delimiter is detected automatically by the helper function `detect_delimiter`, which checks common delimiters such as comma, semicolon, and tab.

---

## Required CSV Columns

The input file must contain the following columns:

| MATLAB variable | Required CSV column |
|---|---|
| `Timestamp` | `Timestamp` |
| `Phase` | `INRIM_QPMU Voltage0 Diff Angle L1MagAng` |
| `Amplitude` | `INRIM_QPMU Voltage0 Magnitude L1MagAng` |
| `Frequency` | `INRIM_QPMU Frequency` |

The script also checks that the table has at least **15 columns**.

If any numeric columns are imported as strings or cells, the helper function `force_numeric` converts them to numeric values before the analysis.

---

## Main Settings

The main analysis parameters are defined at the beginning of the script:

```matlab
Fs = 50;
windowSec = 6;
stepSec = 1;
```

| Parameter | Description |
|---|---|
| `Fs` | QPMU reporting rate, fixed at 50 fps |
| `windowSec` | Sliding analysis window length, equal to 6 seconds |
| `stepSec` | Step between consecutive windows, equal to 1 second |

With these settings, each window contains 300 samples and a new frequency estimate is produced every second.

---

## How to Run

1. Open MATLAB.
2. Place `INRIM_algo.m` and `QPMU_500ksps_1SOW_50fps.csv` in the same folder.
3. Run the script.
4. Select the channel when prompted:

```text
1 -> Frequency channel
2 -> Amplitude channel
3 -> Phase channel
```

For example, enter `2` to analyze the amplitude channel.

---

## Output Files

The output file depends on the selected channel:

| Selected option | Output file |
|---:|---|
| 1 | `frequency_channel_results.csv` |
| 2 | `amplitude_channel_results.csv` |
| 3 | `phase_channel_results.csv` |

### Frequency channel output

| Column | Description |
|---|---|
| `Timestamp` | Timestamp at the center of the window |
| `DetectedFrequency` | Dominant detected frequency in Hz |

### Amplitude and phase channel output

| Column | Description |
|---|---|
| `Timestamp` | Timestamp at the center of the window |
| `DetectedFrequency` | Dominant detected frequency in Hz |
| `SSO_Amplitude` | Estimated oscillation amplitude calculated from the original signal |

---

## Generated Plots

The script generates scatter plots after the analysis.

For the frequency channel:

- Detected frequency over time

For the amplitude and phase channels:

- Detected frequency over time
- Estimated oscillation amplitude over time

---

## Algorithm Summary

For each sliding window, the algorithm performs the following operations:

1. Removes the mean or median component from the signal.
2. Checks whether the window is nearly constant and should be classified as **0 Hz**.
3. Checks whether the window strongly matches the alternating pattern `(-1)^n`, which corresponds to the Nyquist frequency.
4. Detrends the signal and applies a Hann window.
5. Computes the FFT and searches for dominant spectral peaks between approximately **0.2 Hz** and **24.8 Hz**.
6. Uses adaptive thresholds based on the spectrum median and MAD.
7. Selects the strongest valid peak.
8. Validates the selected peak with a sinusoidal least-squares fit.
9. Stores the detected frequency at the center timestamp of the window.

For amplitude and phase channels, the detection step uses a normalized signal. However, the reported `SSO_Amplitude` is calculated from the original, non-normalized signal so that the amplitude remains physically meaningful.

---

## Phase Channel Processing

Before analyzing the phase channel, the script unwraps the phase to avoid artificial discontinuities caused by angle wrapping:

```matlab
phase_raw = unwrap(deg2rad(phase_raw));
phase_raw = rad2deg(phase_raw);
```

This makes the phase signal smoother and more suitable for frequency-domain analysis.

---

## Special Cases

### Steady-state condition

If the signal variation inside a window is very small, the algorithm assigns:

```text
DetectedFrequency = 0 Hz
SSO_Amplitude = 0
```

This means that no meaningful oscillation was detected in that window.

### Nyquist-frequency condition

Since the reporting rate is 50 fps, the Nyquist frequency is:

```text
Fs / 2 = 25 Hz
```

The script detects this case using the alternating sequence `(-1)^n`. If this pattern is dominant, the detected frequency is assigned as 25 Hz.

---

## Helper Functions

The script includes the following helper functions:

| Function | Purpose |
|---|---|
| `normalize_timestamp` | Converts timestamps into a consistent string format |
| `force_numeric` | Converts numeric data imported as strings or cells into double values |
| `detect_delimiter` | Detects whether the CSV file uses comma, semicolon, or tab separation |

---

## Requirements

This script requires MATLAB. It also uses functions commonly available with MATLAB and the Signal Processing Toolbox, including:

- `fft`
- `hann`
- `findpeaks`
- `detrend`
- `rms`
- `mad`
- `unwrap`

---

## Notes and Limitations

- The script assumes a fixed reporting rate of **50 fps**.
- The input CSV must contain the required QPMU column names.
- The frequency resolution depends on the 6-second window length.
- Very short events may not be captured clearly because the method is window-based.
- If multiple oscillatory components exist in the same window, the algorithm mainly reports the dominant one.
- The method is intended for QPMU output signals such as frequency, voltage magnitude, and voltage angle.

---

## Author / Context

This script was developed for analyzing INRIM QPMU data and estimating oscillatory behavior from synchronized PMU output quantities.
