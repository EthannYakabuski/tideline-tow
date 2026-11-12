# Tideline Tow gameplay rules

Hold the helm toward a direction or hold a point on the water. Release to anchor. Keyboard controls are WASD or arrow keys; Escape pauses. Sail close to an SOS boat to add it to the tow. Enter the glowing harbor to hand the convoy to the dock crew. The boats visibly draw into the berth as delivery is scored.

The opening tug carries three boats and has three hull hearts. Rocks and crossing ferries can damage the tug or its trailing boats. A collision drops the last towed boat into recoverable water and briefly protects the tug from another hit. Currents affect a moving tug; anchoring stops the drift. The model uses bounded simulation steps and the same obstacle positions shown by the scene.

Thirty contracts have authored rescue positions, obstacles, time limits and mastery targets. A successful contract earns one star, keeping an undamaged hull earns another, and meeting its mastery time earns the third. Kenney filled and empty star textures show saved results. Replaying can improve the stars; rewards settle once for each distinct voyage.

Harbor Watch presents successive rescue waves. Deliveries replenish the visible countdown; later waves introduce crossing traffic, currents and changing scenery. The daily voyage selects a deterministic contract from the UTC date. Local progress works without Android services.

Coins buy three towline ranks, three small engine improvements and one extra hull heart. Skipper level derives from lifetime XP and awards coins on level gains. Daily quests and the seven-day welcome cycle are optional, once-only claims. Empty abandoned watches grant no coins or XP. Convoy badges require an actual delivery of the stated number together.

Leaving play saves the complete active rescue. Starting another mode requires an explicit choice to replace it. Results, upgrades and daily claims roll back in memory when the save write fails. Saves use a validated envelope, atomic replacement and last-good backup. Device-local files are not cloud saves.

An available Android rewarded ad can call the rescue crew once after a failure. Only the native earned callback restores two hull hearts and at least45 seconds. The app remains paused through the ad and endcard and asks for a neutral resume afterward. Desktop and Web never fabricate ad rewards. A banner uses reserved Home/results space; an available interstitial is requested after every third finalized watch at the results break.

Play Games mappings are blank and disabled pending owner configuration. Local badges and boards remain usable; the adapter queues progress for configured eligible native sessions. Original code is Apache-2.0; Kenney assets and native plugins retain their separate notices in `LICENSES`.
