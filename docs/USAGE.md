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

## Color palettes

Open **Settings → Color palette** and click a preview. The checkmark identifies the active choice.

| Palette | Color progression |
|---|---|
| Mint (Default) | Original mint appearance |
| Aurora | Blue → cyan → mint → pale lime |
| Ember | Rose → coral → gold → cream |
| Twilight | Blue → violet → pink → peach |
| Prism | Blue → cyan → green → yellow → rose |
| Lagoon | Sand → turquoise → blue → lavender |

The five new palettes use multicolor gradients within each instrument. Spectrum colors follow the logarithmic frequency axis; meter colors follow the fixed −60 to 0 dBFS scale. The goniometer blends colors across the visible trace without changing its geometry or gain. Its colors are decorative, not an additional measurement.

Colors update immediately across the spectrum, peak holds, meters, goniometer, and controls, including while capture is running or paused. The choice is saved for the next launch. Choose Mint to restore the original appearance.

Every palette keeps the pure black background, neutral grid and text, and existing brightness/OLED controls. Warning indicators remain amber and clipping remains red. The app's mint logo and Dock icon retain their brand color.

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
