# Anomaly Hunter

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

## Saving

Player data saves through [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (by loleris, Apache 2.0), vendored at `src/server/Vendor/ProfileStore.luau` with its license in `licenses/`. To test real saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it, ProfileStore uses a mock store and nothing persists between play tests.

## Robux purchases

Everything sold for Robux is in `src/shared/Config/Robux.luau`: 9 Developer Products (5 shop item price tiers, Shop Reroll, Mission Reroll, Mission Skip, Starter Pack) and 4 Game Passes. Create each one on the Creator Dashboard (your game > Monetization > Developer Products or Passes) and paste its id over the `0` in that file. Anything still at `0` shows "Robux · soon" in the game. `server/Services/RobuxService.luau` handles `ProcessReceipt`: every purchase id is saved in the player's profile and only marked granted once that save is written, so a purchase is never paid out twice or lost. Purchases in Studio are free test purchases.

## Sound and music

All sounds are made by `tools/sound/make_sounds.py` (needs Python 3 with numpy and scipy, plus ffmpeg): they are synthesized from scratch, so nobody else owns them, and the music is our own rendition of public-domain classical pieces (Grieg, Beethoven) plus two songs of our own. Very famous melodies get rejected by Roblox audio moderation, so avoid those. Run it to write the eight files to upload into `tools/sound/out` (it also rewrites `src/shared/Config/SoundSheets.luau`).

Roblox can't read sound files from the repo. Upload each `.ogg` once (Creator Hub > Development Items > Audio, with the same owner as the game) and put its asset id in `src/shared/Config/Sounds.luau`. Until then that sound is silent and Studio's Output lists what is missing. `client/Controllers/SoundController` plays the music as one server-wide playlist and the event sounds, and switches off the default walking sound. `client/Controllers/MonsterVoiceController` makes a nearby monster call out now and then (`Sounds.MonsterCalls`).
