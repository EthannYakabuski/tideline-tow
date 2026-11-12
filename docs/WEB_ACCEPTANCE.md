# Web acceptance - 2026-11-12

The coordinating thread tested the live GitHub Pages deployment in a supported isolated cloud browser, separately from the owner's personal Edge session. The review rendered and its 7-inch screenshot-profile switch worked. The game reached the Godot loader, which reported missing WebGL2 support in that browser. Gameplay and reload persistence therefore remain not run; this is a browser capability limit, not a demonstrated game-code failure.

Tested public deployment: `bfc4b12c7399ee0ed11e2334a305a8533786ec91`. Canonical runtime identity: `4f97ff49af249f70c693119aeba99f0ec7eb1e8afadf49e5fdde0cc6ba5672ba`. The initial deployment's metadata flagged a CI working-tree change; publication provenance is tracked separately from browser observations. Later documentation and build-tool changes preserve the tested runtime.

| Check | Status | Observed evidence and limits |
| --- | --- | --- |
| Public HTTPS delivery | PASS | `tools/validate_site.py` retrieved 56 live resources, including the landing page, review, Web shell/PCK/WASM, metadata and all 27 desktop profile screenshots. HTTP checks do not execute gameplay. |
| Review rendering | PASS | The isolated browser displayed the live review, generated artwork, current acceptance copy and genuine runtime screenshots. |
| Review screenshot profile switching | PASS | Clicking 7-inch changed the selected state, all six screenshot links to `tablet7` paths and the visible loaded images. |
| Web loader | PASS | The live `/play/` URL loaded the Godot shell and displayed its capability diagnostic. |
| WebGL game startup | BLOCKED | The isolated browser reported: `The following features required to run Godot projects on the Web are missing: WebGL2 - Check web browser configuration and hardware support`. No browser settings were changed. |
| Actual rescue with keyboard / pointer | NOT RUN | Game startup was blocked by the isolated browser's missing WebGL2 capability. |
| Pause, resume and background return | NOT RUN | Requires a running WebGL game. Native and fixture results are separate evidence. |
| Progress persistence after browser reload | NOT RUN | Requires actual Web play, save and reload. HTTP/artifact checks do not prove this. |
| Menus, quests, upgrades and daily gifts in Web | NOT RUN | Requires a running WebGL game. |
| Unavailable Web ads / Play Games feedback | NOT RUN | Adapter fixtures do not substitute for live browser interaction. |
| Embedded-game rendering on landing page | NOT RUN | Loading the standalone Godot shell does not establish iframe gameplay. |
| Physical touch, browser audio and performance | NOT RUN | No physical-device or auditory acceptance is claimed. |

## Earlier personal-browser attempt

The earlier local-preview worker first tried the browser connector. It returned `Browser is not available: iab`, and its browser inventory was empty. The worker then tried the existing minimized native Edge window through Computer Use. Activation restored the window; the following bind/new-tab attempt was stopped by the owner's physical Escape key before game navigation. Whether that new tab opened is uncertain. No further personal-browser control, game navigation or browser setting changes were attempted.

That explains the earlier Edge choice: the worker's attempted isolated in-app surface was unavailable. It does not establish that every possible isolated browser was unavailable. The coordinating thread subsequently found a separate supported cloud-browser surface and performed the review and loader checks above under the owner's new explicit direction. There was no repeated personal-Edge request or further approval prompt.

The local preview server and temporary Android emulator were stopped after their scoped work. No persistent browser, emulator or security settings were changed.
