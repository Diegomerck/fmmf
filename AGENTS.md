# AGENTS.md — FMMF Operating Workflow & Engineering Standards

This file defines the operating model, code quality rules, release protocols, and communication standards for AI agents working on **FMMF** (`fmmf`).

---

## 1. Project Identity & Stack

- **App Name:** FMMF (Personal Finance Manager & Super Advisor)
- **Framework:** Flutter `3.24.x` / Dart `^3.5.4` (`pubspec.yaml`: `name: fmmf`)
- **Target Platforms:** Web-first (`web`), with standalone `android` and `ios` support
- **Primary Currency & Locale:** Mexican Pesos (`$ MXN`, `es_MX`)
- **Current Persistence:** Local-first via `shared_preferences` (`lib/services/storage_service.dart`), structured for future Firebase Auth + Cloud Firestore integration
- **Git & Hosting Status:** Local workspace only for now; GitHub remote and Firebase Hosting will be configured once the core app workflow is finalized

---

## 2. Single-Agent Two-Phase Cycle

### Phase 1: Planning Mode (Default)
- **Always default to Planning Mode** for any bug report, question, feedback, or feature request.
- **Strictly read-only on executable application code** (`lib/`, `test/`, `android/`, `ios/`, `web/`, `pubspec.yaml`).
- Inspect relevant files, trace root causes, evaluate edge cases (especially bidirectional state sync and financial math), propose a clear architectural plan, and **wait for explicit user approval**.

### Phase 2: Implementation Mode
- Activated **ONLY** when the user explicitly types **`IMPLEMENTATION`** (or explicitly instructs you to proceed with implementation).
- Execute the approved plan completely.
- Run static analysis (`flutter analyze`), tests (`flutter test` when present), and verify the production web build (`flutter build web --release`) when structural or release-impacting changes are made.
- Report the exact results clearly.
- **Automatic Return to Planning:** Immediately after finishing an implementation and reporting results, automatically exit Implementation Mode and return to **Planning Mode** for all subsequent turns.

> **Exception (`QUICK FIX`):** When the user explicitly uses `QUICK FIX` for a tiny 1-line edit or typo, apply the fix directly, run `flutter analyze`, report the result, and return to Planning Mode.

---

## 3. Strict Code Modification & Quality Standards

1. **Complete, Production-Ready Code:** Never truncate code, omit sections with `// ...`, or leave placeholder stubs.
2. **Dependency Discipline:** Never add, remove, or alter package/dependency versions in `pubspec.yaml` or `pubspec.lock` without explicit user instruction.
3. **Deterministic Financial Logic:**
   - Keep calculations in `AdvisorEngine` (`lib/services/advisor_engine.dart`) and `FinanceProvider` (`lib/providers/finance_provider.dart`) deterministic, transparent, and free of invented/hardcoded fallback amounts.
   - Maintain strict **single-source-of-truth** synchronization across linked entities:
     - `ScheduledPayOccurrence` (Calendario) ↔ `Transaction` (Movimientos) ↔ `Account.balance` (Cuentas) ↔ `PendingTransfer` / `Ahorro` transfers ↔ `AdvisorAnalysis` (Resumen / Asesor).
   - Never execute future-dated deposits or silent savings transfers without user confirmation.
4. **User Data Isolation (When Auth/DB Is Added):** Scope all Cloud Firestore reads, writes, and security rules strictly to the authenticated user (`request.auth.uid == userId`).
5. **Git Discipline (Once Initialized):** Use concise, imperative commit messages (e.g., `Add recurring income annual schedule`).

---

## 4. Release & Deployment Protocol

> *Note: GitHub push and Firebase Hosting deploy steps apply once the repository remote and Firebase project are initialized.*

### `PUSH TO LIVE` (Public Release)
1. Bump `kAppVersion` in `lib/main.dart` and `version` in `pubspec.yaml` following the FMMF versioning scheme (starting from `2.10.1`):
   - **Small change / bug fix:** increment patch (`2.10.1` → `2.10.2`).
   - **New feature / significant change:** increment minor and reset patch (`2.10.x` → `2.11.0`).
   - **Major app overhaul:** increment major only when explicitly instructed by the user (`2.x.x` → `3.0.0`).
2. Update user-facing changelog / release notes in **Spanish** (if applicable in the app/docs).
3. Update internal documentation (`README.md`).
4. Run `flutter analyze` and `flutter test` (if tests exist) and confirm zero errors.
5. Run `flutter build web --release`.
6. Stage, commit, and push changes to GitHub (`git add -A && git commit -m "..." && git push`).
7. Deploy `build/web` to hosting (`firebase deploy --only hosting`).

### `PUSH DISCRETE` (Silent / Maintenance Release)
1. Do **NOT** update user-facing changelogs or trigger in-app update notifications/badges.
2. Update internal version/docs only if needed.
3. Run `flutter analyze` and `flutter build web --release`.
4. Stage, commit, and push changes to GitHub.
5. Deploy `build/web` to hosting (`firebase deploy --only hosting`).

---

## 5. Language & Communication Protocol

- **Agent Communication:** Conduct **all** analysis, planning, questions, status reports, and reasoning strictly in **English**.
- **App & End-User Copy:** Reserve **Spanish (`es_MX`)** exclusively for FMMF UI labels, categories, advisor messages, user-facing error/snackbar messages, and end-user changelogs.

