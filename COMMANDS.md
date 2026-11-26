# COMMANDS.md — FMMF Quick-Reference Cheat Sheet

Practical command and workflow reference for **FMMF** (`Flutter 3.24.5` / `Dart 3.5.4`).

---

## 1. Local Development & Preview

| Action | Command / Shortcut | Notes |
| :--- | :--- | :--- |
| **Run Web App (Persistent Data)** | `flutter run -d web-server --web-port=8080` | Open `http://localhost:8080` in your regular browser so `localStorage` persists day to day |
| **Run Web App (Ephemeral Dev)** | `flutter run -d chrome` | Launches a temporary Chrome profile on a random port (does **not** persist `localStorage` across runs) |
| **Hot Reload** | Press `r` | In the active `flutter run` terminal |
| **Hot Restart** | Press `R` | Resets app state & picks up structural changes |
| **Quit Dev Server** | Press `q` | Stops `flutter run` |
| **Build Web (Production)** | `flutter build web --release` | Outputs static bundle to `build/web/` |
| **Preview Built Web App** | `python3 -m http.server 8080 -d build/web` | Serves `build/web` at `http://localhost:8080` |
| **Build Android APK** | `flutter build apk --release` | Requires JDK 17 + Android SDK |

---

## 2. Release Workflows

> **Current Status:** GitHub remote (`Diegomerck/fmmf`) and Firebase (`fmmf-finance`: Hosting, Auth, Firestore) are active.

### `PUSH TO LIVE` (Public Release)
1. Bump `version:` in `pubspec.yaml`.
2. Update end-user changelog/release notes (Spanish) & `README.md`.
3. Verify code & build:
   ```bash
   flutter analyze && flutter build web --release
   ```
4. Commit & push to GitHub *(once initialized)*:
   ```bash
   git add -A && git commit -m "Release vX.Y.Z" && git push
   ```
5. Deploy to Firebase Hosting *(once initialized)*:
   ```bash
   firebase deploy --only hosting
   ```

### `PUSH DISCRETE` (Silent / Maintenance Release)
1. Skip user-facing changelogs and update badges/notifications.
2. Update internal docs if needed.
3. Verify & build:
   ```bash
   flutter analyze && flutter build web --release
   ```
4. Commit, push to GitHub, and deploy (`firebase deploy --only hosting`) *(once initialized)*.

---

## 3. Code Quality & Checks

| Check | Command |
| :--- | :--- |
| **Static Analysis / Linter** | `flutter analyze` |
| **Run Unit/Widget Tests** | `flutter test` |
| **Check Outdated Packages** | `flutter pub outdated` |
| **Clean & Refresh Dependencies** | `flutter clean && flutter pub get` |

---

## 4. CLI Auth & Environment

- **Toolchain Paths:**
  - `flutter` / `dart` / `firebase`: `/Users/diego/development/flutter/bin`
  - Homebrew: `/usr/local/Homebrew/bin/brew`
- **Environment & Auth Checks:**
  ```bash
  flutter doctor -v
  firebase --version
  firebase login          # Authenticate Firebase CLI
  firebase projects:list  # Verify accessible Firebase projects
  firebase logout         # Sign out if switching accounts
  ```
- **Note for Android Builds on macOS 12:** Install JDK 17 via binary cask (`brew install --cask temurin@17`) rather than building `openjdk@17` from source.

---

## 5. Workflow Triggers Table

| Trigger | Mode / Behavior |
| :--- | :--- |
| *(Default — no keyword)* | **Planning Mode**: Read-only analysis, root cause, edge cases, and plan proposal. |
| `IMPLEMENTATION` | **Implementation Mode**: Executes the approved plan, runs `flutter analyze`, reports results, and auto-returns to Planning Mode. |
| `QUICK FIX` | Direct 1-line / typo fix + `flutter analyze`, then returns to Planning Mode. |
| `PUSH TO LIVE` | Full public release: version bump, user-facing notes, docs, build, Git push, and deploy. |
| `PUSH DISCRETE` | Silent maintenance release: no user-facing notes/alerts, build, Git push, and deploy. |

---

## 6. Recommended Slash Commands & Session Tips

- **`/plan`** — Structure a multi-step feature or refactor before switching to `IMPLEMENTATION`.
- **`/compact`** — Summarize long conversation history to free up context window without losing key decisions.
- **`/goal`** — Use for larger, end-to-end tasks that require thorough multi-step verification.
- **Conversation Naming Tips:** Name sessions by feature or area (e.g., `FMMF: Annual Pay Schedule Sync`, `FMMF: Firebase Auth & Firestore Setup`) so transcripts stay easy to find.

