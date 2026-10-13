# Phase 4 — Civilization and economy

Date: 2026-10-13. Scope: Phase 4 as revised by the owner's change request (commit dd71663, GAME_SPEC §5):
Human History ages, cities per region with socioeconomic stages, Kardashev milestones, and no named Earth stages.
Nothing from the Deferred list was built.

## 1. What was built

- **Earth stage names removed.** Barren Rock, Volcanic, Oceanic, Habitable and Mature World no longer appear in
  config or UI. The five growth thresholds remain as unnamed internal tiers (Tier1–Tier5) that still drive terrain
  and atmosphere. The Planet tab shows only Earth Mass, Water Mass, Total Size and growth income. Water now
  "unlocks at 800 Earth Mass". The stage-up toast is gone.
- **Human History ages:** 11 steps in 7 ages.
  - Stone Age: Paleolithic, Mesolithic, Neolithic. Metal Age: Copper, Bronze, Iron.
  - Then Middle Ages, Renaissance, Industrial, Information, and Silicon and AI.
  - Each step needs a planet population and a resource cost, and sets the income multiplier (×1 to ×5.5).
  - Founding the first city starts the Paleolithic.
  - Upgrade tree: 15 upgrades, about two per age, with prerequisites, e.g. Stone Tools → Smelting → Guilds →
    Steam Power → Smart Grid → Automation.
- **Cities per region.**
  - Founded on Grassland, Forest, Desert or Mountains, one per region, each further city costing ×1.8 more.
  - 20 buildings in total, 2–4 per age (`config/buildings.luau`), up to level 30. Costs are spread across all six
    spendable resources (Growth Points, Food, Materials, Energy, Money, Research).
  - Development (Σ level × points) sets the socioeconomic stage: Hunter-Gatherer → Horticultural and Pastoral →
    Agricultural → Industrial → Post-Industrial. The stage scales Money, Research and population.
- **Terrain-based production.** Each terrain has its own per-resource and housing multipliers (table in section 6).
- **Planet totals** are the sum of all cities × the current age multiplier × upgrade and Kardashev multipliers,
  plus the growth-level Growth Point income. Planet Population is the sum of city populations.
- **Kardashev Types I–III** are megaprojects: Orbital Habitat Ring (needs the Information Age), Stellar Lattice
  (Silicon and AI) and Galactic Rings (after Type II). Each multiplies production and changes the visuals:
  - Type I: a 72-segment ring with 12 lit habitats around the planet; it scales with the planet.
  - Type II: a star placed along the sun direction, with a geodesic lattice shell.
  - Type III: three galactic rings of 160 lit specks each.
- **Offline income.** It is calculated on rejoin from server time: 50% of production for up to 8 hours. A
  welcome-back toast shows the duration and whether it was capped.
- **Server validation and rate limits.** Five intents with exact argument counts (FoundCity, Build, AdvanceAge,
  BuyUpgrade, Kardashev). Region IDs must be integers 1–252. Validation covers city presence, terrain, age locks,
  max levels, prerequisites and affordability. Purchases share a rate limit (burst 10, refill 6/s), and every
  rejection is logged by category.
- **Save data.** Profile schema v4 adds civilization state. Population is derived from cities and validated on
  load, and city regions keep their terrain when water rises. v1–v3 records upgrade on a validated copy.
- **UI.**
  - Planet / Civilization tabs; the Civilization tab has the age, Advance button, upgrade tree and Kardashev project.
  - A working region panel: found city, build and upgrade, with costs and reasons.
  - Income per second shown on resources, city markers on the map, and toasts for age, Kardashev and offline income.
- **Tests and tools.**
  - 13 new unit tests (61 total).
  - A bot that plays the whole game (`tests/Bot.luau`, development only).
  - Debug tools: Grant, Offline, Act.
- **Blender Lab MCP installed and registered** as owner-approved tooling. I didn't use it for these visuals; see
  section 7.

## 2. Verified behavior

Evidence lives in `docs/evidence/phase-4/` (`acceptance-playtest.txt`, `bot-simulation.txt`,
`region-panel-city-ui.png`). Testing was local Studio Play; all 39 Studio scripts were checksum-matched to the repo.

| Item | Method | Evidence | Result |
|---|---|---|---|
| Format, lint, strict types, both builds, release isolation (Bot and ClientDebug absent) | `scripts/check.ps1` | `CHECKS_PASS` on the final tree | PASS |
| Unit tests: production formulas, terrain differences, city stages, age thresholds, upgrades, Kardashev gates, offline cap, v4 migration and validation | TestEZ in Play | `TESTS_PASS passed=61 failed=0` | PASS |
| Scripted simulation reaches each age and each Kardashev milestone, with logs | Bot, 12 h horizon, at 3 and at 0 clicks/s | `bot-simulation.txt`: all 11 ages and Types I–III reached | PASS (**simulated**) |
| Each age and milestone reached on the live server path | Scripted run using Act (the same `Service.act` as the remote), funded by test grants | AGE_UP for every age at its population threshold; Types I, II, III | PASS |
| Different terrains produce different outputs per the table | Unit test (same buildings on 4 terrains) | Food Grassland > Forest > Mountains; Materials highest on Mountains; ratio equals table ratio | PASS |
| Offline income below, at and past the cap (simulated timestamps) | Unit test, plus live `applyOffline` with 1 h / 8 h / 24 h | Credited 3,600 / 28,800 / 28,800 s; Money gained matches rate × time × 50% | PASS |
| Offline income on a real rejoin | Stop → 50 s → Play | `OFFLINE_INCOME seconds=51` | PASS |
| Every build and purchase validated server-side, including invalid region IDs, with logs | 17 invalid intents from the client datamodel | 17/17 rejected (7 `invalid_region`); REJECT lines per category; state unchanged | PASS |
| Rapid repeated requests | 30 Build intents in one frame | 14 `request_rate`, 6 `action_rate`, 10 accepted | PASS |
| UI end to end: select region → found city → build | Real map click, then real button clicks | `FOUNDCITY 39` → `AGE_UP Paleolithic` → `BUILD 39 HuntingCamp`, `BUILD 39 Hut`; panel screenshot | PASS (see section 4) |
| Rejoin keeps cities, buildings, age, upgrades, Kardashev | Stop → Play, server inspect | 3 cities, city 39 levels, age 11, Kardashev 3, 15 upgrades, population 51,347 restored | PASS (Studio namespace) |
| v3 → v4 migration | Existing Studio record loaded | `PROFILE_READY schema=4` | PASS |
| Kardashev visuals and city markers created | Client instance inspection after Type III | Ring 84 parts; star + lattice + 480 specks; 6 marker parts | PASS (instances only; see section 3) |

## 3. Untested assumptions

- **What the Kardashev visuals and city markers look like.** After Studio was restarted mid-session, every 3D
  capture came back black, in Play and in Edit mode, while GUI capture kept working. Instance counts prove the
  objects exist, but I have no screenshot of them. This is pending (section 8).
- **Pacing for a human player.** All pacing numbers come from the bot.
- **Phone and tablet layouts, touch, and the release build.** Not run.
- **Live servers.**
- **Long-session performance with many cities.** Rates are cached and recomputed only after a change, but not
  profiled.
- **Rejoin after the 3-city run is the only multi-city rejoin.**

## 4. Known bugs and limitations

- **Outside input during testing.** The city on region 39 was founded by a FOUND CITY click that didn't come from
  my test script; someone was using the Studio window, as in Phase 3. The rest of that UI flow (the build clicks)
  was scripted. The founding still ran through the real UI and server path.
- **Rojo had stopped running.** Studio was synced with the checksum-verified mirror instead.
- **Clicking barely affects pacing.** Growth Point clicks speed things up by about 1 minute (3 clicks/s vs idle);
  income dominates.
- **Late-game Materials are weak** compared with Money and Research, so they gate Kardashev II. That is intended,
  but it's a balance question.
- **The Studio test profile is now fully progressed.** It holds test grants of 1e20 per resource, age 11 and
  Kardashev 3. Live data was untouched.
- **The panels still cover the planet on narrow screens.** That's Phase 5.

## 5. Devices actually tested

Windows desktop, local Roblox Studio Play, one player. No physical phone or tablet, no emulation, no live server.

## 6. Economy snapshot

**Age gates** (population needed / cost / income multiplier):

| Age | Needs |
|---|---|
| Paleolithic | first city, ×1 |
| Mesolithic | 30 pop / 150 Food, ×1.1 |
| Neolithic | 70 / 500 Food + 30 Research, ×1.2 |
| Copper | 160 / 1.5K Food + 150 Research, ×1.35 |
| Bronze | 300 / 1.2K Materials + 500 Research, ×1.5 |
| Iron | 550 / 4K Materials + 1.5K Research + 600 Money, ×1.7 |
| Middle Ages | 1.5K / 25K Materials + 8K Money + 10K Research, ×2 |
| Renaissance | 4K / 90K Money + 75K Research, ×2.4 |
| Industrial | 9K / 450K Money + 360K Research + 360K Materials, ×3 |
| Information | 15K / 2M Money + 1.5M Research + 500K Energy, ×4 |
| Silicon and AI | 50K / 30M Money + 25M Research + 10M Energy, ×5.5 |

**Kardashev:**
- Type I: Information Age; 50M Materials, 20M Energy, 30M Money; Energy ×2, Money ×1.5.
- Type II: Silicon and AI; 100B Energy, 40B Research, 1.5B Materials; Energy ×3, Research ×2.
- Type III: 120T Research, 50T Energy, 40T Money; ×2 to Food, Materials, Energy, Money and Research.

**Terrain-to-production table** (multipliers; resources not listed are ×1):

| Terrain | Food | Materials | Energy | Money | Research | Housing |
|---|---|---|---|---|---|---|
| Grassland | 1.4 | 0.9 | 1 | 1.1 | 1 | 1.25 |
| Forest | 1.1 | 1.4 | 0.9 | 0.9 | 1.1 | 1 |
| Desert | 0.5 | 1.1 | 1.6 | 1 | 1 | 0.75 |
| Mountains | 0.6 | 1.7 | 1.2 | 0.9 | 1.2 | 0.7 |

Ocean, Ice, Basalt, Lava and Rock can't host cities.

**Socioeconomic stages** (development needed; Money / Research / population multipliers):

| Stage | Development | Money / Research / Pop |
|---|---|---|
| Hunter-Gatherer | 0 | 0.5 / 0.5 / 1 |
| Horticultural and Pastoral | 12 | 0.8 / 0.7 / 1.25 |
| Agricultural | 35 | 1 / 1 / 1.5 |
| Industrial | 110 | 1.6 / 1.5 / 2 |
| Post-Industrial | 260 | 2.5 / 2.5 / 2.5 |

**Other values:**
- City founding: 300 GP × 1.8^cities.
- Building costs grow ×1.17–1.18 per level, up to level 30.
- Offline income: 50% of production, 8 h cap.
- Purchase rate limit: burst 10, 6/s.

**Measured pacing** (bot, **simulated**, 3 clicks/s; idle in brackets) against GAME_SPEC §5:

| Milestone | Time | Target |
|---|---|---|
| First age (Paleolithic) | 3.8 min [4.5] | within 5 min — met |
| Industrial Age | 30.3 min [31.2] | within 1 h — met |
| Silicon and AI | 1.30 h [1.32] | — |
| Kardashev I | 1.39 h [1.41] | — |
| Kardashev II | 3.05 h [3.09] | — |
| Kardashev III | 9.6 h [9.8] | — |

## 7. Proposals needing owner approval

- **The age structure:** 11 steps, with sub-ages as purchasable milestones, the first one free with the first city.
  Plus the gates and multipliers above.
- **The 20 buildings, the 15-upgrade tree, and the terrain and stage tables** above.
- **Kardashev gates, costs and effects,** and the Type III target of about 10 hours.
- **Offline income** at 50% efficiency with an 8-hour cap.
- **Kardashev visuals are built from primitives,** not Blender meshes. A Blender model only reaches the game
  through Studio's 3D Importer, which needs your manual step and an asset upload. The Lab MCP is installed if you
  want sculpted rings later.
- **Growth tiers stay internal.** They're unnamed but still drive terrain and atmosphere. GAME_SPEC still lists
  "planet stages" under Never cut; I read that as the growth-driven planet change, which remains.

## 8. Blockers needing the owner

- [ ] Review this report and explicitly approve before Phase 5.
- [ ] Make Studio's 3D view render again: bring the window to the foreground, or check Studio's graphics after its
  restart. Then I can capture the Kardashev Type I–III and city-marker screenshots that are still pending.
- [ ] Reconnect Rojo (`./scripts/serve.ps1 -Development`, then Connect in the plugin) before Phase 5 edits.

## 9. Next phase proposal

After explicit approval only: Phase 5, UI, tutorial and audio. That means mobile-first layouts so panels stop
covering the planet, tooltips, settings (reduced motion, sound, music, effects quality), and the tutorial and
audio as the cut list allows. Work is stopped at this gate.
