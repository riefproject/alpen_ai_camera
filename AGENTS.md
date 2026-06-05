# AGENTS.md

## Project

Flutter app — **Alpen AI Camera** (smart photography assistant with AI pose estimation + real-time image processing).

## Commands

```
flutter pub get       # install deps
flutter analyze       # lint + static analysis (must pass, 0 issues)
flutter test          # run all tests
flutter run           # run on connected device/emulator
```

Run order: `pub get -> analyze -> test`. No CI or pre-commit configured.

## Architecture

Clean Architecture under `lib/`:

| Layer | Dir | Role |
|-------|-----|------|
| Presentation | `lib/presentation/` | UI screens, controllers (ChangeNotifier), widgets |
| Domain | `lib/domain/` | Entities, service interfaces, use cases |
| Data | `lib/data/` | Models, service implementations, data sources |
| Core | `lib/core/` | Constants, math utilities, shared helpers |

Entry point: `lib/main.dart` -> `CameraHomeScreen` (single screen, no routing yet).

Controllers use `ChangeNotifier`. Services are defined as interfaces in `domain/services/` with implementations in `data/services_impl/`.

## Key Dependencies

- **camera** ^0.12 — device camera access
- **google_mlkit_pose_detection** ^0.14 — real-time pose estimation
- **google_mlkit_selfie_segmentation** ^0.10 — background removal
- **hive_ce_flutter** ^2.3 — local storage (pose templates)
- **image** ^4.8 — pixel-level image manipulation (filters)
- **flutter_launcher_icons** — app icon generation

## Current State (read plan.md for roadmap)

Many domain services and use cases are still **stubs**. The `CameraHomeScreen` holds most camera logic (zoom, filters, flash, capture) directly — refactoring to controllers/services is in progress per `plan.md` Fase 1.

Analyzer is clean (0 issues). All 9 tests pass.

## Python Tools

`tools/python/` contains subdirectories for `export/`, `preprocessing/`, `training/` — `requirements.txt` is empty. These are placeholder dirs, not yet functional.

## Conventions

- SDK: Dart ^3.10.8
- Lints: `package:flutter_lints/flutter.yaml` (no custom rules)
- Material 3, teal seed color
- Min Android SDK: 21
- App icon source: `assets/icon/icon.png`
