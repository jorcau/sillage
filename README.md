# Sillage — prototype audio natif macOS

<a href="https://digital-strategy.ec.europa.eu/en/policies/eu-icons-labelling-ai-generated-content">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/eu-ai-generated-white.svg">
    <img src="docs/assets/eu-ai-generated-black.svg" alt="AI-generated — code et documentation générés avec l’IA" width="260">
  </picture>
</a>

**Code et documentation générés avec l’IA, à partir de consignes humaines.** Cette mention concerne la création du projet. Les instruments affichent l’audio capturé sur le Mac ; l’application n’utilise pas de modèle génératif à l’exécution.

Le label officiel est affiché volontairement selon les [recommandations de la Commission européenne](https://digital-strategy.ec.europa.eu/en/policies/eu-icons-labelling-ai-generated-content), avec un texte explicite et une alternative accessible. Il ne constitue pas une certification ni, à lui seul, une preuve de conformité à l’AI Act.

Visualiseur local pour Apple Silicon : capture audio système, niveaux stéréo, spectre et goniomètre. Interface SwiftUI en noir pur, rendue avec Canvas. Aucun paquet tiers, aucun pilote audio, aucune connexion réseau.

![Sillage en plein écran, avec un signal de démonstration silencieux](docs/assets/sillage-preview.jpg)

## Démarrer

Ouvrir **Sillage.app**, puis **Écouter**. À la première utilisation, autoriser la capture du son système dans le dialogue macOS. La lecture continue sur la sortie déjà sélectionnée. Si nécessaire, vérifier **Réglages Système → Confidentialité et sécurité → Enregistrement de l’écran et de l’audio système** (le libellé varie selon macOS), puis relancer l’application.

Le menu **Démo** génère seulement des échantillons en mémoire : Musical, Mono 1 kHz, Antiphase, Gauche seule et Silence. Il ne joue aucun son. Le plein écran est accessible par le bouton en haut à droite ou **⌃⌘F**. **⌘R** lance la capture ; **⌘.** la suspend ; **⌘D** lance la démo.

Requis : Mac Apple Silicon, macOS **14.2 minimum**. L’application livrée est un prototype local signé ad hoc, sans notarisation ni distribution App Store. La compatibilité annoncée par le SDK ne remplace pas des essais sur chaque version de macOS.

## Pourquoi les Core Audio Process Taps

Vérification effectuée le 18 septembre 2026 dans la documentation Apple et les en-têtes du SDK local : `AudioHardwareCreateProcessTap` est disponible à partir de macOS 14.2. Un `CATapDescription(stereoGlobalTapButExcludeProcesses:)` copie le mix stéréo des processus. Avec `muteBehavior = .unmuted`, le son continue vers le matériel.

Le tap est attaché à un **périphérique agrégé privé**, créé pour la capture uniquement et détruit à l’arrêt. Cela n’installe pas de pilote et ne remplace pas le périphérique de sortie par défaut. Il n’y a aucun appel d’écriture aux propriétés de sortie système, de volume ou de fréquence du matériel. La fréquence d’analyse est celle annoncée par le tap, sans forcer la fréquence de l’interface audio ou du DAC.

L’autorisation système est décrite par `NSAudioCaptureUsageDescription`. Aucun accès au microphone n’est demandé. Le flux reste en mémoire et n’est ni enregistré ni envoyé. Le mix global peut contenir plusieurs applications et sorties ; il ne constitue pas une mesure électrique de la sortie analogique du DAC. Certains contenus protégés peuvent ne pas être capturables.

ScreenCaptureKit sait aussi fournir l’audio système, mais ajoute un modèle de capture et de filtrage lié au contenu d’écran. Pour cette application exclusivement audio et ciblant les versions modernes de macOS, les taps sont le choix retenu. Un backend ScreenCaptureKit pourra être ajouté pour une éventuelle compatibilité macOS 13, sans modifier les instruments.

Sources primaires :

- [Apple — Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [Apple — CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- [Apple — CATapMuteBehavior.unmuted](https://developer.apple.com/documentation/coreaudio/catapmutebehavior/unmuted)
- [Apple — Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)

## Architecture

```text
Core Audio tap → agrégat privé → callback C → tampon SPSC préalloué
                                                   ↓
                         file d’analyse Swift + Accelerate/vDSP
                                                   ↓
                              AnalysisFrame immuable / FrameStore
                                                   ↓
                                  SwiftUI TimelineView + Canvas
```

| Module | Responsabilité |
|---|---|
| `SystemCapture` | Création/destruction HAL, format, permission, changement de sortie |
| `CRealtime` | Copie Float32 stéréo, atomiques acquire/release, compteur de pertes |
| `AudioAnalysis` | FFT, niveaux, maintien des pics, corrélation, points du goniomètre |
| `SillageApp` | Contrôles, cycle de vie, cadence et dessin vectoriel |

Le callback HAL ne fait ni allocation, ni verrouillage, ni FFT, ni appel SwiftUI. Le tampon de 65 536 trames accepte le Float32 intercalé ou planaire. En saturation, un bloc entrant est abandonné et comptabilisé ; aucune donnée en cours de lecture n’est écrasée. Une file série dépile le tampon toutes les 8 ms. Un verrou très court protège le snapshot hors du callback audio. La destruction attend l’arrêt du callback avant de libérer son tampon.

Un changement de sortie par défaut ou de format du tap relance la capture et recrée l’analyse à la nouvelle fréquence. Un message reste visible en cas d’échec. La capture sans callback et les buffers incompatibles sont distingués du fonctionnement normal dans les diagnostics. Des buffers valides remplis de zéros ne permettent pas, à eux seuls, de distinguer le silence d’une permission refusée ou d’un contenu protégé.

## Ce que mesurent les instruments

- **Niveaux** : RMS avec intégration exponentielle de 300 ms, crêtes d’échantillons, maintien 1,5 s et indicateur de dépassement de 0 dBFS pendant 2 s. Un sinus de crête −6,02 dBFS donne −9,03 dBFS RMS. Ce ne sont pas des VU analogiques calibrés, des mesures LUFS ou des true peaks.
- **Spectre** : FFT de 8 192 points, fenêtre de Hann, pas de 1 024 échantillons. À 48 kHz : résolution ≈5,86 Hz, fenêtre ≈171 ms, nouvelle FFT toutes les ≈21,3 ms. 160 bandes logarithmiques de 20 Hz à 20 kHz ; maximum des bins par bande, corrigé du gain cohérent de la fenêtre. Les bandes très basses peuvent partager un bin : ce ne sont pas 160 bandes indépendantes. Les bandes au-delà de Nyquist restent vides.
- **Stéréo** : les puissances FFT L/R sont moyennées avant conversion en dB ; un signal en antiphase ne s’annule pas. Une seule voie active mesure 3 dB de moins dans ce spectre combiné qu’un signal identique présent sur les deux voies. Le spectre représente des amplitudes de pics, sans normalisation de densité spectrale du bruit ni compensation en pente.
- **Lissage** : attaque du spectre 28 ms, descente 200 ms, maintien des pics 1,5 s puis descente 12 dB/s. Le rendu à 60 Hz est indépendant de la fréquence des FFT.
- **Goniomètre** : X=(L−R)/2, Y=(L+R)/2, échelle fixe sans gain automatique. Mono vertical, antiphase horizontal. Corrélation normalisée avec intégration de 150 ms ; zéro lorsque l’énergie est insuffisante. Trace des 2 048 derniers échantillons, décimée à 1 024 points.

## Affichage, Apple Silicon et OLED 4K

L’exécutable est compilé en **arm64 Release**. Accelerate utilise les primitives optimisées de la plateforme. Canvas dessine un nombre borné de barres et points, indépendant du nombre de pixels de l’écran ; SwiftUI prend en charge le facteur d’échelle Retina. Il n’y a pas de textures 4K recalculées sur le CPU.

La cadence visée est **60 Hz**, sélectionnable à 30 Hz. `TimelineView` est une demande de cadence, pas une garantie de présentation à 60 fps. L’interface agrandit automatiquement ses textes, espacements et instruments sur les grandes résolutions, avec une composition de référence d’environ 1 500 points de large. La mesure des images réellement présentées et de la charge GPU sur l’OLED 4K est une étape de validation matérielle. Metal direct sera pertinent si ce profilage révèle un coût excessif ou lors de l’ajout du spectrogramme. Les diagnostics mesurent les mises à jour de la timeline, pas les présentations GPU.

Le fond est `#000000`. Luminosité par défaut modérée, déplacement lent ±2 points par pas de pixels physiques et atténuation quand le signal devient silencieux. Le système conserve ses mécanismes de veille. Ces précautions réduisent l’exposition des éléments fixes sans garantir l’absence de marquage OLED.

Depuis la version **0.1.1**, les tailles de texte et la géométrie sont calculées avant le dessin, directement dans les dimensions finales de chaque Canvas. Aucune couche de l’interface n’est agrandie après rasterisation. Les graduations, barres et déplacements OLED sont alignés sur les pixels de l’écran, en tenant compte du facteur Retina. L’identifiant technique initial du prototype est conservé lors du renommage en Sillage.

## Extensions prévues

L’analyse et la présentation communiquent uniquement par `AnalysisFrame`. Les nouveaux traitements doivent rester sur la file d’analyse et envoyer un snapshot borné :

- **Waveform** : enveloppes min/max à plusieurs résolutions issues des échantillons avant FFT.
- **LUFS / true peak** : module distinct avec filtrage K, gating et suréchantillonnage, validé sur des vecteurs de référence avant d’afficher une conformité à une norme.
- **Spectrogramme** : tampon circulaire des colonnes FFT, puis texture Metal ; ne pas conserver des milliers de vues SwiftUI.
- **Métadonnées/pochette** : fournisseur asynchrone séparé de la capture et du traitement audio, avec cache. Vérifier les API publiques et autorisations du lecteur concerné avant implémentation ; une API universelle d’accès au morceau courant n’est pas présumée.

## Recompiler

Installer les outils de ligne de commande Apple / Xcode avec Swift 6 ou plus récent. Depuis ce dossier :

```sh
bash scripts/build-app.sh
open dist/Sillage.app
```

Le script accepte aussi le chemin de sortie de l’app puis un dossier de compilation. Il utilise le moteur natif SwiftPM pour éviter une erreur du moteur SwiftBuild observée avec les Command Line Tools locaux. Les caches restent dans le dossier de compilation. `--disable-sandbox` concerne les sous-processus de compilation SwiftPM, pas les réglages de sécurité de macOS.

Tests :

```sh
bash scripts/test.sh
```

Ouvrir `Package.swift` dans Xcode est également possible. Pour la capture réelle, utiliser le bundle `.app` généré, qui contient la déclaration de confidentialité. Un exécutable lancé seul par `swift run` n’est pas le parcours de permission prévu.

Pour le développement, `--demo` lance la démo et `--diagnostics /chemin/absolu.json` active un fichier de compteurs et niveaux renouvelé chaque seconde ; aucune donnée PCM n’y figure. Aucun fichier diagnostic n’est écrit sans cet argument explicite.
