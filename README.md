# Habit Tracker

A polished, offline-first Flutter habit tracker built from the reference requirements supplied for this project.

## Current v1
- Daily habit dashboard and completion controls
- 12 starter habits with categories and monthly goals
- Daily calendar/date navigation
- Weekly progress analytics and top-habit ranking
- To-Do list with progress and swipe-to-delete
- Profile/settings overview
- Local persistence using SharedPreferences
- **Offline daily habit reminders with local notifications**
- No paid API, AI API, or cloud backend required

## Run

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

The `flutter create` command is safe for an empty repository and generates the Android project files locally. The CI workflow does the same on GitHub before analysis and tests.

## Reminders

The reminder engine uses `flutter_local_notifications` and the `timezone` package. Reminders are scheduled locally on the device, so they do not require an account, server, Firebase project, or internet connection.

## Product direction

The app uses the supplied screenshots as the feature and visual reference: daily tracking, weekly/monthly progress, goals, analytics, reminders, and a To-Do bonus. Implementation and branding are original.

## Cost

Designed for **₹0 development cost** for the current offline-first version.
