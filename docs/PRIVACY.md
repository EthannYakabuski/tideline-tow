# Tideline Tow — privacy information for the prototype

This is a draft for the test-configured prototype, not a completed production privacy policy. Before release, the publisher must supply its legal/contact details, public policy URL and applicable store disclosures, and verify the behavior of the final SDK configuration.

## Local game information

The game stores coins, skipper experience, upgrades, achievements, local records, daily claims, preferences and an interrupted rescue on the device. It keeps a validated backup. It does not implement a developer account, chat, location tracking, contacts access or cloud-save synchronization. Uninstalling or clearing app/site data can remove progress. Browser storage is subject to browser settings.

## Advertising

Android prototypes use Google's sample AdMob application and ad-unit IDs. Google Mobile Ads and its consent SDK can process network/device information and diagnostic or advertising-related data according to their own documentation and the user's applicable choices. The game does not attach player names or custom personal information to requests. Native consent forms and privacy options depend on the publisher's configuration and region. The in-game Options screen exposes Ad privacy choices.

Banner ads appear on home/results, interstitials at natural transitions every third finalized rescue, and a rewarded continuation is optional. No reward is granted for an unavailable ad or an unearned early dismissal. Web does not load the native advertising SDK.

[Google's advertising privacy information](https://policies.google.com/technologies/ads) and [Mobile Ads SDK data disclosure guidance](https://developers.google.com/admob/android/privacy/play-data-disclosure) describe the third-party service. The publisher must review those sources against the final SDK version and audience before completing Data safety forms.

## Play Games

Play Games is disabled in the supplied build, with blank backend mappings. Local achievements and high scores remain available. When the publisher configures and enables Play Games, sign-in and achievement/leaderboard submissions are handled by Google; the game queues local achievement keys and integer high scores for retry. Production account switching and service behavior still need verification.

## Publisher actions before release

Provide an accurate public support/contact route and policy URL, choose and validate the audience/consent settings, audit SDK collection and retention, complete Data safety/content-rating/ads declarations, and test privacy choices on intended devices and regions. No Google Play submission is included in this prototype handoff.
