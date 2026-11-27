# FMMF — Personal Finance Manager & Super Advisor

**FMMF** is a modern, privacy-focused, cross-platform personal finance manager built with **Flutter**. Designed primarily for the web, it natively compiles to standalone **Android** and **iOS** applications.

---

## 🌟 Core Features & Pillars

### 1. 🛡️ Safe-to-Spend Balance
Unlike traditional apps that display gross bank balances, FMMF calculates your **true available money**:
$$\text{Safe-to-Spend} = \text{Liquid Cash} - (\text{Upcoming Debt Balances} + \text{Pending Monthly Commitments} + \text{Safety Reserve})$$

### 2. ⚡ Ultra-fast Natural Data Entry
Log any movement in under 3 seconds using natural shorthand or quick-tap chips:
- `250 Tacos Nu` *(logs $250 MXN expense, categorizes as Food, assigns to Nu)*
- `18500 Sueldo BBVA` *(logs $18,500 MXN income, categorizes as Salary, assigns to BBVA)*
- `60 Cafe Efectivo` *(logs $60 MXN expense, assigns to Cash)*
- Guided manual modal with category chips (🍔 Comida, 🚗 Transporte, 🛒 Súper, etc.).

### 3. 📈 Passive Yield & Compound Growth Tracker
Answers the vital question: **"Is my money generating anything on its own?"**
- Tracks daily and monthly passive returns across yield accounts (Nu Cajitas, Cetesdirecto, Mercado Pago, etc.).
- **Lazy Money Detector:** Alerts you when idle cash in 0% checking accounts exceeds your monthly operational expenses and calculates your missed yield opportunity.

### 4. 💳 Account & Credit Card Matrix (MXN First)
- Pre-configured for Mexican financial institutions: Nu México, BBVA, Cetesdirecto, Banorte, Cash, etc.
- Dedicated credit card tracking with **Cutoff Days (*Día de Corte*)** and **Payment Due Days (*Día Límite de Pago*)**.

### 5. 🤖 Super Finance Advisor
- Real-time **Financial Health Score (0–100)**.
- **Runway Calculator:** Computes how many months you can sustain your current lifestyle if active income stopped today.
- Proactive insights for cutoff warnings, yield milestones, and savings rate optimization.

---

## 📁 Architecture Overview

```
lib/
├── main.dart                       # App entrypoint & theme initialization
├── core/
│   ├── theme/app_theme.dart        # Deep fintech dark theme (#0A0E17 palette)
│   └── utils/currency_format.dart  # Mexican Pesos ($ MXN) and percentage formatters
├── models/
│   ├── account.dart                # Checking, Yield Vault, Investment, Credit Card, Cash
│   ├── transaction.dart            # Incomes, Expenses, Transfers, Yield Accruals
│   ├── budget_commitment.dart      # Fixed monthly bills (Rent, Subscriptions, Gym)
│   └── financial_insight.dart      # Advisor alerts and opportunity metrics
├── services/
│   ├── auth_service.dart           # Firebase Authentication (Email/Password & Google Sign-In)
│   ├── firestore_service.dart      # User-scoped Cloud Firestore persistence (users/{uid})
│   ├── storage_service.dart        # Local SharedPreferences cache + awaited Firestore sync
│   └── advisor_engine.dart         # Calculation engine for Safe-to-Spend, 12M forecast & insights
├── providers/
│   └── finance_provider.dart       # Central state management & smart natural parser
└── screens/
    ├── auth_screen.dart            # Email/Password & Google Sign-In screen
    ├── home_screen.dart            # Bottom bar navigation, live sync status & quick action
    ├── dashboard_tab.dart          # Hero Safe-to-Spend & monthly cashflow breakdown
    ├── transactions_tab.dart       # Searchable & filterable movement ledger
    ├── accounts_tab.dart           # Balance breakdown, account purpose, limits & cutoffs
    ├── plan_tab.dart               # Income schedule, savings rules, fixed bills & 12M forecast
    ├── settings_tab.dart           # Account session, JSON backup/restore & Danger Zone
    └── widgets/
        ├── confirm_delete_dialog.dart
        ├── expandable_breakdown_row.dart
        ├── quick_entry_sheet.dart  # Smart one-line natural text parser & modal
        └── safe_to_spend_card.dart # Flagship financial health hero card
```

---

## 🚀 Running the App

### Web (Local development)
```bash
flutter run -d chrome
```

### Build for Production Web
```bash
flutter build web --release
```

### Android APK / Bundle
```bash
flutter build apk --release
# or app bundle:
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa
```

---

## 📋 Notas de la Versión (Changelog)

### v3.0.0+4
- **Prioridad de Metas del Excedente (`Ajustes → Prioridad de Metas`):** Configura el orden de tus metas para tu dinero libre (*Fondo de Emergencia*, *Invertir y Crecer*, *Abono Extra a Tarjetas* opcional) y activa o desactiva el Fondo de Emergencia sin asumir pagos extra a tarjetas por defecto.
- **Categorías Inteligentes (Gasto / Ingreso / Ambos + Palabras Clave):** Las categorías ahora pueden usarse en Gastos, Ingresos o Ambos, permiten configurar palabras clave editables en `Ajustes → Categorías de Movimientos`, y aprenden automáticamente al 3er uso para preseleccionar la categoría mientras escribes.
- **Cuentas Flexibles (`Vales / Beneficios`, `Fondo de Ahorro` y Reglas Avanzadas):** Configura en cualquier cuenta si se incluye en tus finanzas generales (`Margen Libre`), qué categorías de gasto cubre (ej. `Supermercado` con sugerencias en Resumen), restricciones de comercio (ej. `Solo Chedraui`), fecha de liberación y multiplicador de aportaciones (ej. `2×` con registro de aportaciones de nómina y liberación a cuenta bancaria).
- **Tarjetas de Crédito y UX:** Corrección de orden cronológico descendente en movimientos de tarjeta (cargos de hoy arriba y mensualidades futuras abajo), desglose claro del balance neto por banco y eliminación de desbordamientos visuales en pantallas compactas.

### v1.1.0+2
- **Sincronización en la nube con Firebase:** Inicio de sesión con correo/contraseña y Google, respaldo automático en Cloud Firestore aislado por usuario y migración automática de datos locales.
- **Indicador de sincronización en vivo:** Estado en barra superior y pestaña de Ajustes con opción de reintento inmediato.
- **Nueva pestaña de Ajustes:** Gestión de sesión, asistente de configuración, exportación/importación JSON y **Zona de Peligro** protegida con confirmación escrita (`BORRAR`) para evitar borrados accidentales.
- **Confirmaciones en acciones destructivas:** Diálogos de confirmación al eliminar movimientos, cuentas, gastos fijos, ingresos recurrentes, reglas de ahorro y planes MSI/MCI.
- **Proyección a 12 meses y pagos domiciliados:** Planeación mensual con desglose expandible, propósito de cuentas de ahorro y sugerencias inteligentes para cubrir el mes.
