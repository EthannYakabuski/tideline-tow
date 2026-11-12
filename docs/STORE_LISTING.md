# Store listing handoff

The canonical machine-readable copy is [marketing/store.json](../marketing/store.json). It contains the title, 62-character short description, 2,028-character long description, proposed Arcade category/tags, three selling cards, lore, platform details and a clearly labeled future DLC proposal.

Achievement and leaderboard manifests are [achievements.json](../marketing/achievements.json) and [leaderboards.json](../marketing/leaderboards.json). They preserve the game's exact local keys and visible names. Backend identifiers remain blank, as required. All three boards order larger scores first.

## Upload assets

Use the 512px app icon and 1024×500 feature graphic in `marketing/`. The 20 achievement and three leaderboard images are 512px squares. Do not use `marketing/source/` atlases as individual icons. Genuine runtime screenshots are in three viewport-profile directories; their evidence and device distinction are documented in [SCREENSHOTS.md](SCREENSHOTS.md).

The review is [review/index.html](../review/index.html); the website source is [public/index.html](../public/index.html). Both use relative links and local images. The review's screenshot profile controls require no network service.

## Owner release work

Complete Google Play's questionnaires, support contact, privacy-policy URL and declarations using the actual final SDK behavior. Configure production Play Games app/achievement/leaderboard IDs and AdMob IDs, verify signing and native service flows, and complete physical touch/audio/performance/accessibility testing. Remove the prototype disclosure from store copy only when its replacement is true. Keep ads and data collection declarations consistent with the shipped binary.

The full game remains playable with local progress while production service configuration is pending. No Google Play upload, purchase or publication was performed for this package.
