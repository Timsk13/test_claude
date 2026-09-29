# ScreenLimit

Application iPhone qui permet de fixer un **temps d'utilisation quotidien** pour des apps choisies.
Une fois le temps écoulé, les apps sont **bloquées** par un écran de blocage jusqu'à minuit.

Elle s'appuie sur les API officielles « Temps d'écran » d'Apple :

| Framework | Rôle |
|---|---|
| **FamilyControls** | Autorisation Temps d'écran + sélecteur d'apps (`FamilyActivityPicker`) |
| **DeviceActivity** | Surveille le temps d'usage cumulé et déclenche un événement au seuil |
| **ManagedSettings** | Pose / retire le blocage (`shield`) sur les apps |
| **ManagedSettingsUI** | Personnalise l'écran de blocage |

## Architecture

```
ScreenLimit/
├── App/                           App principale (SwiftUI)
│   ├── ScreenLimitApp.swift
│   ├── LimitsModel.swift          Autorisation, sauvegarde, démarrage de la surveillance
│   ├── ContentView.swift          Liste des limites
│   └── LimitEditorView.swift      Choix des apps + durée
├── Shared/AppLimit.swift          Modèle, stockage (App Group), blocage/déblocage
├── MonitorExtension/              Extension DeviceActivityMonitor :
│   └── LimitMonitor.swift           bloque au seuil, débloque à minuit
├── ShieldConfigurationExtension/  Apparence de l'écran « Temps écoulé »
└── ShieldActionExtension/         Bouton « OK » → ferme l'app bloquée
```

Fonctionnement :
1. L'utilisateur crée une limite (ex. « Réseaux sociaux », 45 min, Instagram + TikTok).
2. L'app démarre un `DeviceActivitySchedule` quotidien (00:00 → 23:59) avec un
   `DeviceActivityEvent` dont le seuil est la durée choisie.
3. Quand le seuil est atteint, iOS réveille `LimitMonitor` (même si l'app est fermée),
   qui applique un `ManagedSettingsStore.shield` sur les apps sélectionnées.
4. Au début de l'intervalle suivant (minuit), le blocage est levé.

## Prérequis

- Un **Mac avec Xcode 16+**
- Un **iPhone physique** sous iOS 17.4+ (les API Temps d'écran ne fonctionnent pas dans le simulateur)
- Un compte **Apple Developer** : la capacité *Family Controls* est disponible en développement ;
  pour publier sur l'App Store, il faut demander l'entitlement de distribution à Apple
  ([formulaire](https://developer.apple.com/contact/request/family-controls-distribution)).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `brew install xcodegen`

## Installation

1. Dans `project.yml`, remplace :
   - `com.example` / `com.example.screenlimit*` par ton propre identifiant (ex. `com.tonnom`)
   - `group.com.example.screenlimit` par ton App Group (aussi dans `Shared/AppLimit.swift`)
   - `DEVELOPMENT_TEAM` par ton Team ID
2. Génère le projet puis ouvre-le :
   ```sh
   xcodegen generate
   open ScreenLimit.xcodeproj
   ```
3. Branche ton iPhone, sélectionne le schéma **ScreenLimit** et lance (⌘R).
4. Au premier lancement, touche **Autoriser** et valide avec Face ID / code.

## Limites connues

- iOS limite à **20 activités surveillées** simultanément, donc 20 limites maximum.
- Pour des raisons de confidentialité, les apps choisies sont des *tokens* opaques :
  l'app ne connaît pas leur nom, seul iOS peut les afficher (icônes via `Label(token)`).
- Le blocage peut être contourné en désactivant l'autorisation dans Réglages > Temps d'écran,
  ou en supprimant la limite dans l'app.
