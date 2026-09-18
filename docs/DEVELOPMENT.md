# Development

## Build

Install Apple Command Line Tools or Xcode with Swift 6 or newer.

```sh
bash scripts/build-app.sh
open dist/Sillage.app
```

The script accepts an app output path followed by a build directory. It uses SwiftPM's native build engine to avoid a SwiftBuild property-list error observed with the local Command Line Tools. Caches remain inside the build directory. The SwiftPM `--disable-sandbox` flag concerns build subprocesses, not macOS security settings.

The script embeds localization bundles, adds the capture privacy declaration, signs the app ad hoc, and verifies its signature. This is not a notarized release. The prototype's original bundle identifier is retained across its rename to preserve application identity.

You can also open Package.swift in Xcode. Use the generated app bundle for real capture; a standalone `swift run` executable is not the intended permission flow.

## Tests

```sh
bash scripts/test.sh
```

Tests cover DSP calibration, stereo behavior, ring-buffer safety, processing cost, and language resolution. See [validation](../VALIDATION.md) for measured results and remaining hardware checks.

## App icon

The dashboard and app icon share the original waveform in SillageMark.swift. After changing its geometry or brand color, regenerate the committed icon assets on macOS:

```sh
bash scripts/generate-icon.sh
```

This produces the full macOS icon set, including Retina sizes, and a PNG preview. The app build embeds AppIcon.icns; no image-generation service or external dependency is needed.

## Localization

English is the source language for code and documentation. User-facing translations belong in `Sources/AppLocalization/Resources/<language>.lproj/Localizable.strings`. Keep English keys and format placeholders identical across languages.

The app offers System, English, and French. An explicit choice is saved in UserDefaults; System resolves the first supported macOS preference, falling back to English. AppLocalizer resolves a resource bundle directly, so switching updates the app immediately without restarting capture.

Localized macOS permission text lives in `Resources/<language>.lproj/InfoPlist.strings`. macOS chooses that language independently of the in-app setting.

To add a language, add its resources, update AppLanguage and supported language resolution, expose it in Settings, and include the corresponding bundle localization. Test regional matching, unsupported-language fallback, formatted measurements, and the built app outside the build directory.

Apple references: [SettingsLink](https://developer.apple.com/documentation/swiftui/settingslink) and [localizing package resources](https://developer.apple.com/documentation/xcode/localizing-package-resources).

## Diagnostics

Launch with `--demo` for a silent developer preview. An explicit `--diagnostics /absolute/path.json` argument writes counters and levels once per second, without PCM samples. No diagnostic file is written by default.

Diagnostics count SwiftUI timeline updates, not frames presented by the GPU. Keep diagnostics and recordings out of commits.
