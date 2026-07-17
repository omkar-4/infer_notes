# 📓 Infer Notes

Infer Notes is a simple, fast, and robust note-taking application designed to keep your thoughts safe and organized directly on your local file system. 

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Installation & Usage](#installation--usage)
4. [Technical Architecture](#technical-architecture)

## Overview
Infer Notes operates as a direct interface to your local files. By selecting any folder on your computer to act as a vault, the application seamlessly reads, writes, and organizes your markdown and text files without requiring proprietary databases or cloud synchronization.

## Features
* **Local First**: Your notes stay on your machine. Pick any directory to serve as your vault.
* **Temp Scratchpad**: Switch to a visual scratchpad mode to draw and brainstorm freely.
* **Atomic Autosave 🛡️**: A background saving engine protects your work. Changes are written to a temporary hidden folder and only overwrite your original file upon successful disk write. An indicator `●` tracks unsaved changes.
* **Dark Mode**: Switch between light and dark themes seamlessly.
* **Native Integration**: Custom title bars and file system listeners provide a native desktop experience.

## Installation & Usage
To run Infer Notes from source, ensure you have the Flutter SDK installed and configured for desktop development.

1. Clone this repository to your local machine.
2. Navigate to the project directory.
3. Run `flutter pub get` to fetch all required dependencies.
4. Run `flutter run -d windows` (or `macos` / `linux`) to launch the application.

## Technical Architecture
The application is built using Dart and the Flutter framework, targeting desktop platforms.

### Core Libraries
* `window_manager`: Handles native window lifecycle events and custom title bars.
* `file_picker`: Manages native dialogs for vault selection.
* `http`: Facilitates network requests for the auto-updater system.

### Internals
* **File System Tree**: Implements recursive directory parsing with an expandable sidebar.
* **Atomic Saving Engine**: Orchestrates crash-resilient file I/O operations.
* **Auto-updater System**: Background polling engine for checking and applying the latest releases.
