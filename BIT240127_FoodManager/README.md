# BIT240127_FoodManager

Flutter + MockAPI + offline cache/queue, created for the FoodManager assignment.

## 1. Prepare VS Code / Flutter / Android

Install VS Code Flutter extension (installs Dart extension), Flutter SDK, Android Studio/Android SDK and emulator.
Check `flutter doctor`, `flutter doctor --android-licenses` and `flutter devices`.

## 2. Create Flutter shell from this source

Extract ZIP, open **BIT240127_FoodManager** folder in VS Code, then run:

```powershell
flutter create --project-name bit240127_foodmanager --platforms android .
flutter pub get
```

This creates platform-specific files (android/) absent from the ZIP. Keep the supplied `lib/`, `pubspec.yaml`, `scripts/` and `README.md`. The Android label can be customized later in `android/app/src/main/AndroidManifest.xml` with `android:label="BIT240127_FoodManager"`.

## 3. MockAPI

At https://mockapi.io create a new project. Its URL usually ends in `/api/v1`.

Create **two resources with these exact names**:
- `BIT240127_DishCategory`
- `BIT240127_Dish`

MockAPI will generate a built-in `id` for each record. Set these data columns (as supported by your MockAPI UI):

**BIT240127_DishCategory**
- `BIT240127_ClientUid` (String)
- `BIT240127_Name` (String)
- `BIT240127_Description` (String)

**BIT240127_Dish**
- `BIT240127_ClientUid` (String)
- `BIT240127_Name` (String)
- `BIT240127_Price` (Number)
- `BIT240127_PreparationTime` (Number)
- `BIT240127_IsAvailable` (Boolean)
- `BIT240127_Description` (String)
- `BIT240127_DishCategoryId` (String)
- `BIT240127_DishImage` (Array of nested image records, JSON)

Each entry in `BIT240127_DishImage`: `BIT240127_ImageUrl` (String), `BIT240127_IsThumbnail` (Boolean). The relation field references the category's **ClientUid**; this is a stable identifier usable offline. MockAPI's own `id` (without the prefix) is a system-managed identifier outside our control. If the MockAPI schema editor has no array/object field type, first confirm it preserves POSTed nested JSON; if it strips or stringifies it, use a suitable JSON-compatible field or adapt the schema before running the app.

Edit `lib/services/store.dart` and change `mockApiBaseUrl` to your project's base URL.

Seed sample data in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\seed_mockapi.ps1 -BaseUrl "https://YOUR_PROJECT_ID.mockapi.io/api/v1"
```

Seed can be run repeatedly: it skips rows with matching `BIT240127_ClientUid`.

## 4. Run

```powershell
flutter doctor
flutter devices
flutter run
```

Use an Android emulator with working internet or real Android device. The app has no dependency on XAMPP.

## 5. Offline sync architecture

- Local source: `shared_preferences` holds JSON snapshots of categories and dishes including flags `_dirty` and `_deleted`. The local persistence keys are prefixed `BIT240127_`.
- Every entity has a permanent, locally assigned `BIT240127_ClientUid`; the server also assigns built-in `id`. The category relationship uses ClientUid, not a fragile server-generated ID.
- Local save/change/delete writes to disk immediately and sets dirty. The UI updates without network.
- At startup, connectivity change and every 15 seconds, `Store.sync()` tries HTTP.
- Categories are sent before dishes. It searches existing remote records by ClientUid before POST, limiting accidental duplicate creation if the response of a previous POST was lost. Changes use PUT; deletions are queued as tombstones and send DELETE.
- After successful sync, fresh remote lists are merged with locally still-pending records, giving pending local records priority. The app is an educational **single-device / simple last-local-write** sync example, not a production-grade multi-client conflict resolution system.
- `connectivity_plus` signals network availability, not confirmed internet; real HTTP exceptions are caught and retried.
- Limitation: simultaneous writes during an active sync, remote changes of the same record on multiple devices, and records deleted by another device are not handled by transactional conflict resolution. For a production system use a database, revisioning and a server supporting idempotency keys/transactions.

## 6. How to demo

1. Show project title and English UI (default). Tap language icon to switch English/Vietnamese.
2. Add 3 categories and 5 dishes using seed or the UI.
3. Search partial name; combine category, available toggle, min/max price; sort by ascending/descending price or preparation time.
4. Tap a dish; view all images and Quick/Regular classification (<=15 min).
5. Edit a dish, add multiple image URLs, tap an image row to mark its thumbnail (at most one).
6. Turn off internet; edit/add a dish; verify it remains in UI; reconnect and wait around 15s; verify it exists in MockAPI.
7. Try deleting a non-empty category: blocked. Delete the dishes first, then delete the category.

## File guide

- `lib/models/models.dart`: entities, prefixed JSON serialization
- `lib/services/store.dart`: validation, local persistence, REST methods, offline sync
- `lib/screens/screens.dart`: screens, search/filter/sort, forms, photo management
- `lib/main.dart`: app initialization and theme
- `scripts/seed_mockapi.ps1`: starter data


flutter create --platforms=web .

mmockdata https://6ad71435f71f154ac487b5f0.mockapi.io/
powershell -ExecutionPolicy Bypass -File .\scripts\seed_mockapi.ps1 -BaseUrl "https://6ad71435f71f154ac487b5f0.mockapi.io"