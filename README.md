# Hangisi Daha?

Hangisi Daha? is a Flutter comparison game for Android and iOS. Classic and 60 Seconds use the same bundled question pool and work without an account, backend, environment file, or network connection.

## Run and verify

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

The app stores onboarding state, sound preference, the Classic hint notice, personal bests, and seen question IDs on the device. Privacy information is in [PRIVACY.md](PRIVACY.md), and question sources are in [SOURCES.md](SOURCES.md). A completed 60 Seconds run reports that the question pool is finished, how many active questions it contained, and the time remaining.

## Bundled content

The app ships 48 active questions in `assets/content/questions.json` and their 96 WebP images under `assets/content/images/<question-id>/`. Each question has distinct A and B images. `SOURCES.md` records the sources used for question facts.

The 96 current image files' rights, licenses, and redistribution permissions have not been verified. Source records do not establish image rights. Review the current assets before distributing or publicly sharing a build. No separate application or content license is selected in this repository. Third-party Flutter and package notice delivery remains a separate pending item.

## Project structure

- `lib/` — Flutter app, local content loader, and gameplay engines
- `assets/content/` — bundled gameplay questions and images
- `assets/audio/` — bundled sound effects
- `test/` — unit, widget, and bundled-content integration tests
