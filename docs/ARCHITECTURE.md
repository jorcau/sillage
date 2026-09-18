# Architecture and measurements

## System capture

Core Audio Process Taps are available from macOS 14.2. Sillage uses `CATapDescription(stereoGlobalTapButExcludeProcesses:)` with `muteBehavior = .unmuted`, so playback continues normally.

The tap feeds a private aggregate device created only for capture and destroyed on stop. No code writes the default output, device volume, or hardware sample rate. Analysis uses the sample rate reported by the tap, which may differ from the physical output device.

`NSAudioCaptureUsageDescription` explains the permission. No microphone permission is requested. Audio is analyzed in memory without recording. Optional Phone display sharing sends bounded visualization snapshots over the local network. The global mix can contain multiple apps and outputs; it is not an electrical measurement of a DAC's analog output.

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
| AudioAnalysis | FFT, RMS/sample peaks, quasi-peak envelopes, waveform, correlation, and phase points |
| AppLocalization | Language resolution and localized resources |
| RemoteDisplay | Local HTTP server, viewer pairing, bounded display snapshots, and bundled web renderer |
| SillageApp | Lifecycle, Settings, controls, and vector rendering |

The HAL callback performs no allocations, locking, FFTs, or SwiftUI work. The 65,536-frame ring accepts interleaved or planar Float32. On overflow, it discards the incoming block and increments a counter without overwriting data being read. A serial queue drains the ring every 8 ms. A short lock protects snapshots outside the audio callback. Teardown stops the callback before freeing its ring.

An output or tap-format change restarts capture and rebuilds analysis for the new sample rate. Failures remain visible. Diagnostics distinguish absent callbacks and incompatible buffers. Valid zero-filled buffers alone cannot distinguish silence, denied permission, and protected content.

## Instrument definitions

- **Levels:** exponential RMS integration of 300 ms, sample peaks, 1.5 s hold, and a 2 s clipping indicator. A sine peaking at −6.02 dBFS measures −9.03 dBFS RMS.
- **Spectrum:** 8,192-point Hann-windowed FFT with a 1,024-sample hop. At 48 kHz: about 5.86 Hz bin resolution, a 171 ms window, and a new FFT every 21.3 ms. The 160 logarithmic bands span 20 Hz–20 kHz and take the maximum bin corrected for coherent window gain. Low bands may share a bin; bands above Nyquist stay empty.
- **Stereo spectrum:** averages L/R FFT power before converting to dB, preserving antiphase signals. One active channel measures 3 dB below the same signal on both channels. This is a peak-amplitude spectrum, without noise-density normalization or slope compensation.
- **Smoothing:** 28 ms attack, 200 ms release, 1.5 s peak hold, then 12 dB/s decay. Display refresh is independent of FFT updates.
- **Goniometer:** X=(L−R)/2 and Y=(L+R)/2 at fixed gain. Mono is vertical; antiphase is horizontal. Normalized correlation integrates over 150 ms and reports zero at insufficient energy. The last 2,048 samples are decimated to 1,024 points.
- **Waveform:** a 20 ms window, triggered on a rising zero crossing in the stronger channel. Both channels share the trigger and sample window. Up to 1,024 min/max columns preserve extrema with fixed ±1 full-scale gain. The window is capped at 4,096 samples; its actual duration is displayed at unusually high sample rates.
- **Quasi-peak:** independent sample-by-sample L/R envelopes, with approximately 10 ms integration and 24 dB release in 2.8 s. The display's TEST mark is −18 dBFS; its relative scale runs from −12 to +12 dB. This is an approximation inspired by historical [EBU Tech 3205](https://tech.ebu.ch/docs/tech/tech3205.pdf), not a certified IEC/EBU instrument, true-peak detector, or loudness measurement.

## Apple Silicon and OLED rendering

The release executable targets arm64. Accelerate supplies optimized analysis primitives. Canvas draws bounded numbers of bars and points independently of display pixel count; SwiftUI handles Retina scaling. No 4K texture is recalculated on the CPU.

The target is 60 Hz, with a 30 Hz option. TimelineView requests updates; it does not guarantee GPU presentation timing. The layout scales from a reference width of about 1,500 points. Actual GPU cadence and power consumption on a physical OLED 4K display still need validation. Direct Metal rendering can be added if profiling or a future spectrogram warrants it.

Text and geometry are calculated at final Canvas dimensions, with no magnification after rasterization. Grids, bars, and OLED drift align with physical pixels. Pure black, adjustable brightness, and silence dimming reduce fixed-element exposure without guaranteeing protection from burn-in.

## Extension points

New analysis runs on the analysis queue and publishes a bounded snapshot through AnalysisFrame.

- **Extended waveform:** configurable timebase and longer multiresolution history beyond the current short triggered window.
- **LUFS / true peak:** separate K-weighting, gating, and oversampling modules validated against reference vectors.
- **Spectrogram:** circular FFT-column storage and a Metal texture.
- **Metadata and artwork:** an asynchronous provider separate from capture and analysis, with caching. Confirm each player's public APIs and permissions first.

Language selection is a UI concern. It never restarts the capture or DSP pipeline.

InstrumentTheme supplies gradient colors and control accents through a SwiftUI environment value. Settings saves the selected theme in UserDefaults, falling back to the legacy colorPalette key when reading earlier preferences; missing or unknown values fall back to Mint. Changes redraw the views without touching audio state. Neutral backgrounds, grids, and warning colors stay independent of the selected theme.

Each theme defines a frequency or level axis for the spectrum. Canvas anchors shared gradients to the full logarithmic frequency range or the fixed −90 to 0 dBFS plot, including peak holds. Settings previews use the same orientation. Both digital meter layouts use their fixed −60 to 0 dBFS scale. Digital goniometer colors span the trace's bounds, preserving its fixed-gain coordinates. Gradients use a bounded set of color stops; no per-pixel CPU rasterization or additional audio analysis is needed. Mint preserves the original appearance. Analog faces and CRT phosphors use fixed material colors.

VisualizerLayout defines eleven saved presentation choices. DashboardInstruments composes the spectrum, digital meters, analog dials, CRT screens, and PPM faces. HiFiRackView combines the same instruments in stacked cabinets. All instruments read the same AnalysisFrame inside one TimelineView. Interactive header/footer controls stay outside this animation loop so native popup selection remains stable during capture; their status readout and whole-pixel OLED drift update once per second. Switching layouts only updates presentation state: it neither restarts capture nor resets smoothing and peak holds. New layouts can compose instruments without introducing another analysis pipeline.

AnalogMeterScale maps the existing 300 ms RMS result to a voltage-based dial with a −18 dBFS reference and a +3 VU end stop. Scale tests cover calibration, monotonicity, voltage ratios, silence, and invalid inputs. Static dial artwork and the moving needles are separate native Canvas layers at final dimensions; they use no external images or new audio processing. Hardware VU ballistics and calibration are not claimed.

HardwareCabinet renders bounded procedural metal grain, wood grain, bevels, and screw heads. CRTScreen separates static glass/grid artwork from signal paths and keeps at most four prior traces for about 200 ms of phosphor persistence. Glow and reflection are presentation effects; they do not change gain, correlation, or measured levels. All artwork is original vector geometry rendered at the current window size.

## Local phone renderer

The optional Network.framework listener serves its own bundled HTML, CSS, JavaScript, icons, and translations on TCP port 8765. A separate queue reads FrameStore at about 30 Hz and sends versioned JSON snapshots through Server-Sent Events. No network work runs in the HAL callback or analysis queue. A slow viewer has only one outstanding send; intermediate frames are dropped, and a send stalled for more than 5 s closes that viewer.

The wire format includes L/R RMS, sample peak, peak hold, quasi-peak and clipping; 160 spectrum/hold bins; up to 256 phase points and 256 min/max waveform columns; correlation; sample rate; and the Mac's view, theme, and source mode. Values are finite, bounded, and rounded. Waveform reduction preserves extrema. No device names, playback metadata, recordings, or continuous audio playback stream are sent.

The browser draws with Canvas 2D and requestAnimationFrame at a selectable 60/30 Hz target. Static material layers are cached. Backing resolution is capped at device pixel ratio 2 and four million pixels. Only three recent CRT traces are retained. Each phone can follow the Mac or keep its own view/theme. Hidden pages close the event stream and suspend drawing; stale measurements clear after about 1.8 s.

Sharing starts disabled and is not enabled automatically on the next launch. Each activation creates a fresh private link. Its fragment is exchanged for an HttpOnly, SameSite=Strict session cookie and removed from the address bar. Stopping sharing closes clients and revokes all sessions. The listener accepts private/local peers, validates Host and Origin, serves an explicit asset allowlist, and limits request sizes, connection lifetime, pairing attempts, and concurrent viewers. It provides no capture-control endpoint. This is an HTTP service for a trusted local network, with no router configuration or cloud relay.

See [Phone display](PHONE-DISPLAY.md) for setup and the distinction between the local browser viewer and an installable HTTPS PWA. [MDN's SSE guide](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) describes the one-way transport and browser connection limits.
