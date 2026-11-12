# Bug log — Tideline Tow

Updated 12 November 2026. This log records defects found during implementation, source review and actual Godot rendering. A scripted regression is evidence for its stated behavior; it is not evidence of native SDK presentation, physical-device performance or human difficulty acceptance.

The latest local automated runs report **145/145 model checks**, **49/49 UI/lifecycle checks** and **57/57 platform fixture checks**. The UI total includes the later native-discovered rescue-display regression; the earlier complete UI run was 43/43. The model run completes all 30 authored contracts without upgrades or ads and with zero damage, taking 8.4–77.9 seconds under the baseline strategy. Logs are retained locally under ignored `build/final-tests/` and `build/qa/ui-reward-refresh.log`; reproducible sources are [test_model.gd](../tests/test_model.gd), [test_ui.gd](../tests/test_ui.gd) and [test_services.gd](../platform/tests/test_services.gd).

## Gameplay and progression fixes

| Finding | Correction | Verification |
|---|---|---|
| Real epoch and UTC-date hash seeds exceeded the snapshot validator's original counter bound, rejecting genuine active saves. | Seed validation accepts the actual unsigned 32-bit seed domain separately from bounded gameplay counters. | Model regressions cover real epoch and date-hash snapshots. |
| Very slow analog movement could move the tug without advancing its tow trail. | Trail sampling accumulates distance rather than requiring a minimum distance in every frame. | Slow-input regression checks that the trail head remains attached. |
| A long convoy could exhaust history while moving slowly and extrapolate its tail incorrectly around turns. | Distance-sampled, bounded trail history retains the complete six-boat convoy; spacing is 2.05 world units. | Six-boat long-path, turn-clearance and retained-history regressions. |
| Ferries jumped from their authored initial position on their first tick. | Motion begins continuously from that position. | First-tick ferry regression. |
| Fatal collision while towing could leave stale tow positions after dropping a boat, invalidating the terminal save. | Dropped boats are moved to recoverable positions and tow positions are refreshed before terminal state is saved. | Fatal carrying-collision snapshot regression. |
| Reviving a long convoy could place its tail outside the harbor world. | The revive trail bends within the playable bounds. | Six-boat revive-bound regression. |
| Early timers gave little reason to plan routes, and the first contract ended too quickly. | The introduction uses three boats; contract time limits and mastery targets were tuned against baseline routes. | All 30 final baseline routes pass. Human pacing and difficulty remain a separate review. |
| Convoy badges described delivered boats but were awarded for merely hooking that many boats. | Maximum convoy is recorded on delivery. | Undelivered three-boat convoy does not award the delivery badge. |
| Immediately abandoning an untouched watch could farm coins and XP. | Failed watches without rescue activity grant no consolation currency or XP. | Zero-work settlement regression; actual unsuccessful rescue activity retains its modest consolation. |
| Starting another mode could silently replace a saved rescue. | A saved rescue presents an explicit resume-or-replace choice. | UI regression verifies the original active run survives the first new-mode request. |
| Harbor Watch displayed elapsed time while failure depended on a replenishable countdown. | The HUD displays the remaining deadline. | UI assertion verifies the initial `2:30` deadline. |

## Saves, services and lifecycle fixes

| Finding | Correction | Verification |
|---|---|---|
| A failed write after settlement, purchase or a claim could leave in-memory economic changes appearing committed. | Settlement, upgrades, login gifts and quest claims restore their previous profile on failed writes; result settlement offers a retry. | UI tests inject failed writes and compare the complete profile before and after each operation. |
| A corrupted-save notice promised continued retention of the original corrupt file, although a later save may replace it. | The notice now states only the observed recovery outcome. Valid previous backups remain protected from a corrupt primary. | Source review plus genuine previous-backup recovery and subsequent-save model tests. |
| Login and quest rewards could remain absent from the Play Games submission queue until a later completed run. | Successful claim commits queue current achievements and leaderboard values; loading also replays local progress. | Source review of the application integration; production backend delivery remains unverified. |
| Headless UI teardown reported audio playback resources that were inappropriate for a no-audio test process. | Audio creation is skipped for the headless display server. | Subsequent UI run completed without those resource leaks; rendered/native audio is not disabled by this guard. |
| A genuine Android earned-reward journey restored the tug's model while the paused view retained the failed HUD/world until resumption. | Revision `7b001133ef71903209ec713c1dd3e4218334d329` refreshes the harbor and HUD immediately after the earned revive, retaining the fullscreen lock and neutral resume. | Expanded UI suite: 49/49. Rebuilt final-runtime native verification passed: real earned callback, corrected paused two-heart/0:45 HUD, dismissal, cold recovery and explicit-resume victory. |

Final regression coverage also checks repeated and cold-load settlement, genuine backup recovery, invalid-save rejection, active-convoy restoration, UTC rollover and rollback, seven-day gifts, repeated quest claims, pause/Back behavior, unavailable rewards, pending fullscreen locks and neutral resume after dismissal. Platform tests use explicit fixtures; they do not claim actual native ad presentation or Play Games backend acceptance.

## Visual and interface fixes

| Finding | Correction | Verification |
|---|---|---|
| Rescue SOS markers and halos were hidden because the renderer checked `waiting` while the model uses `afloat`. | Renderer and model status names agree. | UI checks plus actual rescue captures. |
| Later endless waves could add an invisible ferry or reuse delivered boats at their shrunken scale. | The renderer rebuilds on wave changes, refreshing boats, ferries, currents and district scenery. | UI assertions cover entity counts, ferry visibility, district change and full boat scale. |
| Wake animation suggested movement while the tug was anchored; ferry direction and current cues were ambiguous. | Wakes respond to actual displacement, ferries turn with travel direction and currents use world-space arrow meshes. | Source review and rendered iteration; static screenshots alone do not establish animation quality. |
| Early phone layouts wrapped HUD text and allowed presentation elements to compete with the play area. | The gameplay viewport has dedicated space between the HUD and helm; labels and fixed fields were adjusted. | Regenerated phone and tablet captures. |
| Unnormalized rock models were visually much larger than their collision circles; vessel sizes also needed consistency. | Actual model bounds determine displayed rock diameters and vessel scaling. | Lantern and Copperdock rendering review, followed by regenerated captures. |
| The angled Home diorama's two harbor labels overlapped. | The redundant Home label was removed; gameplay keeps its separate harbor cues. | Home captures were regenerated after the cosmetic correction. |

An independent visual review inspected all nine 7-inch tablet views: Home, rescue, contracts, result, shipyard, journal, daily rewards, Lantern Strait and Copperdock. No blocking control clipping or hidden gameplay area was found. Contracts and journal intentionally continue below the viewport inside visible scroll containers. Screenshot origin and dimensions belong in [SCREENSHOTS.md](SCREENSHOTS.md).

## Environment and build incidents

- An Android emulator **SystemUI ANR** occurred during native preparation. This is recorded as an emulator/system incident, not as a demonstrated Tideline Tow crash. It does not count as application acceptance.
- An early export wrapper did not reliably represent the lifetime of its Godot child process, allowing export attempts to overlap. Build orchestration now tracks the owned process and runs exports sequentially. A wrapper return alone is not treated as a completed build; output, process completion and artifact identity must be verified.
- The Windows headless runs emitted a host certificate-store diagnostic. Their successful assertion totals are recorded separately; this diagnostic is not claimed to prove network or service operation.

## Remaining verification

The final runtime `7b001133ef71903209ec713c1dd3e4218334d329` passed the documented Android emulator core-loop, real banner/interstitial dismissal, no-earned reward closure, earned continuation, corrected HUD and cold-resume journeys. Sequential rebuilt artifacts and final AAB architecture checks passed. The owner explicitly approved public evidence and Pages publication; those restrictions are resolved. Clean publication baseline `8a68db13e272f1dab68a1490d7584e579f5babe2` passed [CI 43288056075](https://github.com/EthannYakabuski/tideline-tow/actions/runs/43288056075) and live HTTPS identity checks.

CI initially regenerated five tracked AdMob sample translation binaries during CSV import, producing dirty metadata. The workflow now restores only those five reviewed resources immediately after import, before tests/export. A strict post-export guard rejects any remaining checkout changes. All five payloads in the public PCK were also verified byte-for-byte against the committed files. No gameplay or platform runtime source changed.

The authorized isolated cloud browser rendered the review and passed its 7-inch profile switch. The Web game reached the Godot loader, which reported missing WebGL2 support; gameplay and browser reload persistence remain NOT RUN. This is a browser capability limitation, not a demonstrated game defect. The earlier personal-Edge cancellation was not retried. All 56 live static resources passed HTTP verification. See [Web acceptance](WEB_ACCEPTANCE.md) and [publication evidence](publication-evidence.json).

Physical touch, audio listening, accessibility, sustained device performance and human difficulty assessment remain owner checks. Production AdMob and Play Games IDs, backend resources, consent-region behavior and release signing require owner configuration. No Google Play publication is performed.
