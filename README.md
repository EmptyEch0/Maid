<div align="center">

# 🤖 MAID — Modern AI Assistant & Intelligent Dashboard

**An offline-first, intelligent productivity engine, study planner, and smart schedule optimizer built with Flutter.**

[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-4CAF50?style=for-the-badge)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20First-green?style=for-the-badge&logo=shield)](https://github.com/EmptyEch0/Maid)

</div>

---

## 📖 Overview

**MAID** (Modern AI-driven Assistant & Intelligent Dashboard) is an all-in-one personal productivity companion designed for students, developers, and power users. Built from the ground up with **Flutter** and **Material 3 Glassmorphism**, MAID combines time-blocking, algorithmic study planning, natural language voice commands, deep analytics, and privacy-first local data storage into a cohesive, high-performance mobile experience.

---

## ✨ Key Features

### 🎙️ 1. Offline Voice Assistant & Local NLP
* **Zero Cloud Dependency**: Speech-to-Text and Text-to-Speech operating entirely locally on your device.
* **Natural Language Parser Engine (`NlpParserEngine`)**: Automatically parses commands like *"Schedule DSA practice tomorrow at 4 PM"* or *"Remind me to submit project on Friday"*.
* **Local Query Engine (`LocalQueryEngine`)**: Instant semantic searching across all events, tasks, notes, and study logs.

### 📅 2. Dynamic Calendar & Intelligent Scheduling
* **Time-Blocking & Recurrence**: Support for recurring schedules, routine rules (`RecurrenceRule`), and smart conflict resolution.
* **Universal Rescheduler**: Seamless exception handling (`ScheduleException`) that lets you shift tasks and routines without breaking master schedules.
* **Visual Time Map**: Color-coded categorization (Study, Work, Health, Routine, Personal).

### 🚀 3. DSA Roadmap & Mastery Tracker
* **Curated Curriculum (`DsaPlanSeeder`)**: Pre-loaded step-by-step Data Structures & Algorithms roadmap.
* **Topic Breakdowns**: Detailed problem lists, completion metrics, and milestone progression.
* **Interactive Checklists**: Real-time status updates and revision tracking.

### ⏱️ 4. Focus Study Timer & Pomodoro Engine
* **Customizable Intervals**: Work/break intervals tailored to your focus rhythm.
* **Heatmap Activity Matrix (`StudyHeatmap`)**: GitHub-style daily commit/study activity heatmap.
* **Weekly Review Engine (`WeeklyReviewEngine`)**: Automated weekly retrospectives, efficiency scores, and actionable feedback.

### ⏰ 5. Advanced Alarms & Wake-up System
* **Custom Audio Engine (`just_audio`)**: Support for custom audio files and bundled alarm tones.
* **Interactive Ringing Screen**: Full-screen dialog with snooze and dismissal controls.
* **Exact Scheduling**: Powered by `flutter_local_notifications` and exact alarm permissions for guaranteed reliability.

### 📝 6. Rich Notes & Linked Knowledge Base
* **Cross-linked Context**: Link notes directly to calendar events, tasks, and DSA topics.
* **Tagging & Filtering**: Instant organization with multi-tag support and search.

### 🔒 7. Privacy & Security
* **100% Offline Storage**: All personal data is stored locally in an encrypted/isolated SQLite database (`sqflite`).
* **App Lock Protection**: PIN and biometric verification screen (`AppLockScreen`).

---

## 🎨 UI / UX Design System

MAID features a modern **Glassmorphism Design Language**:
* **Theme Support**: Seamless switching between Ultra-Clean White Glass & Frosted Dark Mode.
* **Dynamic Animations**: Smooth micro-interactions, staggered card entrances (`AnimatedEntry`), and interactive haptic feedback.
* **Responsive Layouts**: Designed to adapt fluidly across phones, tablets, and desktop viewports.

---

## 🏗️ Architecture & Project Structure

```
lib/
├── engine/                      # Core business logic & heuristic engines
│   ├── dsa_plan_seeder.dart     # Pre-seeded DSA curriculum & roadmaps
│   ├── local_query_engine.dart  # Offline search & NLP retrieval engine
│   ├── nlp_parser_engine.dart   # Natural language intent & date parser
│   ├── scheduling_engine.dart   # Conflict detector & recurring planner
│   ├── study_timer_engine.dart  # Pomodoro & study session tracking
│   └── weekly_review_engine.dart# Performance aggregator & analytics
├── models/
│   └── app_models.dart          # Data models (Event, Task, Alarm, Note, etc.)
├── providers/
│   └── app_provider.dart        # Central ChangeNotifier state management
├── services/                    # Device & OS integration services
│   ├── alarm_service.dart       # Alarm manager
│   ├── alarm_sound_service.dart # Audio player & ringtone selector
│   ├── audio_haptics_service.dart# Vibration & sound feedback
│   ├── database_helper.dart     # SQLite CRUD operations
│   ├── notification_service.dart# Local notifications scheduler
│   ├── permission_service.dart  # Runtime Android/iOS permissions
│   ├── speech_service.dart      # Speech-to-text listener
│   └── tts_service.dart         # Text-to-speech engine
├── ui/                          # Presentation layer
│   ├── app_lock_screen.dart     # Security lock & PIN verification
│   ├── home_shell.dart          # Bottom navigation & main layout
│   ├── screens/                 # Feature screens (Calendar, Tasks, DSA, etc.)
│   └── widgets/                 # Reusable glass cards, dialogs & heatmaps
└── main.dart                    # Application entry point & theme definitions
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.44.0`)
* [Dart SDK](https://dart.dev/get-dart) (`>= 3.12.0`)
* [Android Studio](https://developer.android.com/studio) / Xcode (for iOS)
* Android SDK (`API Level 34+` / Android 14+)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/EmptyEch0/Maid.git
   cd Maid
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run
   ```

---

## 📦 Building the Release APK

To generate an optimized, signed release APK for Android:

```bash
flutter build apk --release
```

The compiled APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🛠️ Built With

* **[Flutter](https://flutter.dev)** — Cross-platform UI Toolkit
* **[Provider](https://pub.dev/packages/provider)** — State Management
* **[Sqflite](https://pub.dev/packages/sqflite)** — High-performance SQLite database
* **[FL Chart](https://pub.dev/packages/fl_chart)** — Beautiful analytics and productivity graphs
* **[Table Calendar](https://pub.dev/packages/table_calendar)** — Dynamic calendar view
* **[Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)** — System notifications & alarms
* **[Just Audio](https://pub.dev/packages/just_audio)** — Audio playback engine
* **[Speech To Text](https://pub.dev/packages/speech_to_text)** & **[Flutter TTS](https://pub.dev/packages/flutter_tts)** — Voice interactions

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Crafted with ❤️ by <a href="https://github.com/EmptyEch0">EmptyEch0</a></sub>
</div>
