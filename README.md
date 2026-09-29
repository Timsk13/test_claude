# ScreenLimit

Application iPhone qui découpe l'utilisation d'apps choisies en **sessions** séparées par une **pause obligatoire**.

Exemple : Instagram, **8 sessions de 7 minutes**, **45 minutes de pause** entre deux sessions.
- Après 7 minutes d'Instagram, l'app est bloquée pendant 45 minutes.
- Elle se débloque ensuite pour une nouvelle session de 7 minutes, et ainsi de suite.
- Après la 8e session (56 minutes au total), Instagram reste bloqué jusqu'à minuit.

Avec 1 seule session, on retrouve une limite quotidienne classique.

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
│   ├── ContentView.swift          Liste des limites + état (session, pause, bloqué)
│   └── LimitEditorView.swift      Choix des apps, durée/nombre de sessions, pause
├── Shared/AppLimit.swift          Modèle, état du jour, stockage (App Group),
│                                  blocage et logique sessions/pauses (LimitEngine)
├── MonitorExtension/              Extension DeviceActivityMonitor :
│   └── LimitMonitor.swift           réagit aux fins de session, de pause et de journée
├── ShieldConfigurationExtension/  Apparence de l'écran « Temps écoulé »
└── ShieldActionExtension/         Bouton « OK » → ferme l'app bloquée
```

Fonctionnement :
1. L'utilisateur crée une limite (ex. Instagram, 8 × 7 min, pause 45 min).
2. L'app démarre une activité quotidienne (00:00 → 23:59) avec un `DeviceActivityEvent`
   par fin de session : seuils d'usage cumulé à 7, 14, 21… 56 minutes.
3. À chaque seuil, iOS réveille `LimitMonitor` (même si l'app est fermée), qui :
   - bloque les apps (`ManagedSettingsStore.shield`) ;
   - s'il reste des sessions, programme une activité ponctuelle « pause » de 45 min ;
   - sinon, laisse le blocage jusqu'à minuit.
4. À la fin de la pause (`intervalDidEnd`), le blocage est levé pour la session suivante.
5. À minuit, le compteur de sessions repart à zéro et tout est débloqué.

Une session correspond à du temps d'utilisation **cumulé** : utiliser Instagram 3 minutes,
le fermer, puis y revenir 4 minutes plus tard termine la session de 7 minutes.

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

- iOS limite à **20 activités surveillées** simultanément. Chaque limite en utilise 2
  (journée + pause), soit **10 limites maximum**.
- La pause dure au minimum **15 minutes** (durée minimale d'un intervalle DeviceActivity).
- iOS peut réveiller l'extension avec un léger retard (souvent moins d'une minute) :
  la fin d'une session ou d'une pause n'est pas à la seconde près.
- Pour des raisons de confidentialité, les apps choisies sont des *tokens* opaques :
  l'app ne connaît pas leur nom, seul iOS peut les afficher (icônes via `Label(token)`).
- Le blocage peut être contourné en désactivant l'autorisation dans Réglages > Temps d'écran,
  ou en désactivant / supprimant la limite dans l'app (ce qui remet aussi son compteur à zéro).
