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

## Color palettes (0.2.1)

- Release build and signature verification succeeded; all **14 existing tests passed**.
- Inspected all six palette previews and the selected-state checkmark in French Settings.
- Verified immediate palette changes during system capture, including multicolor spectrum bars, peak holds, stereo meters, and goniometer rendering.
- Confirmed the selected palette is written to the app's persistent preferences.
- The five gradient palettes preserve the black background, fixed instrument scales, and separate warning/clipping indicators. Mint retains the original single-color appearance.

## Themes, views, and analog meters (0.3.0)

- The arm64 release build and packaged app signature passed. All **16 tests passed**, including two new analog-scale tests for the −18 dBFS reference, end stops, monotonicity, voltage ratios, silence, and invalid values.
- Inspected all nine theme previews in English and French, including their frequency/level labels. Thermal's vertical spectrum gradient and held peaks were inspected during system capture.
- Inspected dashboard, large digital meters, spectrum, stereo, and analog views. View shortcuts worked, and the selected theme/view were present in persistent preferences.
- Reproduced the unstable nested view menu during animation. Replaced it with a direct native picker outside the instrument TimelineView; mouse selection remained usable after leaving the popup open during silent-demo analysis and live system capture.
- Confirmed the brightness control starts at **100%**.
- Inspected analog artwork and moving needles at the available window size. A left-only silent demo moved the left needle to its upper stop while the right needle rested at zero voltage.
- Captured an English analog-view screenshot using the silent demo and stripped its metadata before publication.
- A later system-capture reconnection stalled inside Core Audio’s AudioDeviceStart. A fresh Sillage process and a separate system-player attempt with digital silence did not clear it. Demo rendering remained functional; recovery of the macOS audio service still needs verification.
- No new claim of hardware VU calibration, physical 4K OLED validation, or measured GPU presentation cadence is made.

## Analog instrument collection (0.4.0)

- The arm64 release build and packaged app signature passed. All **19 tests passed**.
- New tests cover waveform amplitude, stereo polarity, a fixed window, and the 1,024-column bound at 44.1, 48, and 96 kHz. Quasi-peak tests cover 5/10 ms tone bursts, steady-state calibration, 24 dB return in 2.8 s, invalid inputs, channel isolation, and independence from processing block size.
- Inspected all six new views in the running app: Studio Blue, Vintage Console, CRT Oscilloscope, CRT Goniometer, Broadcast PPM, and Hi-Fi Rack. Rechecked the finished artwork in native full screen, including glass, needles, lighting, and waveform persistence.
- Verified the new shortcuts, English/French labels, saved view selection, and brightness at **100%**. The native view picker stayed open during animation and accepted mouse selection afterward.
- Observed approximately **58–59 timeline updates/s** at the 60 Hz target during silent-demo CRT/rack rendering. This is not a GPU presentation count. The analysis benchmark processed 5 s of stereo audio in about **0.021 s**; it excludes capture and rendering.
- Added six English screenshots generated with the silent Music demo. Removed JPEG metadata before publication.
- Returning from the demo to system capture again remained at the macOS connection stage with zero callbacks. The earlier Core Audio reconnection limitation remains unresolved; the audio service was not restarted as part of this view update.
- VU/PPM hardware certification, physical 4K OLED performance, and power consumption remain unverified.

## Local phone display (0.5.0)

- The arm64 release build and packaged app signature passed. All **23 Swift tests** and **3 web tests** passed.
- New Swift checks cover incremental HTTP parsing, ambiguous framing, request limits, host/origin restrictions, local address scope, finite bounded snapshots, stereo polarity, and waveform extrema. Web checks cover protocol validation, VU calibration, and English/French key coverage.
- A probe against the running packaged app verified every bundled web asset, pairing, session cookies, unauthorized access rejection, host/origin rejection, traversal rejection, and ten increasing live frames. Test snapshots stayed below 13 KB. Testing used the silent Music demo; no new system-capture success is claimed.
- Inspected the web interface at **390 × 844** and **844 × 390** browser viewport sizes, including the dashboard, analog meters, Studio Blue, CRT views, PPM, and hi-fi rack. Checked mobile controls, English/French switching, independent view selection, and landscape Focus mode.
- Stopping sharing disconnected the viewer and cleared stale levels. Restarting sharing rotated the private link and rejected the previous session. Pairing with the replacement link in an already-open tab succeeded.
- The server serves resources from the app's embedded bundle. It no longer attempts to open a developer build-directory bundle when running as a packaged app.
- Actual iPhone/Android browsers, camera scanning, phone sleep/wake, Wi-Fi roaming, sustained power use, and physical-device frame rates still need validation. The 60 Hz option is a render target; measurements arrive at about 30 Hz.
- The viewer runs over local HTTP. HTTPS-only PWA installation, service-worker behavior on a secure deployment, and screen wake lock have not been validated on phones.

## Audio status and details (0.5.1 — September 19, 2026)

- The arm64 release build and packaged app signature passed. All **25 Swift tests passed**.
- New tests distinguish actual silent input from synthetic meter-decay zeros, expire input activity after two seconds, reject invalid timestamps, and reset activity across pipeline restarts. The pipeline test covers 44.1/96 kHz capture configurations and the 48 kHz silent demo.
- Inspected the French footer and Audio details popover in the packaged app: paused and connecting states hide active format values; Music demo shows 48 kHz, two channels, 32-bit float PCM, and an 8,192-sample FFT window lasting 170.7 ms. Loss and invalid-buffer counts were zero.
- The popover remained open across ongoing demo animation and showed readable layout, localized labels, and a close control. English/French resource keys were checked for duplicates.
- System capture was active before the app update, but reconnecting after the restart reproduced the earlier macOS waiting condition. The new footer correctly showed **Waiting for audio**. Live system-format presentation after reconnection remains unverified; this update does not claim to fix Core Audio startup.

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

The instruments measure digital RMS, sample peaks, and a dedicated quasi-peak envelope, not LUFS, true peak, SPL, or certified hardware VU/PPM.
