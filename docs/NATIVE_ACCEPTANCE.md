# Native Android acceptance

Runtime: `7b001133ef71903209ec713c1dd3e4218334d329`, Godot 4.5.1 Compatibility. The diagnostic APK is `tideline-tow-acceptance.apk`, SHA-256 `b5a08c40bafa33bb37d2c2184931f0cf4a32096dc6cee1675afc947e75914fbc`. Exact ordinary APK and debug AAB identities are in [build-evidence.json](build-evidence.json).

The environment was a temporary Pixel 3a API 30 x86 Android emulator using GLES3. It was started read-only with snapshots and audio disabled, host graphics and a process-only GLES compatibility flag. No physical-device or ARM64 runtime acceptance is claimed. No persistent AVD or security setting was changed.

The acceptance feature is enabled only in its separate debug export. It reads an explicit `qa_probe.json`, isolates game/service data below `user://qa/`, and drives the real game loop with steering input. The ordinary export ignores this configuration. Diagnostic builds must not be distributed to players. The captured profiles are task-created test fixtures, not owner progress.

| Check | Result | Observation |
|---|---|---|
| Install and GLES3 launch | PASS | Final acceptance APK installed and launched on the emulator. |
| Ordinary APK direct controls and cold save | PASS | Final ordinary APK SHA-256 `4233f7a76b2ca6016c8e2714de0c116936d2745901bcbab42729943b69d73026` installed and ignored the retained acceptance probe. Direct ADB water-target and helm touch input collected/delivered one boat for 100 points with full hull. Android Back paused at elapsed 30.0577 seconds. Process restart retained the exact run ID, position, one delivery and score; Home offered the parked rescue. This used the real input path, not the acceptance autopilot. |
| Three actual contracts | PASS | Contracts 01/02/03 produced 561/340/352 points, seven total deliveries, 328 coins and 260 XP. The native probe uses a simple nearest-boat driver, separate from the all-contract route-planning suite. |
| Actual collision failure | PASS | Contract 04 encountered three hull-depleting collisions, stopped and offered optional rescue or free return. This is expected game behavior; the probe does not avoid every hazard. |
| Sample banner | PASS | Actual sample creative visible at Home and result breaks, with reserved space. A separate Contract 02 screenshot shows a blank creative slot and is labeled accordingly. |
| Unavailable eligible interstitial | PASS | The first eligible result continued normally when its ad was not loaded. |
| Interstitial presentation/dismissal | PASS | A real sample interstitial opened after the sixth cumulative finalized round, then its visible Close button returned to the settled result. Two initial rounds were seeded, followed by three real wins and one failed watch. The final profile held 333 coins/270 XP. |
| Rewarded closure without entitlement | PASS | The visible sample ad was closed without an earned callback. The game displayed no-reward feedback, retained failed hull/`continued=false`, and preserved that state after process restart. No repair or currency was invented. |
| Real earned rewarded callback | PASS | A separate actual 45-second deadline failure opened the sample rewarded ad. The SDK granted a reward; `continued=true` and hull 2 were saved before dismissal while fullscreen remained active. |
| Repaired HUD and neutral dismissal | PASS | The patched build immediately showed two filled hearts and 0:45 behind a neutral Resume dialog after dismissal; no automatic sailing occurred. |
| Cold earned continuation and resumed delivery | PASS | The same run ID, hull 2, `continued=true` and neutral pause survived process restart. Explicit Resume completed three deliveries for 561 points, 162 coins, 100 XP and two stars. |

The initial `1305a04` runtime also completed an earned/cold/resume journey. That run exposed the stale paused HUD and led to the final two-call display correction plus six additional UI regressions (49 total). It is not substituted for the final-runtime cases above.

Raw native observations are retained locally under `build/native/`. Selected gameplay images and their byte hashes are public in [SCREENSHOTS.md](SCREENSHOTS.md). [The evidence manifest](evidence/native/manifest.json) binds 14 unchanged JSON/PNG files to the final APKs; 50 packaging assertions verified the recorded states, callbacks, payout identity and ordinary-profile checksum. These assertions inspect genuine recorded observations, not a new emulator run. Restoring clears transient per-tick failure events while retaining persistent game state. Screenshot filenames describe the capture step; a screenshot alone does not prove a callback or persistence.

Human touch feel, audio listening, accessibility, battery/thermal performance, production credentials, Play Games backend behavior, all consent regions and store release eligibility remain unverified. Sample-ad behavior does not certify production ads. No ad Install button, purchase or Google Play publication was performed.
