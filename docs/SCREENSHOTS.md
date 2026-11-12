# Screenshot provenance

The desktop runtime set contains **27 PNG captures of the implemented Godot game**, nine views in each viewport profile. Four separate native Android emulator captures are documented below. They were rendered from the source project by the installed Godot 4.5.1 desktop executable using the Compatibility renderer. These are **desktop runtime captures, not Android APK screenshots, emulator screenshots or physical-device screenshots**. No Windows export was created for this capture workflow.

| Folder under `marketing/screenshots/` | Pixel dimensions | Views |
|---|---:|---:|
| `phone/` | 1080 × 1920 | 9 |
| `tablet7/` | 800 × 1280 | 9 |
| `tablet10/` | 1200 × 1920 | 9 |

“Phone,” “7-inch” and “10-inch” are viewport-profile labels. They do not establish physical screen size, DPI, device performance, touch behavior or Android safe-area behavior.

The 27 desktop PNGs preserve runtime revision `1305a04a3d3a45bcc8ca865ae3428f82adb31f94`. They were not regenerated for `7b001133ef71903209ec713c1dd3e4218334d329`, whose only runtime change refreshes the tug and HUD after an earned revive while play remains paused. The separate native captures below use that later revision.

## Capture method and scene setup

[tests/capture.gd](../tests/capture.gd) instantiates the real main scene with `qa_mode=true`. It uses a fresh in-memory profile, avoids the ordinary player save, and disables automatic app processing while staging each view. The script captures the rendered viewport texture after a completed render frame and saves it directly as PNG. Transient toast messages are hidden before capture. The raw PNGs are not resized, composited with marketing artwork, retouched or overlaid with invented UI.

[tools/capture_profiles.ps1](../tools/capture_profiles.ps1) runs each view at its explicit profile size with isolated process-local app data. Runtime logs and process receipts are kept under ignored `build/captures/`. Its latest manifest can describe only the most recent subset; the hashes below cover the complete delivered set.

| Filename in each profile | Implemented view and setup |
|---|---|
| `01-home.png` | Fresh-profile harbor home. All three captures were refreshed after fixing overlapping dock labels in the presentation camera. |
| `02-rescue.png` | Contract 01. The driver steps the actual tow model at 1/30 second using its steering policy until three boats are in tow, then renders that state. This is scripted model simulation, not human play. |
| `03-contracts.png` | Fresh-profile campaign list, with later contracts locked and unearned star icons. |
| `04-result.png` | The actual model is driven to completion of Contract 01, then the game runs its result/progression flow. The displayed score, stars, coins and XP come from that flow. This does not independently prove disk persistence. |
| `05-shipyard.png` | Shipyard opened after the simulated completed contract. Available and unaffordable upgrades reflect that test profile; no upgrade purchase is staged. |
| `06-journal.png` | Journal opened after the simulated completed contract, showing local records and achievements earned by that simulation. |
| `07-daily.png` | Fresh-profile daily dock on the app-reported date, 2026-11-12, with an unclaimed welcome gift and daily goals. |
| `08-lantern.png` | Contract 24, The Quiet Channel, selected directly by the QA fixture to show Lantern Strait. This bypasses normal campaign unlock progression and does not prove an earned unlock. |
| `09-copperdock.png` | Contract 16, Busy Water, selected directly by the QA fixture to show Copperdock and crossing ferries. This likewise does not claim an earned unlock. |

The capture mode suppresses native service submissions and banner display. These pictures do not demonstrate native ad presentation, native banner insets, sign-in, network behavior or Play Games overlays. Separate Android/emulator and Web acceptance belongs in [ACCEPTANCE.md](ACCEPTANCE.md), with final source/build identities in [build-evidence.json](build-evidence.json). Physical-device testing remains separate.

Generated icon, splash, feature and achievement illustrations are stored separately in `marketing/` and `assets/brand/`. They are never described as gameplay screenshots.

## Visual verification

All 27 PNG dimensions were checked against the profile table. All nine phone and 10-inch views were inspected visually, the eight remaining 7-inch views were inspected at full resolution, and all three refreshed home views were rechecked. The previous home dock-label overlap is resolved. No unintended UI clipping or text overlap was observed in the final set. Partially visible final rows in campaign and journal views are inside visibly scrollable containers.

These are visual layout checks, not certification of physical touch targets, accessibility, every-device legibility, animation timing, audio, human difficulty or production-service behavior.

To regenerate a separate comparison set without overwriting the approved PNGs, run from the project root:

```powershell
.\tools\capture_profiles.ps1 -OutputRoot 'build/recapture' -Views @('home','tow','campaign','result','shipyard','journal','daily','district','copperdock')
```

## Delivered PNG identities

SHA-256 values were computed after the three home captures were refreshed. Paths are relative to `marketing/screenshots/`; preserve these raw files when making thumbnails or review contact sheets.

| PNG | SHA-256 |
|---|---|
| `phone/01-home.png` | `3fb76b47e30e2ff49d13785ea025a9c557667af37e64dc37debeb34419ca9f6f` |
| `phone/02-rescue.png` | `f8914ffa2a7b87d69c66afb623929d2bfc381e59de62e2f4348f54d18825c0a5` |
| `phone/03-contracts.png` | `bf171836d6c13c23c2189dca253967eaa3b92258bead9204e9dae8e5110bf3d6` |
| `phone/04-result.png` | `481ddd4b1f70ff865dc44322456fc51e56477548709eddee38c8000cd7124fe4` |
| `phone/05-shipyard.png` | `12a3c3dce705938d455270c32ede16e8c75292df8d1c7f9d3c9fb273c282f73b` |
| `phone/06-journal.png` | `6f10909b3566999b7f3807c00d9e3136850b32d6b015adb9f649d62ad63e786d` |
| `phone/07-daily.png` | `4b65c241fc5cc25911eda26ad2a4906364e06159be19046fed2e0835db6d6d2a` |
| `phone/08-lantern.png` | `054671ff52d63cd5d923fda5e8999653bf7acc90ae1f29a5d6694fe8e54591c2` |
| `phone/09-copperdock.png` | `6a5eb048d934082b3c10d83f4aa3f3b1d5670d7ac5c867a624d262ce925bfa31` |
| `tablet7/01-home.png` | `5f019f453f231c77e0514937ce3d870f17a603597de7d582efed0d174d489df2` |
| `tablet7/02-rescue.png` | `3b82eec51c8d161b7680a75704d592b36f9ccd11a7277da0b85feef2244a4a70` |
| `tablet7/03-contracts.png` | `4bfc95dda95ec49946fac38a258b9c80e8df4603d8f1bd7e2b96cdbadedbe1b8` |
| `tablet7/04-result.png` | `86e63764646136cf70de70a572b859fa98ef57b1abf12f6e8d9a95eabea71662` |
| `tablet7/05-shipyard.png` | `9a3030aa3d78343ba951c28e3117170c8ddf2c3209bb4c2c79f3f9a143c818fa` |
| `tablet7/06-journal.png` | `ce98a99ce21daf42ed83ed2b9bf01a882162d2ff7455306b62dc5070c7364a41` |
| `tablet7/07-daily.png` | `0a7a56aac77a68fbfc6bf56e5c15b9d2abc9afeb6dbe411c9f5b7cb571bc6358` |
| `tablet7/08-lantern.png` | `547b114d493dd44c85bb8501bbc6cfb8855339dcedc6a7ef2a49ff1f18716143` |
| `tablet7/09-copperdock.png` | `66cbd1d23f097112ef975f7226e91c28e48540c45a50538c0575512c698f74f3` |
| `tablet10/01-home.png` | `caff511e5e46086be2b504b8efeccbb9b1de2d2b6372bf851a8697bed7c67c0a` |
| `tablet10/02-rescue.png` | `680b25953fa6c5ea547cfaf106b9d4f8c9efe3f51df973edce4f781eaa9b2e29` |
| `tablet10/03-contracts.png` | `1d5a69b9aa3f5835daaec233d2667e676fd132e7d4cafe22eb7c5c55fe1bd013` |
| `tablet10/04-result.png` | `63a5a3df83ed82fb6ca44bf787e90da8057893e8192fc8345b72a0f695d06d9d` |
| `tablet10/05-shipyard.png` | `c48ec7ae401ded7930451ffc99f9d1bad743fb0af99318e23c2e235ddd5c5714` |
| `tablet10/06-journal.png` | `b9ee95b8231370f51da36152721a198b70747f467c8c341cb6a67c7f65499c69` |
| `tablet10/07-daily.png` | `8012538b682bd84390e9ec34f098ecb10d89e1b7a1c82b704c1ef5c40bce5fba` |
| `tablet10/08-lantern.png` | `a7bb519d63c8731b068401a3f9ea557901c052f8db144eb64d4368b10af50f5e` |
| `tablet10/09-copperdock.png` | `e5a5f6a04a610937962ae33d3f89bca4d13f96cd80d3462b2777ec029fed2b1e` |

## Native Android emulator captures

Four additional PNGs are packaged separately in `marketing/screenshots/android-emulator/`. They show the native Android acceptance APK running on the Pixel 3a API 30 x86 emulator with the GLES3 renderer. They are emulator evidence, not physical-device screenshots.

- Runtime source: `7b001133ef71903209ec713c1dd3e4218334d329`.
- Debug acceptance APK: `build/android/tideline-tow-acceptance.apk` (test harness build, not the ordinary distributable APK).
- APK SHA-256: `b5a08c40bafa33bb37d2c2184931f0cf4a32096dc6cee1675afc947e75914fbc`, independently checked against the host file.
- The interstitial acceptance scenario seeded the prior completed-round count to two, then ran an actual Contract 01 through the Android game using the acceptance autopilot. The initial two rounds are fixtures, not completed gameplay evidence.
- UI navigation was performed through ADB. These captures do not claim human touch playtesting.
- Viewport captures contain Godot-rendered pixels only. They exclude Android status/navigation bars and native AdMob overlays. Full-device captures include those surfaces when visible.
- Each supplied host-local source file was copied unchanged. No new device pull, crop, resize, compositing or retouching was performed for this package.

The images show rendered gameplay, results, navigation state and the visible home banner. They do not independently prove an interstitial dismissal, rewarded entitlement, cold-save persistence or a complete ad journey. Consult the native acceptance records and [ACCEPTANCE.md](ACCEPTANCE.md) for those separate checks.

| Packaged filename | Pixels | Observed content |
|---|---:|---|
| `01-contract-one-tow-viewport.png` | 1080 x 2022 | Game viewport: Contract 01 in progress, first boat in tow; onboarding toast remains visible. No native SDK overlays are captured. |
| `02-contract-one-result-viewport.png` | 1080 x 2022 | Game viewport: original Contract 01 victory, 561 points, three boats, three stars, +162 coins and +100 XP. This is the initial host-local victory capture, retained without re-pulling a later device capture slot. |
| `03-harbor-home-test-banner-device.png` | 1080 x 2220 | Full device: harbor home, skipper level 2, 162 coins and Contract 02 ready. The actual Google sample banner visibly says Test Ad and 320x50. The source filename does not mean that a fourth-round result is shown. |
| `04-contract-two-result-device.png` | 1080 x 2220 | Full device: Contract 02 victory, 340 points, two boats, three stars, +83 coins and +80 XP. The lower banner rectangle is blank in this frame; this image does not prove a visible test-ad creative. |

### Native PNG identities

Source names refer to the retained host-local files under `build/native/`; packaged names are relative to `marketing/screenshots/android-emulator/`.

| Source file | Packaged file | SHA-256 |
|---|---|---|
| `v2-interstitial-tow.png` | `01-contract-one-tow-viewport.png` | `0cb46dd168819ed318e4abc156d100069cf809b319f1ce282dbd2d15b18ab0f6` |
| `v2-interstitial-result.png` | `02-contract-one-result-viewport.png` | `b3db6e08da822446fd37150e2439054195429ac56e68106aa586f2c8ad3c66b5` |
| `v2-round-four.png` | `03-harbor-home-test-banner-device.png` | `2818abafbbee2ef29600db61bcab6948d8d490f6e19eadb60ddc68cf62c52b7c` |
| `v2-contract-two-result.png` | `04-contract-two-result-device.png` | `59917127981d8d5d3de5de6ce3cab36e5fbd08ab6e0a0d4c7ac5aa8acdc178e9` |
