# SpotGo Parking Admin (Flutter)

Multiplatform mobile app for **Parking Admin** operators of SpotGo. It lets an
administrator provisioned by SuperAdmin monitor live occupancy, review and
resolve operational alerts, manage parking zones and register guest parking
sessions with exit and physical payment.

This branch delivers about **50% of the Parking Admin module**.

## Implemented screens

| # | Screen | Main behaviour | User stories |
|---|--------|----------------|--------------|
| – | Sign in | Provisioned Parking Admin accounts only, validation, errors, no public sign up | US09 |
| 15 | Administrator dashboard | Occupancy, availability, open alerts, guest sessions, reservations, balances, zone and sensor status, recent alerts | US07 |
| 16 | Live occupancy map | Spots grouped by zone, filters (All / Available / Issues, zone, search), spot detail with separate occupancy, reservation and sensor states, periodic refresh | US05, US07 |
| 17 | Operational alerts | List with filters (All / Critical / Sensor / Payment / Resolved) | US06 |
| 33 | Alert detail | Classification, action taken, monitoring or resolution, history | US06 |
| 19 | Parking zones | Facility summary and zones with hours, rates and free spots | US02 |
| 20 | Create / edit parking zone | Validated form, operating hours, rate, billing fraction, status, spot types, spot assignment with conflict detection | US02 |
| 21 | Guest parking sessions | Active / Completed / Issues | US03 |
| 22 | New guest session | Plate, vehicle, available spot only, expected duration | US03 |
| 23 | Guest session details | Exit registration, amount by billing fraction, cash or external POS confirmation, closing | US03 |

Also included: bottom navigation (Dashboard, Occupancy, Alerts, More), account
sheet with sign out and an audit history of administrative changes.

## Business rules applied

- Parking Admin accounts are enabled by SuperAdmin; the app has no registration.
- Occupancy (sensor), reservation and sensor health are independent states.
  A spot with an unreliable sensor is shown as Unavailable and blocks guest
  sessions.
- A guest session needs an Available spot in an active zone, a valid plate and
  creates no Driver account, vehicle, reservation or digital payment.
- Closing a guest session requires the exit first and then the confirmation of
  a physical payment (cash or external POS). Card data is never requested.
- Amounts are charged by the zone billing fraction; overstay is flagged after
  a 5-minute tolerance.
- An alert is resolved only with a classification, the action taken and the
  action marked as completed; its history is kept.
- A high occupancy alert is raised when occupancy exceeds 95% of the
  operational spots.
- A spot can belong to only one zone; conflicting assignments are rejected.
  Each zone stores its allowed spot types and authorized Driver profiles
  (sample categories until the Profiles service is integrated).
- Occupancy percentages use physical sensor readings only; reservations and
  guest sessions block availability but are not counted as presence.

## Architecture

```
lib/
  app/        App root, dependency scope, navigation helper
  core/       Theme, shared widgets, formatters
  data/       Models, repository contracts, mock implementations
  domain/     Pure business rules
  features/   auth, shell, dashboard, occupancy, alerts, zones, guests
  state/      AuthController and AdminController (ChangeNotifier)
test/         Unit tests for rules and widget tests for the main flows
```

State is handled with `ChangeNotifier` controllers exposed through
`InheritedWidget` scopes, so no extra packages are required.

## Data sources

The documented SpotGo backend (`https://spotgo-backend.onrender.com`) did not
answer its OpenAPI or Swagger endpoints (HTTP 404) during development, so no
endpoint was assumed. The app uses `AuthRepository` and `ParkingRepository`
contracts with **local mock implementations** (`lib/data/mock`) that hold sample
data in memory and apply the same business rules. A REST implementation can
replace them in `SpotGoAdminApp` without changing the screens.

Demo account (sample data only): `admin@spotgo.pe` / `SpotGo2026!`.

## Running

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk
```

## Pending for the complete module

- Occupancy reports (18), parking infrastructure, digital map and floor plan
  upload (24, 25, 36), zone assignments and driver profiles (31), zone
  occupancy detail (32), B2B billing (26, 41).
- REST integration with the SpotGo backend, Google sign in and persistent
  session ("keep me signed in").
- Real-time sensor events (MQTT/HTTP) and push notifications.
