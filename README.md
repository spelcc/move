# Move

Move est une application macOS légère qui vit dans la barre de menu et autour de l’encoche. Elle propose des micro-défis, des séances rapides et un historique local, sans compte ni backend.

## V1 livrée

- Capsule d’encoche noire avec fallback écran et animation spring.
- Défis avec validation, refus, remplacement et snooze.
- Notifications système avec actions Fait, Reporter et Passer.
- Scheduler persistant : intervalle, plages horaires, jours actifs, veille/réveil et changement d’heure.
- 50 mouvements intégrés, filtres de contraintes, rotation et variantes adaptatives.
- Mouvements personnalisés archivables dans SwiftData.
- Presets de séances et éditeur de séances personnalisées.
- Runner avec pause, reprise persistée, temps restant et abandon.
- Historique éditable : ajout manuel, correction, suppression, recherche et filtres de base.
- Import JSON dédupliqué et export JSON/CSV.
- Statistiques quotidiennes, activité et séries.
- Onboarding, raccourcis clavier, VoiceOver et lancement à la connexion.

## Développement

Move cible macOS 26 Tahoe, Swift 6.2 et Xcode 26.

```bash
brew install xcodegen
xcodegen generate
open Move.xcodeproj
```

Tests locaux :

```bash
swift test
xcodebuild -project Move.xcodeproj -scheme Move -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

La CI GitHub Actions utilise macOS 26, lance les tests du cœur, compile en Release et publie `Move-unsigned.zip` comme artefact.

## Architecture

- `Sources/MoveCore` : modèles, sélection, scheduler, statistiques et transfert de données.
- `Sources/MoveMac` : SwiftUI, AppKit, encoche, SwiftData, notifications et services système.
- `Tests/MoveCoreTests` : tests unitaires Swift Testing.

Les données restent locales en V1. Les UUID, dates de création/modification et l’archivage logique préparent une future synchronisation iCloud.
