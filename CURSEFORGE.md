# Short Description

Filterable LFG browser with Invite/Request-to-Join, minimap & Titan Panel integration, and declined-request tracking.

---

# Long Description

## LFG Forever

LFG Forever adds a filterable Looking For Group browser on top of the game's own LFG tool — filter by role (Tank/Healer/DPS), level range, and free text, then Invite or Request to Join straight from the results list. Open it with **/lfg**, **/groupfinder**, the minimap button, or the Titan Panel button.

The game's native Looking For Group window is left completely untouched — LFG Forever only reads from the `C_LFGList` API and never hooks or taints Blizzard's own LFG frames, so the original window keeps working normally through its usual menu button. Searches only start from a real button click or Enter key press (not timers), matching Blizzard's own anti-automation rules for this API.

## Features

- **Filters**: role (Tank / Healer / DPS), level range, and free text search
- **Invite / Request to Join**: act on results straight from the list
- **Suggest Invite**: if you're in a group but not the leader, the Invite button becomes "Suggest" and relays the invite to your group leader — the same built-in behavior as the social menu's Invite option. Auto-disables when your group or raid is full
- **Declined-request tracking**: if a group leader declines your Request to Join, the listing is marked "Declined" in the UI and can be filtered out with a "Hide declined" option
- **Minimap button**: draggable around the minimap edge, can be hidden
- **Titan Panel integration**: adds an LFG Forever button to your Titan bar, with the same hover/right-click behavior as the minimap button
  - Hovering either button shows active questing groups for your current zone and active dungeon groups for a dungeon in that zone, listed separately
  - Right-click to quickly search the zone's activity or its dungeon, or open the full browser
  - The Titan bar text shows a live group count for your current zone/dungeon at a glance
- **Zone entry notifications**: get a chat notice when you enter a zone with an available questing or dungeon activity (toggleable)
- **Settings menu**: reachable from the minimap/Titan right-click menu or a small gear icon on the browser window, covering zone notifications, minimap visibility, and more

## Commands

- `/lfg` or `/groupfinder` — open or close the browser
- `/lfg minimap` — show or hide the minimap button
- `/lfg reset` — recenter the browser window
- `/lfg cleardeclined` — forget all declined listings
- `/lfg zonenotify` — toggle zone entry notifications
- `/lfg help` — list all commands

## Credits

Created by: @Tri Chomez - Horde/PVP

Contributions by: @Aldamir Nocturna - Horde/PVP
