# Changelog

All notable changes to LFG Forever are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Zone entry chat notice: prints once when you enter a zone with a matching zone/dungeon activity (e.g. "Entered Westfall - Westfall, Deadmines nearby. Right-click the minimap/Titan icon to search."). Only reads already-known activity data - never triggers a search itself, so it can't get stuck the way a hover-triggered search did.
- Minimap button now matches the Titan Panel button: hovering shows the same zone/dungeon listings, and right-clicking offers the same "Search Zone X" / "Search Dungeon Y" options, now combined into one menu with the settings checkboxes ("Zone entry notifications", "Hide minimap button") and "Open window". Also togglable via `/lfg zonenotify`.

### Changed
- Pulled the zone/dungeon tooltip-building and menu-building logic (previously only in Titan.lua) into shared `ns.AddZoneTooltipLines()` / `ns.AddZoneMenuItems()` in Core.lua, so the minimap button and Titan Panel button can't drift out of sync with each other.

- Titan Panel integration (same mechanism Socialite uses: a LibDataBroker-1.1 "launcher" object, which Titan's own TitanLDB bridge turns into a panel button automatically - no direct Titan API calls needed). Vendored LibStub, CallbackHandler-1.0, and LibDataBroker-1.1 under `Libs/` so this works with or without Titan/Socialite installed.
  - Left-click: open/close the window (same as the minimap button).
  - Hover: shows active listings (from the last right-click search) for the current zone's own activity (e.g. a dig site named after the zone) and, separately, for a dungeon activity tied to this zone, each with a group/solo count and up to 5 names.
  - Right-click: menu to search just the zone's activity, or just the zone's dungeon, opening the window with results - each only offered if one was found.

### Changed
- Titan LDB object type switched from "launcher" to "data source": Titan hardcodes launchers to start on the right side of the bar regardless of what the addon requests, while data sources default to the left/center side - so a fresh install now lands in the right spot without manual repositioning. (An already-placed icon keeps wherever you've dragged it; Titan remembers that per plugin regardless of type.)

### Fixed
- Reverted the hover-triggered background search: on this client it gets silently dropped (not a real click), leaving `ns.searching` stuck `true` forever and the tooltip stuck on "Searching...". `ns.Search()` now self-heals from this regardless of cause (12s timeout clears a stuck `ns.searching`), but hover itself no longer attempts a search - right-click remains the one reliable trigger. The tooltip now says "Not searched yet - right-click to search" instead of a flat "No active listings" so it's clear which is which; both the tooltip and the right-click menu already recompute the zone/dungeon match fresh every time (no caching), so they reflect zone changes as soon as you interact with them again.
- The dungeon match no longer uses each activity's `mapID` field - in testing it matched Gnomeregan/Dun Morogh while standing in Thousand Needles (a different continent), so it wasn't reliably scoped to the entrance zone on this server. Replaced with a static classic-Azeroth zone -> dungeon name table (see `ZONE_DUNGEONS` in Core.lua). `/lfg debugzone` now reports what it matched for your current zone instead of raw map IDs - let us know if any zone/dungeon pairing is wrong so the table can be corrected.
- Titan tooltip counts/listings now only include results within +/- 4 levels of the player (the main window opened via right-click search is unaffected - it still shows everything, filterable there as usual).

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
