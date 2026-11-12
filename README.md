# Tideline Tow

**A little tug. A growing convoy. Bring every boat home.**

A portrait 3D harbor-rescue arcade game for Android, built in Godot 4.5.1 Compatibility. Steer through a coastal diorama, hook stranded boats into a visible tow chain, then return to the glowing harbor. Long convoys earn bonuses and demand more care around ferry crossings. Normal retries are always free.

## Play

Hold the bottom helm in a direction or hold a spot on the water; release to stop. On a keyboard, use WASD or the arrow keys. Escape/Android Back pauses. The next contract launches directly from Home. A parked rescue can be resumed or explicitly replaced.

- Thirty authored contracts across Sunwake Cove, Copperdock and Lantern Strait.
- Endless Watch with a replenishable countdown, and a seeded UTC daily rescue.
- Skipper levels, earned-coin rope/engine/hull upgrades, daily goals and a seven-day login cycle.
- Twenty local achievements and three records, with optional configured Play Games submission.
- Validated local saves, backup recovery, interrupted-rescue restoration and once-only settlement.

The Web version keeps local progress and reports native services as unavailable; it never invents an ad reward. Browser storage depends on browser settings. Cross-device cloud saves are not implemented.

## Review and evidence

The styled review is [review/index.html](review/index.html). [Acceptance](docs/ACCEPTANCE.md) separates passed, failed and not-run checks; [screenshot provenance](docs/SCREENSHOTS.md) explains the capture environments. [Gameplay rules](docs/GAMEPLAY_RULES.md) and [store listing](docs/STORE_LISTING.md) provide details. Generated illustrations are separate from real runtime screenshots.

Local export outputs belong in `build/android/` and `build/site/play/`; they are intentionally excluded from Git. Exact final build hashes and runtime source hashes are recorded in `docs/build-evidence.json` when exports finish. A test APK and acceptance APK are debug builds, not production release artifacts. The acceptance APK is a separate diagnostic build and must not be distributed to players.

## Build and test

Use the Godot **4.5.1** editor and its matching export templates. Android uses the installed Android SDK and JDK 17; configure their paths in Godot Editor Settings. The presets enable Gradle, API 24 minimum, target API 36, and ARM64/x86/x86_64. These are tested build settings, not a claim of Play release eligibility.

```powershell
./tools/test.ps1 -Godot 'path/to/Godot_v4.5.1-stable_win64.exe'
./tools/build.ps1 -Target Android
./tools/build.ps1 -Target 'Android Test APK'
./tools/build.ps1 -Target Web
python tools/assemble_site.py build/site
```

Pass `-Godot` to each script if the editor is not on the default Desktop path. Build scripts track and wait for the actual process; do not run two Android exporters in the same project simultaneously. No Windows distribution build is produced.

For other systems, import with `godot --headless --editor --path . --import`, then run `--script tests/test_model.gd`, `--script tests/test_ui.gd`, and the normal scene `res://platform/tests/test_services.tscn`. Use isolated writable data/log locations. Run `python3 tools/validate_audio.py`, `python3 tools/validate_content.py` and `python3 tools/verify_android_bundle.py <bundle.aab>`. The hosted workflow validates source/content and exports the single-threaded Web build; Android artifacts are validated locally.

GitHub Pages is enabled with Actions deployment and `PAGES_DEPLOY_ENABLED=true`, under explicit owner approval. [Play](https://ethannyakabuski.github.io/tideline-tow/play/) and [review](https://ethannyakabuski.github.io/tideline-tow/review/) are public. The workflow retains reviewed plugin translation resources after import and rejects unexpected checkout changes before publication. [Live build metadata](https://ethannyakabuski.github.io/tideline-tow/build.json) identifies the deployed commit; [acceptance](docs/ACCEPTANCE.md) distinguishes delivery, browser capability and gameplay checks.

## Services and publishing

The native Poing AdMob and Godot Play Games Services plugins are included. AdMob uses Google's sample app/unit IDs. Home/results reserve space for a banner; an interstitial is eligible after each third finalized round; an optional rewarded ad can continue a failed rescue once, only after the real earned callback. Fullscreen ads and consent forms pause play.

Play Games is disabled with blank backend mappings until the owner supplies real IDs. See [platform setup](docs/PLATFORM_SETUP.md) for precise fields and callback behavior. The publisher supplies production service configuration, signing, policy/support information and store forms, then performs physical-device and real-backend testing. The [privacy document](docs/PRIVACY.md) is a clearly marked prototype draft. Nothing in this repository submits the app to Google Play.

## License and credits

Original project work is Apache-2.0. Kenney Watercraft, Pirate, Industrial, UI and sound assets are CC0. The engine and service plugins retain their MIT notices; the plugin's Noto font retains its SIL OFL notice. Original music/art provenance and all third-party notices are in `LICENSES/`, `marketing/art-prompts.json` and the audio manifest. See [NOTICE](NOTICE).

Future expansion concept: Winter Harbor, ten additional ice-channel rescue contracts. It is a proposal, not implemented content.
