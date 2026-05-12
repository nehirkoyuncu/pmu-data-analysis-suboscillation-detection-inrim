# INRIM_Algorithm_QPMU_50fps.m

## Overview

This MATLAB script analyzes PMU data sampled at **50 frames per second (fps)** in order to detect the dominant oscillation frequency over time. The script can be applied to three different channels:

1. Frequency channel
2. Amplitude channel
3. Phase channel

For each selected channel, the signal is processed using sliding windows. The algorithm estimates whether each window corresponds to a steady-state condition, a Nyquist-frequency oscillation, or an ordinary oscillatory component detected from the spectrum.

The script is mainly intended for the analysis of PMU output quantities.

---

## Input File

The script expects the input CSV file to be located in the same folder as the MATLAB file.

Default input file:

```matlab
inputFile = '50fps_30second_1h.csv';
```

The script reads the file using:

```matlab
rawCell = readcell(inputFile);
numData = readmatrix(inputFile);
```

It expects at least **15 columns** in the input file.

The script uses the following column positions:

| Variable | Column | Meaning |
|---|---:|---|
| `Timestamp` | 1 | Time information |
| `Phase` | 3 | `PSL_UPMU_Voltage0_Angle_L1MagAng` |
| `Amplitude` | 4 | `PSL_UPMU_Voltage0_Magnitude_L1MagAng` |
| `Frequency` | 15 | `PSL_UPMU_Frequency` |

If the first row contains the text `Timestamp`, it is treated as a header and removed before the analysis.

---

## Main Settings

The main analysis parameters are defined near the beginning of the script:

```matlab
Fs = 50;
windowSec = 6;
stepSec = 1;
```

| Parameter | Description |
|---|---|
| `Fs` | PMU reporting rate, fixed at 50 fps |
| `windowSec` | Sliding analysis window length, equal to 6 seconds |
| `stepSec` | Step between consecutive windows, equal to 1 second |

With these settings, each analysis window contains 300 samples, and the algorithm produces one result approximately every second.

---

## How to Run

1. Open MATLAB.
2. Place `INRIM_Algorithm_QPMU_50fps.m` and `50fps_30second_1h.csv` in the same folder.
3. Run the script.
4. When prompted, select the channel to analyze:

```text
1 -> Frequency channel
2 -> Amplitude channel
3 -> Phase channel
```

For example, enter `1` to analyze the frequency channel.

---

## Output Files

Depending on the selected channel, the script creates one of the following CSV files:

| Selected option | Output file |
|---:|---|
| 1 | `frequency_channel_results.csv` |
| 2 | `amplitude_channel_results.csv` |
| 3 | `phase_channel_results.csv` |

### Frequency channel output

The frequency-channel result table contains:

| Column | Description |
|---|---|
| `Timestamp` | Timestamp at the center of the analysis window |
| `DetectedFrequency` | Dominant detected frequency in Hz |

### Amplitude and phase channel output

The amplitude and phase result tables contain:

| Column | Description |
|---|---|
| `Timestamp` | Timestamp at the center of the analysis window |
| `DetectedFrequency` | Dominant detected frequency in Hz |
| `SSO_Amplitude` | Estimated oscillation amplitude from the original, non-normalized signal |

---

## Generated Plots

The script also generates scatter plots to visualize the results.

For the frequency channel, it plots:

- Detected frequency over time

For the amplitude and phase channels, it plots:

- Detected frequency over time
- Estimated oscillation amplitude over time

---

## Algorithm Summary

The script uses a sliding-window approach.

For each window, the algorithm performs the following steps:

1. Removes the central tendency of the signal.
2. Checks whether the window represents a nearly steady-state condition, corresponding to **0 Hz**.
3. Checks whether the signal strongly matches an alternating pattern `(-1)^n`, corresponding to the Nyquist frequency, **Fs/2 = 25 Hz**.
4. Applies detrending, Hann windowing, and FFT to search for ordinary frequency components between approximately **0.2 Hz** and **24.8 Hz**.
5. Uses adaptive thresholds based on the median and MAD of the spectrum.
6. Selects the strongest valid spectral peak.
7. Uses a sinusoidal least-squares fit to verify whether the detected frequency explains enough signal energy.
8. Returns the final detected frequency for the window.

For amplitude and phase channels, the detection is performed on a normalized version of the signal, while the oscillation amplitude is estimated from the original signal.

---

## Special Cases

The algorithm explicitly handles two important edge cases:

### 0 Hz condition

If the signal variation inside the window is very small, the detected frequency is assigned as:

```text
DetectedFrequency = 0 Hz
```

This represents a steady-state or non-oscillatory window.

### Nyquist-frequency condition

Because the sampling rate is 50 fps, the Nyquist frequency is:

```text
Fs / 2 = 25 Hz
```

The script checks for this condition using correlation with an alternating sequence `(-1)^n`.

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
- The input file must contain the expected columns in the correct positions.
- The frequency resolution depends on the selected window length.
- Very short oscillations may be smoothed or missed because the analysis is window-based.
- The method detects the dominant frequency in each window, so weaker simultaneous oscillations may not always be selected.
- The script is designed for PMU output quantities such as frequency, magnitude, and phase, rather than raw high-frequency waveform samples.

---

## Author / Context

This script was developed for PMU data analysis in the context of detecting sub-synchronous or low-frequency oscillatory behavior from PMU output channels.
