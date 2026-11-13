# Hunt a Monster

_Formerly "Anomaly Hunter" (the repository and Rojo project keep that name)._

A Roblox ghost-hunting game: catch monsters in haunted zones, let them haunt your mansion to raise their value, sell them, and upgrade your mansion to reach deeper zones.

The full design lives in the concept doc. Everything you can tune (monsters, rarities, sizes, effects, shop items, wings, Watcher events) is a config table in `src/shared/Config`.

## Setup

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder. That installs Rojo, Selene and StyLua at the versions in `aftman.toml`.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve` and click Connect in the Studio plugin. Code edits sync into Studio live.

Models, maps and UI are built in Studio. Code lives here.

## Layout

| Folder | Ends up in | What goes there |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | Config tables and helpers used by server and client |
| `src/server` | ServerScriptService.Server | Services: data, catching, shops, events |
| `src/client` | StarterPlayerScripts.Client | UI and input |
| `tests` | not synced | Plain-Luau checks for config and value math |

Shared modules use string requires (`require("../Config/Effects")`), so they run both in Roblox and in the plain Luau CLI.

## Checks

```
luau tests/run.luau
selene src
stylua --check src
```

### Cheat and save checks in Studio

Studio only (they do nothing in a live game). Press **Play** (F5), not Run, and open **Window > Command Bar** and **Window > Output**. The Test tab's Client/Server button picks where the command bar runs.

1. Server view: `game.ServerScriptService.Server.Tests.Setup:Fire()` (skips the tutorial, tops you up to $1M, gives 4 test monsters).
2. Client view, standing in your mansion: `require(game.Players.LocalPlayer.PlayerScripts.Client.Tests.ExploitChecks).run()` (add `"deep"` to also race two requests at once).
3. Server view: `workspace:SetAttribute("TestAsPlayer", true)`, then back in the Client view `require(game.Players.LocalPlayer.PlayerScripts.Client.Tests.ExploitChecks).run("admin")`.
4. Server view: `game.ServerScriptService.Server.Tests.RunChecks:Fire()` (admin rules, every remote, every save, and any server error the cheat tests caused).

`TestAsPlayer` on Workspace (a Boolean attribute) makes nobody an admin in Studio. A new remote must be added to `KnownRemotes` in `src/server/Tests/ServerChecks.luau` and to the lists in `src/client/Tests/ExploitChecks.luau`.

### Movement anti-cheat

`src/server/Services/MovementService.luau` checks every player 4 times a second (rules in `src/shared/Util/Movement.luau`, numbers in `src/shared/Config/Movement.luau`): walking faster than the hub speed allows (Faster walking speed pass included), teleporting, rising higher than a jump, and hovering. A cheater is put back on the last spot they stood on; 12 pull-backs in 30 s is a kick (`KickStrikes = 0` turns kicking off). Output shows a `MovementService: pulled ... back` line for each one. Anything the game moves on purpose calls `MovementService.excuse` first (`PlotService.teleport` for portals, Return Charm, fast travel and spawning; the fall rescue; slaps; monster knockbacks), so a new teleport or push must do the same.

Test it in the Client view: `require(game.Players.LocalPlayer.PlayerScripts.Client.Tests.ExploitChecks).run("movement")`.

## Saving

Player data saves through [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (by loleris, Apache 2.0), vendored at `src/server/Vendor/ProfileStore.luau` with its license in `licenses/`. To test real saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it, ProfileStore uses a mock store and nothing persists between play tests.

## Codes, Lucky Spin and leaderboards

- **Codes**: players type them in Settings > Codes. The list is `src/shared/Config/Codes.luau`; each code works once per player. Add a new one there (capitals and digits only) and post it on the game page or group wall; set `ended = true` to retire one.
- **Lucky Spin**: the wheel button on the left. One free spin a day, plus one after 15 and 45 minutes of play. Prizes and odds are in `src/shared/Config/Spin.luau`. It is never sold for Robux. Admins: F2 > Playtime > "Spins back", or `/spins`.
- **Leaderboards**: two boards next to Watcher Square ("Richest Hunters" and "Top Collectors"), ranked across all servers. They need **Enable Studio Access to API Services** to show anything in Studio, and Studio scores go to separate boards from the live game.

## Rebirth and rare catch shout-outs

- **Rebirth** (`server/Services/RebirthService.luau`, numbers in `src/shared/Config/Rebirth.luau`): once every wing is owned, the expand sign turns into a REBIRTH sign. With $10B (x4 for each next one) a player can start over: money, wings and every monster reset; tools, items, cakes (packed back into the hotbar), the Codex, badges and Robux purchases stay. Each rebirth adds +50% to what the Collector pays (added to the other sell bonuses), and the player list gets a Rebirths column. Studio: `/wings 6`, `/money 10000000000`, then press E at the sign; `/rebirths <n>` sets the count without a reset.
- **Rare catches** (`server/Services/RareCatchService.luau`, levels in `src/shared/Config/RareCatch.luau`): Epic and up gets a reveal card for the catcher; Mythic, Nightmare and any Rainbow gets a banner and a chat line for the whole server; Divine, Eldritch and a Rainbow Mythic also show in the chat of every other server (MessagingService, so only in a published game).

## Robux purchases

Everything sold for Robux is in `src/shared/Config/Robux.luau`: 15 Developer Products (5 shop item price tiers, Shop Reroll, Mission Reroll, Mission Skip, Starter Pack, 6 Steal products) and 5 Game Passes. Create each one on the Creator Dashboard (your game > Monetization > Developer Products or Passes) and paste its id over the `0` in that file. Anything still at `0` shows "Robux · soon" in the game. `server/Services/RobuxService.luau` handles `ProcessReceipt`: every purchase id is saved in the player's profile and only marked granted once that save is written, so a purchase is never paid out twice or lost. Purchases in Studio are free test purchases.

### Stealing monsters

Hold E on a monster roaming another player's mansion to steal it for Robux (`server/Services/HeistService.luau`, rules in `src/shared/Util/Heists.luau`, numbers in `src/shared/Config/Heists.luau`). The price is one of the six `Steal1`-`Steal6` products in `Config/Robux.luau`, by what the monster is worth; a hearted monster costs a step more. Once paid it moves straight into the thief's mansion with its Familiarity back at 0. Players in the tutorial or their first 2 hours, and players already robbed twice that day (or once by the same thief), are safe. In Studio the 2-hour shield is off, so stealing can be tried with Test > Clients and Servers (2 players).

## Sound and music

All sounds are made by `tools/sound/make_sounds.py` (needs Python 3 with numpy and scipy, plus ffmpeg): they are synthesized from scratch, so nobody else owns them, and the music is our own rendition of public-domain classical pieces (Grieg, Beethoven) plus two songs of our own. Very famous melodies get rejected by Roblox audio moderation, so avoid those. Run it to write the eight files to upload into `tools/sound/out` (it also rewrites `src/shared/Config/SoundSheets.luau`).

Roblox can't read sound files from the repo. Upload each `.ogg` once (Creator Hub > Development Items > Audio, with the same owner as the game) and put its asset id in `src/shared/Config/Sounds.luau`. Until then that sound is silent and Studio's Output lists what is missing. `client/Controllers/SoundController` plays the music as one server-wide playlist and the event sounds, and switches off the default walking sound. `client/Controllers/MonsterVoiceController` makes a nearby monster call out now and then (`Sounds.MonsterCalls`).
