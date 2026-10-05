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

## Saving

Player data saves through [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (by loleris, Apache 2.0), vendored at `src/server/Vendor/ProfileStore.luau` with its license in `licenses/`. To test real saving in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services** (the place must be published). Without it, ProfileStore uses a mock store and nothing persists between play tests.
