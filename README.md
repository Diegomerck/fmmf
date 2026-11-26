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
│   ├── storage_service.dart        # Local persistence & seed data (ready for Firebase)
│   └── advisor_engine.dart         # Calculation engine for Safe-to-Spend, Yields & Insights
├── providers/
│   └── finance_provider.dart       # Central state management & smart natural parser
└── screens/
    ├── home_screen.dart            # Bottom bar navigation & quick action triggers
    ├── dashboard_tab.dart          # Hero Safe-to-Spend & financial overview
    ├── transactions_tab.dart       # Searchable & filterable movement ledger
    ├── yields_tab.dart             # Passive earnings & Lazy Money detector
    ├── accounts_tab.dart           # Balance breakdown, debt limits, and cutoff dates
    ├── advisor_tab.dart            # Super Advisor diagnostic & health metrics
    └── widgets/
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
