# Tea Shop Manager

A Flutter app for running the money side of a tea shop from one place:
account balance, daily sales, expenses, profit and simple reports. All data is
stored **on the device** (Hive) — it works fully offline.

## Features

| Area | What it does |
| --- | --- |
| **Calc** (centre button) | Opening screen. A 4‑function calculator; press `=` and the key turns into a green tick — tap it to drop the result straight into your account (a quick sheet: Income/Expense + optional note, no category prompt). Reached from the raised button in the middle of the bottom bar. |
| **Home** | Live account balance, today's sales/spend, this month's income / expense / profit, quick add buttons, recent entries. Settings opens from the gear in the header. |
| **Entries** | Every income & expense, grouped by day, with search and filters by type / month; `+` opens the same fast add sheet; tap a row to edit (full form with category, payment method, date) |
| **Menu** | Your tea / snack items with price, cost and margin %. "Sell" records an income entry in one tap (quantity + payment method) |
| **Reports** | Month picker, 6‑month income‑vs‑expense bar chart, expense pie chart, category breakdowns with bars, and a copyable text summary |
| **Settings** | Shop name, currency symbol, opening balance, light/dark theme, category manager, all‑time totals, reset data |

## Money model

- **Balance** = opening balance + all income − all expense
- **Profit** (period) = income − expense for that period
- **Margin** (menu item) = price − cost

## Project layout

```
lib/
  main.dart            app bootstrap (Hive + provider)
  app.dart             MaterialApp + theme wiring
  models/              Category, Product, Txn, enums (plain map <-> object)
  data/data_store.dart Hive persistence + first-run seed data
  state/app_state.dart single ChangeNotifier: lists, derived figures, CRUD
  theme/               Material 3 tea-green theme (light + dark)
  utils/               currency & date formatting, icon + colour maps
  utils/calc_engine.dart  pure calculator logic (unit tested)
  widgets/             QuickEntrySheet (fast add), AmountText, StatTile, ...
  screens/             home shell + Dashboard / Transactions / Products /
                       Reports / Settings / Categories + add/edit screens
```

## Run it

```bash
flutter pub get
flutter run                 # pick a connected device / emulator
```

Platform builds:

```bash
flutter build apk           # Android (needs Android SDK + accepted licenses)
flutter build windows       # Windows (needs Visual Studio + "Desktop C++")
flutter build web            # Web (already configured)
```

## Tests

```bash
flutter test
```

`test/app_state_test.dart` covers seeding, balance/profit maths, quick sale and
persistence across app restarts. `test/widget_test.dart` covers the model
serialisation and enums.
