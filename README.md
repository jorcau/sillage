# Sillage

<a href="https://digital-strategy.ec.europa.eu/en/policies/eu-icons-labelling-ai-generated-content"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/eu-ai-generated-white.svg"><img src="docs/assets/eu-ai-generated-black.svg" alt="AI-generated" height="28"></picture></a>
<img src="docs/assets/macos-badge.svg" alt="macOS 14.2 or later" height="28">
<img src="docs/assets/swift-badge.svg" alt="Swift 6 or later" height="28">
<img src="docs/assets/apple-silicon-badge.svg" alt="Apple Silicon arm64" height="28">

A native macOS audio visualizer for Apple Silicon. See your system audio without changing your audio output.

![Sillage in full screen with a silent demo signal](docs/assets/sillage-preview.jpg)

- Stereo RMS and peak meters, a 20 Hz–20 kHz spectrum, and a stereo goniometer.
- Five multicolor palettes plus classic mint, pure black OLED backgrounds, and a 60 Hz target.
- English and French, with silent demo previews in **Settings**.
- Local processing: no recordings, network access, extra drivers, or third-party packages.

## Get started

Requires **Apple Silicon**, **macOS 14.2+**, and **Swift 6+** to build.

```sh
git clone https://github.com/jorcau/sillage.git
cd sillage
bash scripts/build-app.sh
open dist/Sillage.app
```

Click **Listen** and allow system audio capture when macOS asks. Your selected output stays unchanged. This is an early prototype, signed locally and not notarized.

Open **Settings** with the gear button or **⌘,** to choose your palette and language or try a silent demo. Use **⌃⌘F** for full screen, **⌘R** to listen, and **⌘.** to pause.

## More information

- [User guide](docs/USAGE.md) — permissions, settings, demos, and display controls.
- [Architecture and measurements](docs/ARCHITECTURE.md) — capture, analysis, rendering, and planned modules.
- [Development](docs/DEVELOPMENT.md) — builds, tests, and localization.
- [Validation](VALIDATION.md) — tested behavior and current limitations.
