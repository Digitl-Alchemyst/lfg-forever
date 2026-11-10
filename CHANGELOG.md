# Changelog

All notable changes to LFG Forever are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Declined Request to Join is now reflected in the UI: the row dims and its button shows "Declined" (disabled) instead of "Request".
- "Hide declined" filter checkbox (on by default) to hide groups whose leader already declined your request.
- `/lfg cleardeclined` and a per-row "Clear declined status" right-click option to forget a decline and try again.

### Notes
- There's no documented Blizzard event for a declined Request to Join, so this is detected by watching the system chat line the client prints when a leader declines, matched against names you're waiting on. If this client phrases that message differently, declines may go undetected automatically — use the manual "Clear declined status" / re-request flow in that case, and let us know the exact wording so detection can be tightened.

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
