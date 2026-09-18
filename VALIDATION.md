# Prototype validation — September 18, 2026

## Observed environment

- Apple Silicon development machine running macOS.
- Swift 6.4, arm64 release build, ad hoc signing, and verified signature.
- Windowed and fullscreen inspection on the available display. No physical OLED 4K validation is claimed.

## Analysis tests

Ten Swift Testing cases passed:

1. Sine calibration: −6.02 dBFS peak / −9.03 dBFS RMS.
2. FFT coherent gain and frequency position at 44.1, 48, and 96 kHz.
3. Antiphase: −1 correlation, preserved spectrum, horizontal trace.
4. Mono vertical trace and left-only channel isolation.
5. Silence, finite values, and peak-hold decay.
6. Clipping detection and indicator timeout.
7. Low- and high-frequency spectrum coverage.
8. Ring wraparound, overflow, loss counters, and NaN/Inf sanitization.
9. Stereo deinterleaving.
10. Faster-than-realtime processing.

Initial measurement: **5 s of stereo audio analyzed in about 0.020 s**, including signal generation. This does not measure HAL capture, SwiftUI/GPU cost, or total latency.

## Settings and localization (0.2.0)

- All **14 tests passed**: the ten analysis tests plus explicit language overrides, regional system-language resolution and fallback, missing-key fallback, and formatted measurements/error details.
- English/French switching was inspected in Settings and the dashboard, including accessibility labels. The selected language persisted across an app restart.
- All five demo choices were present in Settings. Starting a preview and selecting a different signal while it ran were checked; system capture also resumed successfully.
- The packaged app launched with the build-directory resource bundle temporarily removed, confirming that it loads its embedded translations.
- The shared waveform icon was generated at all ten standard/Retina icon sizes, embedded in the app, and the updated app's signature was verified.
- The English fullscreen demo screenshot was refreshed and its metadata removed before publication.

## Live capture

An 8 s stereo test signal, 997 Hz left / 1,499 Hz right, near −48 dBFS, was played through the system player and captured:

- Maximum observed left peak: **−48.071 dBFS**.
- Maximum observed RMS: approximately **−51.65 dBFS** per channel.
- More than **8,600 callbacks**, **0 dropped frames**, and **0 invalid buffers**.
- Device descriptions were identical before and after.
- Default output and device sample rates stayed unchanged.
- The tap supplied 48 kHz audio; tap and hardware sample rates are distinct.

The first start waited for macOS and returned system error 268451843. A retry succeeded. The app now displays guidance after 5 s of waiting. macOS manages capture authorization.

## Display

- Version 0.1.1 removed magnification after rasterization. Canvas draws at final dimensions, with text and OLED motion aligned to physical pixels. The fix was inspected in full screen.
- Silent demos, pause/resume, switching between demo and capture, and native fullscreen controls were checked.
- Pure black background, large-display scaling, and brightness controls were inspected.
- Approximately **59 timeline updates/s** were observed at a 60 Hz target. This is not a GPU presentation count.

## Remaining validation

- Extended use and actual GPU cadence on a 3840 × 2160 OLED.
- Other USB audio interfaces, output switching, unplugging, and sleep/wake.
- Denied/revoked permissions, macOS 14.2 and 15, protected content, and simultaneous outputs.
- Energy profiling and end-to-end latency; the 171 ms FFT window at 48 kHz trades time resolution for frequency resolution.

The instruments measure digital RMS and sample peaks, not LUFS, true peak, SPL, or calibrated analog VU.
