# Validation du prototype — 18 septembre 2026

## Environnement observé

- Machine de développement Apple Silicon sous macOS.
- Compilation Swift 6.4, exécutable arm64 en Release, bundle signé ad hoc et signature vérifiée.
- Interface inspectée en fenêtre et en plein écran sur l’écran disponible. Aucune validation physique d’un écran OLED 4K n’est revendiquée.

## Tests automatisés

10 tests Swift Testing réussis :

1. Sinus −6,02 dBFS crête / −9,03 dBFS RMS.
2. Gain cohérent de la FFT et position fréquentielle à 44,1, 48 et 96 kHz.
3. Antiphase : corrélation −1, spectre conservé, trace horizontale.
4. Mono : trace verticale ; canal gauche seul : droite silencieuse.
5. Silence, valeurs finies et relâchement du maintien de pic.
6. Détection de dépassement et extinction de son indicateur.
7. Couverture grave et aiguë du spectre.
8. Bouclage du tampon, saturation, compteurs de pertes et nettoyage NaN/Inf.
9. Désentrelacement stéréo.
10. Calcul plus rapide que le temps réel.

Mesure initiale du moteur sur la machine de développement : **5 s de son stéréo analysées en environ 0,020 s**, génération du signal de test comprise. Ce benchmark ne mesure ni la capture HAL, ni le coût SwiftUI/GPU, ni la latence totale.

## Capture réelle

Un signal de 8 s, gauche 997 Hz / droite 1 499 Hz, amplitude proche de −48 dBFS, a été joué avec le lecteur système puis reçu par le tap :

- Crête gauche maximale observée : **−48,071 dBFS**.
- RMS maximum observé sur les snapshots : environ **−51,65 dBFS** sur les deux voies.
- Plus de **8 600 callbacks** au dernier snapshot de la session ; **0 trame perdue**, **0 buffer invalide**.
- Les descriptions des périphériques retournées par macOS étaient **identiques avant et après**.
- Sortie par défaut et fréquences des périphériques inchangées.
- Le mix fourni par le tap était à **48 kHz**. La fréquence du tap et celle du matériel sont distinctes ; l’application ne modifie ni l’une ni l’autre.

Le premier démarrage a attendu macOS puis retourné l’erreur système 268451843. Une nouvelle tentative a démarré correctement. L’application affiche désormais une indication après 5 s d’attente. Le système gère l’autorisation de capture ; le prototype ne tente pas de la contourner.

## Interface et performances

- Version 0.1.1 : agrandissement après rasterisation supprimé, Canvas dimensionnés à leur taille finale, textes et déplacements OLED alignés sur les pixels physiques. Rendu inspecté en plein écran après correction.
- Démo silencieuse, arrêt/reprise et passage démo/capture vérifiés.
- Plein écran natif et raccourci ⌃⌘F vérifiés.
- Mise à l’échelle de l’interface pour les grandes résolutions, fond noir pur et luminosité réglable inspectés visuellement.
- Environ **59 mises à jour de timeline/s** observées pour une cible de 60 Hz. Il s’agit des mises à jour SwiftUI, pas d’un comptage des images présentées par le GPU.

## Validation restant à effectuer

- Session prolongée et cadence GPU réelle sur l’OLED **3840 × 2160**, en fenêtre et plein écran.
- Vérification avec d’autres interfaces audio USB, changement de sortie, débranchement et veille/réveil.
- Refus/révocation de permission, versions macOS 14.2 et 15, contenus protégés et plusieurs sorties simultanées.
- Profilage énergétique et latence bout en bout. La fenêtre FFT de 171 ms à 48 kHz impose un compromis de résolution/latence.

Ce prototype affiche des **niveaux numériques RMS / crête d’échantillons** ; il ne prétend pas fournir une mesure LUFS, true peak, SPL ou un VU analogique calibré.
