# TripWit

## What is this?
iOS travel planner app built with Swift/SwiftUI. Plan trips, track your itinerary on the go, and automatically match photos from your camera roll to trip stops using GPS metadata.

## Architecture
- **TripCore** (`Packages/TripCore/`) — Pure Swift package with all business logic, models, and services. No UI dependencies. Tests run fast with `swift test`.
- **TripWit** — SwiftUI iOS app target that depends on TripCore.
- **TripWitTests** — App-level unit tests.

## Validation Loop
After every code change, run:
```bash
./Scripts/validate.sh
```
This runs 4 steps:
1. TripCore package build
2. TripCore tests (fast, no simulator)
3. Full app build (xcodebuild, needs simulator)
4. App tests (xcodebuild test)

For fast iteration on business logic only:
```bash
./Scripts/test-logic.sh
```

## Key Commands
```bash
# Fast: logic tests only (no simulator)
cd Packages/TripCore && swift test

# Full app build
xcodebuild build -scheme TripWit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Full app tests
xcodebuild test -scheme TripWit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TripWitTests -quiet

# Regenerate Xcode project after changing project.yml
xcodegen generate
```

## Project Structure
```
Packages/TripCore/          ← Pure logic package (models, services, tests)
TripWit/                     ← SwiftUI app (views, view models, platform services)
TripWitTests/                ← App-level tests
Scripts/                    ← Validation scripts
project.yml                 ← XcodeGen project spec
```

## Rules
- Keep business logic in TripCore, not in the app target
- Every new service or model gets tests in TripCore
- Run validate.sh after every change before considering work done
- Use `public` access control on TripCore types that the app needs
- iOS 17+ minimum deployment target
- Swift 6 strict concurrency
- **Never upload to TestFlight unless explicitly asked**

## File Format Rules (.tripwit)
- `.tripwit` files (JSON via `TripTransfer`) must always be **forwards compatible**
- Never remove fields from `TripTransfer` structs — only add new optional fields with defaults
- New fields must have defaults so old files still decode correctly (`var foo: String = ""`)
- Bump `TripTransfer.currentSchemaVersion` when making structural changes
- Date encoding is `iso8601` — do not change

## Data Safety Rules
- **Never destroy or migrate away existing Core Data stores** — users' trips live in `Private.sqlite` and `Shared.sqlite` in Application Support
- Do not change the `NSPersistentCloudKitContainer(name:)` value — it determines the store filename; changing it orphans existing data
- Do not change the CloudKit container identifier (`iCloud.com.kevinbuckley.travelplanner`) — it is linked to the App Store app
- Any Core Data model changes must be additive (new optional attributes only) — no renames, no deletes, no type changes
- If a migration is ever needed, use lightweight migration and test it explicitly before shipping

## Deployment
- **Archive:** `xcodebuild -project TripWit.xcodeproj -scheme TripWit -configuration Release -destination 'generic/platform=iOS' -archivePath build/TripWit.xcarchive archive`
- **TestFlight upload:** `xcodebuild -exportArchive -archivePath build/TripWit.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/TripWitExport`
- **Device deploy (no TestFlight):** `xcodebuild -destination 'platform=iOS,id=<UDID>'` — find UDID with `xcrun xctrace list devices`
- Build number lives in `project.yml` → `CURRENT_PROJECT_VERSION` — increment for every TestFlight upload

## App Icon
- Single 1024×1024 PNG at `TripWit/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- No rounded corners, no transparency — iOS applies rounding automatically

## iMessage / CloudKit Sharing
- **Do not use UICloudSharingController for new shares** — documented iOS spinner bug in Messages
- New shares: pre-create `CKShare` via `container.share([trip], to: nil)`, wrap URL as `tripwit://share?url=<encoded>`, send via `MFMessageComposeViewController` directly
- Existing shares: `UICloudSharingController` is fine for participant management only
- CKError 10/2007 "Permission Failure": Developer Portal → App ID → iCloud → uncheck/re-check container → save → regenerate provisioning profiles in Xcode
