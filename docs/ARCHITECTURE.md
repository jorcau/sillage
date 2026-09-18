# Architecture and measurements

## System capture

Core Audio Process Taps are available from macOS 14.2. Sillage uses `CATapDescription(stereoGlobalTapButExcludeProcesses:)` with `muteBehavior = .unmuted`, so playback continues normally.

The tap feeds a private aggregate device created only for capture and destroyed on stop. No code writes the default output, device volume, or hardware sample rate. Analysis uses the sample rate reported by the tap, which may differ from the physical output device.

`NSAudioCaptureUsageDescription` explains the permission. No microphone permission is requested. Audio is neither recorded nor transmitted. The global mix can contain multiple apps and outputs; it is not an electrical measurement of a DAC's analog output.

ScreenCaptureKit is an alternative for a future macOS 13 backend, but its screen-content filtering model adds unnecessary complexity for the current audio-only target.

Apple references:

- [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- [Unmuted tap behavior](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/unmuted)
- [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)

## Data flow

```text
Core Audio tap → private aggregate → C callback → preallocated SPSC ring
                                                        ↓
                                      Swift analysis queue + Accelerate/vDSP
                                                        ↓
                                      immutable AnalysisFrame / FrameStore
                                                        ↓
                                           SwiftUI TimelineView + Canvas
```

| Module | Responsibility |
|---|---|
| SystemCapture | HAL lifecycle, capture format, output changes, and errors |
| CRealtime | Stereo Float32 copying, acquire/release atomics, and loss counters |
| AudioAnalysis | FFT, levels, peak hold, correlation, and phase points |
| AppLocalization | Language resolution and localized resources |
| SillageApp | Lifecycle, Settings, controls, and vector rendering |

The HAL callback performs no allocations, locking, FFTs, or SwiftUI work. The 65,536-frame ring accepts interleaved or planar Float32. On overflow, it discards the incoming block and increments a counter without overwriting data being read. A serial queue drains the ring every 8 ms. A short lock protects snapshots outside the audio callback. Teardown stops the callback before freeing its ring.

An output or tap-format change restarts capture and rebuilds analysis for the new sample rate. Failures remain visible. Diagnostics distinguish absent callbacks and incompatible buffers. Valid zero-filled buffers alone cannot distinguish silence, denied permission, and protected content.

## Instrument definitions

- **Levels:** exponential RMS integration of 300 ms, sample peaks, 1.5 s hold, and a 2 s clipping indicator. A sine peaking at −6.02 dBFS measures −9.03 dBFS RMS.
- **Spectrum:** 8,192-point Hann-windowed FFT with a 1,024-sample hop. At 48 kHz: about 5.86 Hz bin resolution, a 171 ms window, and a new FFT every 21.3 ms. The 160 logarithmic bands span 20 Hz–20 kHz and take the maximum bin corrected for coherent window gain. Low bands may share a bin; bands above Nyquist stay empty.
- **Stereo spectrum:** averages L/R FFT power before converting to dB, preserving antiphase signals. One active channel measures 3 dB below the same signal on both channels. This is a peak-amplitude spectrum, without noise-density normalization or slope compensation.
- **Smoothing:** 28 ms attack, 200 ms release, 1.5 s peak hold, then 12 dB/s decay. Display refresh is independent of FFT updates.
- **Goniometer:** X=(L−R)/2 and Y=(L+R)/2 at fixed gain. Mono is vertical; antiphase is horizontal. Normalized correlation integrates over 150 ms and reports zero at insufficient energy. The last 2,048 samples are decimated to 1,024 points.

## Apple Silicon and OLED rendering

The release executable targets arm64. Accelerate supplies optimized analysis primitives. Canvas draws bounded numbers of bars and points independently of display pixel count; SwiftUI handles Retina scaling. No 4K texture is recalculated on the CPU.

The target is 60 Hz, with a 30 Hz option. TimelineView requests updates; it does not guarantee GPU presentation timing. The layout scales from a reference width of about 1,500 points. Actual GPU cadence and power consumption on a physical OLED 4K display still need validation. Direct Metal rendering can be added if profiling or a future spectrogram warrants it.

Text and geometry are calculated at final Canvas dimensions, with no magnification after rasterization. Grids, bars, and OLED drift align with physical pixels. Pure black, moderate default brightness, and silence dimming reduce fixed-element exposure without guaranteeing protection from burn-in.

## Extension points

New analysis runs on the analysis queue and publishes a bounded snapshot through AnalysisFrame.

- **Waveform:** multiresolution min/max envelopes from samples before the FFT.
- **LUFS / true peak:** separate K-weighting, gating, and oversampling modules validated against reference vectors.
- **Spectrogram:** circular FFT-column storage and a Metal texture.
- **Metadata and artwork:** an asynchronous provider separate from capture and analysis, with caching. Confirm each player's public APIs and permissions first.

Language selection is a UI concern. It never restarts the capture or DSP pipeline.
