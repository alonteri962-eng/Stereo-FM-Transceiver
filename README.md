# Stereo FM Transmitter & Receiver (MATLAB)

Implementation of a full FM communication chain for **mono and stereo audio**:
modulation, demodulation, filtering, resampling, and stereo channel reconstruction.

## Features
- Mono FM: audio → FM modulation → demodulation → audio recovery
- Stereo FM composite baseband:
  - L+R (0–15 kHz)
  - L−R on 38 kHz DSB-SC
  - 19 kHz pilot tone
- FM demodulation using phase derivative
- Filtering and resampling stages (audio rate ↔ transmission rate)

## Repository Structure
- `mono/` – Mono FM transmitter & receiver scripts
- `stereo/` – Stereo FM transmitter & receiver scripts
- `docs/` – Full lab report (PDF)

## How to Run (High-level)
1. Run mono or stereo modulation script to generate the transmitted FM signal.
2. Run the matching demodulation script to recover the audio.
3. Adjust file paths and parameters as needed.
