# User guide

## System audio

Open Sillage and click **Listen**. macOS controls system audio capture permission. If capture does not start, check **System Settings → Privacy & Security → Screen & System Audio Recording**; the label varies by macOS version. Allow Sillage, reopen the app, and retry.

Sillage creates a private Core Audio tap. It does not replace the default output, change device volume or sample rate, install a driver, or request microphone access. Audio stays in memory. Protected content may not be capturable.

Click **Pause** to stop capture. You can keep listening to music normally while Sillage is paused.

## Settings and language

Open the gear button or **Sillage → Settings…** (**⌘,**).

- **System** follows your preferred supported macOS language, falling back to English.
- **English** and **Français** override that choice for Sillage's interface.
- The choice is saved and applies immediately to app controls, status messages, and accessibility labels without restarting audio capture.

macOS-owned menu items, window controls, and permission dialogs follow system preferences. The capture permission explanation is bundled in English and French; the in-app selection does not override an OS permission dialog.

## Silent demo previews

In **Settings → Demo previews**, choose **Music**, **Mono · 1 kHz**, **Antiphase**, **Left only**, or **Silence**, then click **Start preview**. All samples are generated in memory; no sound is played.

Starting a preview stops system capture. Selecting another signal while a preview is running switches the preview immediately. **Stop preview** returns to the paused state. **Listen to system audio** returns to real capture.

## Display controls

The bottom bar provides peak-hold visibility, OLED precautions, instrument brightness, and a 60 or 30 Hz target refresh rate. Full screen uses native macOS window behavior.

OLED mode uses pure black, subtle movement in whole physical pixels, and dimming during silence. It does not prevent burn-in. System sleep remains enabled.

The meters show digital RMS and sample peaks in dBFS. They are not calibrated analog VU, LUFS, true peak, or SPL meters. A 60 Hz target is not a guarantee of 60 presented frames per second.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘, | Open Settings |
| ⌘D | Open Settings for demo previews |
| ⌘R | Start system capture |
| ⌘. | Pause |
| ⌃⌘F | Toggle full screen |
