# Move

Move est un coach sportif macOS caché dans l’encoche. Toutes les heures, une capsule noire fait un petit bump et propose un mouvement. L’utilisateur valide, refuse, remplace, ou lance une vraie séance maison.

## Scope actuel

- Capsule noire liée à l’encoche, texte blanc, animation spring/bump.
- Défis horaires avec validation, refus et remplacement.
- Bibliothèque intégrée de mouvements classiques et libres.
- Filtres matériel, sauts, bruit, sol et poignets.
- Séances rapides 5 à 10 minutes inspirées de Workoutloop.
- Runner de séance avec tours et minuterie.
- Historique local via SwiftData.
- Statistiques par activité.
- Barre de menu macOS.
- Architecture `MoveCore` testable séparément.

## Cible

- macOS 26 Tahoe minimum.
- Swift 6.2.
- Xcode 26 stable.

## Générer le projet

```bash
brew install xcodegen
xcodegen generate
open Move.xcodeproj
```

## Tests

```bash
swift test
xcodebuild -project Move.xcodeproj -scheme Move -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Architecture

- `Sources/MoveCore`: modèles, sélection, planning et statistiques.
- `Sources/MoveMac`: SwiftUI, AppKit, encoche, SwiftData et notifications.
- `Tests/MoveCoreTests`: tests unitaires compatibles Swift Package.

Les données restent locales en V1. Les UUID et modèles sont prévus pour une future synchronisation iCloud.
