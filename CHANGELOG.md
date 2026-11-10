# Changelog

All notable changes to LFG Forever are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Titan Panel integration (same mechanism Socialite uses: a LibDataBroker-1.1 "launcher" object, which Titan's own TitanLDB bridge turns into a panel button automatically - no direct Titan API calls needed). Vendored LibStub, CallbackHandler-1.0, and LibDataBroker-1.1 under `Libs/` so this works with or without Titan/Socialite installed.
  - Left-click: open/close the window (same as the minimap button).
  - Hover: shows active listings for the current zone's own activity (e.g. a dig site named after the zone) and, separately, for a dungeon activity tied to this zone, each with a group/solo count and up to 5 names.
  - Right-click: menu to search just the zone's activity, or just the zone's dungeon, opening the window with results - each only offered if one was found.

### Notes
- The zone activity is found by matching an activity's name against your current zone text (e.g. "Excavation Site: Wetlands" while in Wetlands). The dungeon match is found via each activity's `mapID` field falling within your current zone/continent map chain - this field is new (patch 11.0.7+) and we haven't been able to confirm in-game whether this server populates it usefully for its dungeon activities. If the dungeon side never finds a match, that's the first thing to check.

### Changed
- When you're in a group but not the leader or an assistant, the Invite button on solo listings no longer greys out. It now reads "Suggest" and relays the invite to your group leader for approval instead - the same built-in behavior as the social menu / player frame "Invite" option, using the same `InviteUnit` call.
- Invite/Suggest on solo listings now disables itself (button reads "Full") when your party is full and not a raid, or your raid is full - no point inviting or suggesting when there's no room.

### Added
- Declined Request to Join is now reflected in the UI: the row dims and its button shows "Declined" (disabled) instead of "Request".
- "Hide declined" filter checkbox (on by default) to hide groups whose leader already declined your request.
- `/lfg cleardeclined` and a per-row "Clear declined status" right-click option to forget a decline and try again.

### Notes
- There's no documented Blizzard event for a declined Request to Join, so this is detected by watching the system chat line this server prints for it: `"<Name> declines your group invitation request."` (confirmed in-game). Detection now matches that exact wording rather than a loose keyword guess.

## [1.0.1] - 2026-11-10

### Changed
- Renamed the addon from "Enhanced Group Finder" to **LFG Forever**: new `.toc` title, Lua namespace (`LFGForever`), SavedVariables (`LFGForeverDB`), and frame/button names.
- Credited the addon to its creators: Tri Chomez (creator) and Aldamir Nocturna (contributor).

### Removed
- The `/egf` slash command. Use `/lfg` or `/groupfinder` instead.

## [1.0.0]

### Added
- Initial release (as "Enhanced Group Finder"): filterable Looking For Group browser with tank/healer/dps, level, and text filters.
- Invite and Request to Join buttons, right-click menu (Whisper / Invite / Request to Join / Who).
- Draggable minimap button.
- `/lfg`, `/groupfinder` slash commands (plus the since-removed `/egf`).
