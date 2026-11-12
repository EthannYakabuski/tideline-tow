# Tideline Tow: Android services

The project includes Poing AdMob 5.1.0 and Godot Play Games Services 3.4.0, including their Android libraries and MIT notices. The adapters support Android native callbacks; the editor and Web build retain local play and never invent ad rewards. No production credentials, release signing keys or real service IDs are included.

## AdMob configuration

The operative manifest app ID is `project.godot` > `[admob] general/android/app_id`. It is Google's sample `ca-app-pub-3940256099942544~3347511713`. The matching value in `platform/config.json` is descriptive; editing JSON alone does not change the Android manifest.

`platform/config.json` starts with `admob.test_mode=true`. Every debug build chooses Google's sample fixed banner, interstitial and rewarded IDs even if production unit mappings are later filled. A production release requires the real manifest app ID, `test_mode=false`, and real `banner_unit_id`, `interstitial_unit_id`, `rewarded_unit_id`. Do not test by clicking production ads. [Google test ad guide](https://developers.google.com/admob/android/test-ads)

The banner is shown only on the home/results surfaces. `Services.menu_bottom_reserve(root)` reports space for the native banner, safe-area/navigation inset and separation. Hide it during the active rescue, pause and other panels. An interstitial is eligible at every third finalized round, after the game has durably committed the result and closed any continue offer. The adapter rejects duplicate result counts/IDs; an unavailable ad is skipped, not deferred into gameplay. Rewarded rescue is an explicit player request on failure. Only the SDK's earned callback emits `reward_earned(run_id)`. The game must atomically store its one-continue flag before applying the recovery. Early dismissal or show failure grants nothing. Unsupported Web/editor services grant nothing.

`fullscreen_changed(active)` covers the request, native fullscreen ad and UMP form lifetime. The game must pause and retain an explicit resume action after interruption. Earned rewards can arrive before dismissal: persist the reward, but keep gameplay stopped while `fullscreen_ad_active()` is true.

At every Android launch, UMP updates consent information and displays a required form. Ad loading is withheld unless the SDK reports obtained/not-required consent. The supplied plugin exposes consent status, but not Android's newer `canRequestAds()` convenience method; the adapter uses its supported conservative status flow after update. `show_privacy_options()` opens the native form when required and otherwise reports that no form is needed. Opening it clears cached ads, and requests restart only after consent is checked. The owner must configure actual privacy messages and test all intended regions, audiences and revocation paths. [Google UMP guide](https://developers.google.com/admob/android/privacy)

## Play Games configuration

The default is explicitly disabled with empty game/achievement/leaderboard IDs. Local achievements and records remain usable. To activate, set the real numeric project ID in both `platform/config.json` > `play_games.game_id` and Android export > `godot_play_game_services/game_id`, set `play_games.enabled=true`, then fill all 20 achievement and three leaderboard mappings. Board keys are `total_rescues`, `best_endless` and `skipper_xp`; all are integer, higher-is-better boards. Achievement keys match `game/content.gd`.

Configure `com.ethannyakabuski.tidelinetow`, release/test certificate fingerprints, the linked Android application, testers and backend resources in the owner's consoles. The service adapter journals desired unlocks/high scores, retries failed sessions, keeps larger values and does not acknowledge submissions until a successful native callback. A callback without request identity cannot acknowledge a later timed-out score: such IDs remain eligible for idempotent retry. Local saves are independent of this journal. Account changes, real sign-in, achievements and leaderboards require backend/physical-device validation. Cross-device cloud save is not implemented.

## Included plugin adaptations

- The PGS exporter omits `APP_ID` metadata when the game ID is blank, so an intentionally disabled build never references a missing resource. It retains a pre-registered PGS autoload and creates the resource when configured.
- AdMob preserves the explicit sample Android app ID in project settings. The inherited no-auto-install iOS editor behavior is retained: Android/Web are the targets.
- Both upstream MIT licenses remain in their addon folders and `LICENSES/`. Google SDK dependencies and their terms still apply.

## Game integration API

`set_banner_visible(bool)`, `menu_bottom_reserve(CanvasItem=null)`, `menu_bottom_reserve_changed`, `round_completed(total, round_id="")`, `request_rewarded_continue(run_id) -> bool`, `reward_earned(run_id)`, `reward_finished(run_id, earned)`, `fullscreen_changed(active)`, `fullscreen_ad_active()`, `submit_progress(unlocked_keys, scores)`, `request_sign_in()`, `show_achievements()`, `show_leaderboards(key="")`, `show_privacy_options()`, `status()`, `availability_changed` and `service_notice(message)`.

`reward_finished` means an entitlement decision (earned callback or non-earned closure), not necessarily native dismissal. Keep checking the fullscreen state before resuming. `round_completed` accepts the persistent completed-round total, never a session-only counter.

The debug-only `acceptance` export isolates its service journal before reading any progress. It uses `user://qa/platform-{profile}.json`, taking `profile` from `user://qa_probe.json` only after accepting a short safe filename. Ordinary exports always use the normal service journal and ignore the probe.

## Repeatable adapter tests

After importing the project, run `godot --headless --path . res://platform/tests/test_services.tscn`. Use the scene entry point so the plugin's autoload is registered before its client classes compile. The suite creates its journal fixtures beneath ignored `build/test-platform/` and removes only those fixture files. It tests sample-ID selection, shipping mappings, reward idempotency and stale callbacks, unavailable ads, fullscreen events, privacy blocking, interstitial count/result deduplication, banner insets, corrupted retry storage, higher-score retention, authentication cancellation/timeouts and ambiguous delayed acknowledgments. These are scripted fixtures, not native SDK presentation evidence.

On 2026-11-12 the canonical project passed all 57 assertions with exit code 0 on Godot 4.5.1. No script errors or resource leaks appeared. The Windows execution environment logged its separate root certificate-store warning; no network request is part of these fixtures. The parent build/acceptance evidence records native testing separately.

## Release work

The owner supplies production IDs/backend setup/signing, validates consent and ads on physical phones/tablets, reviews policy/store disclosures and publishes to Google Play. No purchase or Play publication is performed by this project. Test configurations and automated callback fixtures are not production service acceptance.
