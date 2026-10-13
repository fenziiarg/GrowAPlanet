# Phase 1 core

All seven balances belong to the server. Clients send only `Click` or `Ready` with exactly one argument.
The server accepts at most eight clicks in an immediate burst, then refills eight tokens per second.
An independent request bucket limits all messages to a burst of 16 and a refill of 12 per second.
Invalid payloads consume request capacity but never award resources. Rejection logs are throttled by category.
Snapshots are sent at most once per 0.25 seconds; click rewards are never predicted by the client.

## Numbers and economy

Balances are nonnegative normalized `{m, e}` values representing `m * 10^e`, with zero `{m=0,e=0}`.
The mantissa retains native double precision (approximately 15 significant digits); this is approximate
incremental-game arithmetic, not exact arbitrary-precision integer arithmetic. Tiny rewards can be below
representable precision beside a much larger balance. Exponents from -300 through 3000 are supported.
Invalid/nonfinite values and overflow are rejected before the server commits a changed balance table.
Suffixes run through Dc; larger values display scientific notation. Formatting is presentation only.

All balances start at zero. Proposed Phase 1 rates: +1 Growth Point per accepted click, +1 per online second.
The other six resources have zero baseline production until their earning systems are implemented.
Online production uses elapsed server time, not client timestamps or a presumed fixed frame rate.
No buildings, eras, planet visuals or offline income were added. Those belong to later approved phases.

## Saving

Official vendored ProfileStore owns session locks, autosaves, release writes and shutdown completion.
The adapter uses `StartSessionAsync` with cancellation on leave, shutdown or a 30-second load deadline.
It never uses `Steal`, the mock backend, reconciliation of invalid profiles, or a default-profile fallback.
Schema v1 contains `planets.home.resources`. New profiles use the template only when ProfileStore finds
no record; unknown versions or malformed balances are rejected without replacing existing data.

Studio uses `GrowAPlanet_Studio_v1`; live servers use `GrowAPlanet_Live_v1`. Player keys are `Player_<UserId>`.
Session loss removes access and kicks the player. PlayerRemoving and BindToClose end active sessions;
ProfileStore's own shutdown handler waits for final writes. Failed loads never enter the active-player map.
Studio must report DataStore access before loading: ProfileStore's automatic mock fallback is not allowed.

API reference: https://madstudioroblox.github.io/ProfileStore/api/ (checked alongside the pinned source).

## Planet growth (Phase 2)

`src/shared/Planet.luau` holds the pure rules; `src/shared/config/planet.luau` holds every number and look.
The client sends `("Grow", "Earth" | "Water")`; anything else is `malformed_intent`. The server checks the
growth rate limit, stage unlock, max level and price, then commits new balances and levels together.
Only levels are saved (`planets.home.growth = { earthLevel, waterLevel }`); stats are derived:

- Earth/Water Mass = level × massPerLevel.
- Total Size (km) = baseSizeKm × (1 + (Earth + Water Mass) / sizeMassStep)^(1/3).
- Stage = the highest stage whose Earth and Water minimums are both met. Masses never fall, so stages never drop.
- Price = baseCost × costGrowth^level Growth Points. Each level adds incomePerLevel Growth Points per second.

A stage increase prints `STAGE_UP <id>` and fires the `Notify` remote. Snapshots carry the derived stats and
prices. The client copies EarthMass, WaterMass, TotalSize and Stage onto one `HomePlanet` model. The renderer
rebuilds that model when Stage changes and calls `Model:ScaleTo` when TotalSize changes.
Each player renders only their own planet locally, at `viewCenter`.

Schema v2 adds the growth levels. A v1 record is upgraded on a copy and validated before it is applied to
the loaded profile. Malformed or unknown versions are released unchanged, as before.

## Development tests

`dev.project.json` includes TestEZ, the unit specs and `ServerStorage.GrowAPlanetTests.Debug`.
Play runs the suite and creates `ServerStorage.GrowAPlanetTests.Control`, a BindableFunction bridge, because MCP
`require` calls get an isolated module cache. Its commands are `Inspect(player)`, `Skip(player, seconds)`,
`Grow(player, id)`, `Simulate(seconds, clicksPerSecond)` and `Persistence()`.
`Simulate` is a bot run on in-memory data that buys whatever growth the next stage needs and reports when each
stage was reached. Its results are simulated, not human-verified. `Skip` is a bounded online reward advance.
Both are Studio-only and the module is absent from release output. No client debug remote exists.
`persistence()` uses a unique `Acceptance_` key in the Studio namespace to verify a real final save,
forced acquisition failure without overwrite, and reopen. It never resets a player profile.
Unit-test fakes are isolated test inputs, never live persistence substitutes.

Client connections and instances are cleaned up with Janitor. Per-player session connections are cleaned
on leave/session loss; shared listeners close on shutdown. One throttled server loop handles online income.
