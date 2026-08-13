# Flutter Agentic App

A Flutter app that generates topic-based jokes using **Firebase AI Logic** (Gemini) with **Provider** for state management and **Firebase App Check** for API protection.

## Features

- Generate jokes by topic (`Puns`, `Tech`, `Corporate`, `Marriage`)
- Paginated joke loading via Gemini (`gemini-2.5-flash`)
- Structured JSON responses parsed into local models
- Firebase App Check (debug provider for local development)

## Tech stack

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase initialization |
| `firebase_ai` | Gemini via Firebase AI Logic |
| `firebase_app_check` | Protect Gemini API calls |
| `provider` | State management |

## Project structure

```
lib/
├── main.dart                 # App entry, Firebase + App Check init
├── firebase_options.dart     # FlutterFire-generated options
├── model/joke.dart           # Joke / response models
├── presentation/home_page.dart
├── provider/
│   ├── base_provider.dart
│   └── jokes_provider.dart   # Topic + pagination state
└── services/
    └── gemini_service.dart   # Prompt building + Gemini calls
```

## Prerequisites

- Flutter SDK (Dart `^3.8.0`)
- A Firebase project with **Firebase AI Logic** enabled
- Firebase App Check enforced for Firebase AI Logic  
  ([docs](https://firebase.google.com/docs/ai-logic/app-check))

## Setup

1. Clone and install dependencies:

```bash
flutter pub get
```

2. Configure Firebase (if regenerating options):

```bash
flutterfire configure
```

3. Enforce App Check in Firebase Console:
   - **Security → App Check → APIs**
   - Set **Firebase AI Logic** baseline protection to **Enforced**

4. For local/debug builds, register your App Check debug token:
   - Run the app and copy the debug token from logs
   - **App Check → Apps → Manage debug tokens** → add the token  
   - Flutter debug provider docs: https://firebase.google.com/docs/app-check/flutter/debug-provider

5. Run the app:

```bash
flutter run
```

## App Check notes

`main.dart` currently activates the **Android debug** provider:

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.debug,
);
```

- Use `AndroidProvider.debug` / `AppleProvider.debug` only for development
- For production, switch to Play Integrity (Android) and App Attest / DeviceCheck (iOS)
- Without a valid App Check token, Gemini calls fail with:  
  `Firebase AI Logic has been deactivated... you must enforce Firebase App Check`

## How joke generation works

1. `JokesProvider` requests jokes for the selected topic and page
2. `GeminiService` builds a JSON-schema prompt and calls `generateContent`
3. The model response is cleaned and decoded into `JokeResponse`
4. Results are appended (pagination) or replaced (topic change / refresh)

## Useful links

- [Firebase AI Logic + App Check](https://firebase.google.com/docs/ai-logic/app-check)
- [Flutter App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [FlutterFire](https://firebase.flutter.dev/)
