# CAR PARKING SYSTEM
### JAY GANESH PAY & PARK
**Powered by BIZFLOW**

A modern, full-featured car and vehicle parking management system built with Flutter and Firebase, tailored for rapid entry/exit ticketing, live capacity tracking, multi-guard shift management, thermal receipt printing, automated handovers, and comprehensive financial reporting.

---

## 🚀 Key Features

- **Rapid Vehicle Entry & Exit:**
  - Automated ticket generation with QR codes.
  - Multi-vehicle category support (2-Wheeler, 4-Wheeler, etc.).
  - Real-time rate calculation with customized duration-based billing rules.
  - WhatsApp ticket sharing integration.

- **Active Parking & Capacity Tracking:**
  - Real-time live vehicle slots and capacity monitoring.
  - Over-capacity warnings and dynamic slot availability.

- **Monthly Pass Management:**
  - Issue, renew, and track monthly parking passes.
  - Automatic pass recognition on vehicle entry and exit.
  - Historical pass usage and vehicle logs.

- **Guard & Shift Management:**
  - Guard login device binding and session token security.
  - Active shift requirements and live shift timer.
  - Mandatory cash/UPI handover reconciliation between shifts.
  - "Keep With Me" float tracking and admin cash/UPI withdrawal workflows.

- **Thermal Printing Support:**
  - Bluetooth and ESC/POS thermal receipt printing for vehicle tickets, receipts, and shift handover summaries.

- **Financial Analytics & Reporting:**
  - Admin Reports Hub with date-range filters (Today, Last 7 Days, Last 15 Days, Last 30 Days, Custom).
  - Cash vs. UPI revenue breakdown and guard-wise collection metrics.
  - Real-time synchronization via Cloud Firestore.

- **Multi-language Support:**
  - English and Marathi localized interfaces.

---

## 🛠️ Technology Stack

- **Frontend / Mobile / Web:** Flutter (Dart)
- **Database & Backend:** Firebase Cloud Firestore
- **Authentication:** Firebase Authentication
- **Media & Storage:** Firebase Storage / Cloudinary
- **Hardware Integration:** ESC/POS & Bluetooth Thermal Printing
- **Platform Targets:** Android APK / Web / Desktop

---

## 📂 Project Structure

```
lib/
├── core/            # Theme, constants, localization, routing, utilities
├── models/          # Data models (VehicleEntry, Shift, Guard, Payment, Pass)
├── providers/       # State management & reactive streams
├── screens/
│   ├── admin/       # Admin Dashboard, Guards, Shifts, Payments, Reports, Passes, Settings
│   ├── guard/       # Guard Dashboard, Vehicle Entry/Exit, Active Parking, My Shift, Handover
│   └── auth/        # Login, device binding & session validation
├── services/        # Firebase, thermal printer, WhatsApp, receipt generators
└── widgets/         # Reusable UI components, dialogs, summaries
```

---

## 📄 License & Ownership
Copyright © 2026 Jay Ganesh Pay & Park | BIZFLOW. All rights reserved.
