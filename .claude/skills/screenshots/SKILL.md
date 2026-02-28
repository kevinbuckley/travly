---
name: screenshots
description: Generate polished App Store screenshots for TripWit. Captures simulator screenshots and composites them into App Store-ready PNGs with device frames, gradients, and marketing text at exact pixel dimensions.
argument-hint: [--skip-build | --render-only]
allowed-tools: Bash, Read, Write, Glob
---

# App Store Screenshot Generator

Generate polished, pixel-perfect App Store screenshots automatically — no human intervention needed.

## What It Does

1. Boots the iOS Simulator (iPhone 17 Pro)
2. Builds and installs TripWit
3. Launches the app to each key screen using `-screenshotTab` launch arguments
4. Captures raw simulator screenshots via `xcrun simctl io`
5. Renders each into a polished App Store image (1284×2778px) using HTML/CSS templates + Puppeteer
6. Outputs final PNGs to `Screenshots/AppStore/`

## How to Run

```bash
cd Screenshots/tools && node render.js $ARGUMENTS
```

## Flags

- `--skip-build` — skip xcodebuild, use already-installed app (faster iteration)
- `--render-only` — skip simulator entirely, just re-render existing raw screenshots into App Store images (useful for tweaking templates)

## Screenshots Generated

| File | Screen | Headline |
|------|--------|----------|
| 01_trips.png | Trip list | "Plan Every Detail" |
| 02_map.png | Map view | "See Your Route Unfold" |
| 03_wishlist.png | Wishlist | "Save Your Dream Spots" |
| 04_tripdetail.png | Trip detail | "All Bookings, One Tap" |

## Output

All final images saved to `Screenshots/AppStore/` at exactly 1284×2778 pixels (App Store 6.5" display format).

## Customizing

- **Templates:** `Screenshots/tools/templates/base.html` — HTML/CSS template with mustache-style placeholders
- **Screenshot definitions:** `Screenshots/tools/render.js` — `SCREENSHOTS` array defines each screen's tab, headline, colors, rotation
- **To add a new screenshot:** Add an entry to the `SCREENSHOTS` array in render.js

## After Running

Verify the output images look correct. Open them with:
```bash
open Screenshots/AppStore/
```
