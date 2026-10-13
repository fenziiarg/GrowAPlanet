# Phase 3 — Planet map and camera

Date: 2026-10-13 (UTC). Scope: Phase 3 only. No buildings, eras, production or offline income.
Region population and building fields exist in the saved data model but nothing changes them yet, except a
Studio-only debug tool used to test persistence.

## 1. What was built

- **Real regions covering the whole sphere.** 252 regions (240 hexagons, 12 pentagons) from a Goldberg polyhedron,
  the dual of a frequency-5 geodesic icosphere (`src/shared/RegionTopology.luau`).
  - *Why this approach:* near-uniform region sizes everywhere, poles included. Exact shared borders, so there are
    no gaps or overlaps. A neighbour graph for later systems. IDs that are deterministic and never change as the
    planet scales.
- **Terrain.** Nine terrain types: Barren Rock, Basalt Plain, Lava Field, Ocean, Grassland ("land"), Desert,
  Forest, Mountains, Ice Sheet.
  - Generated per planet from a saved seed (`src/shared/Terrain.luau`). Elevation and moisture come from seeded
    noise fields, ranked so each terrain's share is exact.
  - **Water Mass sets ocean coverage:** ocean share = clamp(2 × Water / (Earth + Water), 0, 0.62), filled from the
    lowest regions up. More water raises the sea; more earth lowers it.
  - Stage rules: Barren is all rock. Volcanic is basalt and lava. Oceanic adds sea. Habitable adds polar ice,
    mountains, deserts and grassland. Mature World adds forests.
  - Developed regions (any building) keep their terrain when water rises, ready for Phase 4.
- **Rendering.** Each region is its own Model of flat triangles (1,992 wedge parts), coloured by terrain. Thin
  dark borders are drawn by one wireframe adornment. The atmosphere and Mature World clouds can't intercept clicks.
  The same attribute-driven planet model still scales with Total Size.
- **Strategic camera** (`src/client/StrategicCamera.luau):
  - Trackball rotation about the camera's own axes, so it passes over the poles with no gimbal lock.
  - Smooth log-space zoom between 1.3× and 4.4× the planet radius, so framing follows the planet as it grows.
  - Mouse: drag with either button, wheel zoom. Keyboard: WASD/arrows rotate, Q/E or +/- zoom.
    Touch: one-finger drag, pinch zoom.
  - A client-only fill light keeps the night side readable. Avatars are disabled; this is a strategic view.
- **Hover and click selection by real raycast** (`src/client/RegionPicker.luau`). At most one ray per frame,
  filtered to region parts, then an indexed part → region lookup. A white highlight shows hover, a gold one
  selection. The placeholder region panel shows region ID, terrain and population, with a close button.
  Pointer hover is ignored over UI.
- **Region data saved with stable IDs.** Schema v3 adds `regions = { topologyVersion, seed, terrain (1 char per
  region), population, buildings }`, with sparse maps keyed by region ID. Invalid IDs, values and terrain codes
  are rejected. v1/v2 profiles get a fresh seed and generated terrain on load.
- **Tests and tools.** 10 new unit tests (48 total). Studio-only tools: `SetGrowth`, `SetPopulation`, and a
  development-only client bridge (`tests/ClientDebug.client.luau`). `check.ps1` asserts the bridge is absent from
  the release build.

## 2. Verified behavior

Evidence lives in `docs/evidence/phase-3/` (`acceptance-playtest.txt` plus screenshots). Testing was local Studio
Play with the owner's Rojo development server. All 31 Studio scripts were checksum-matched to the repo before
each session.

| Item | Method | Evidence | Result |
|---|---|---|---|
| Format, lint, strict types, both builds, release isolation | `scripts/check.ps1` | `CHECKS_PASS` on the final tree | PASS |
| Unit tests | TestEZ in Play | `TESTS_PASS passed=48 failed=0` | PASS |
| No gaps or overlaps (topology) | Unit tests | Every border shared by exactly 2 regions; V−E+F = 2; areas sum to 4π (±1e-6) | PASS |
| No gaps (geometry) | 4,000 random inward rays against the rendered regions | 0 misses; 0 owner mismatches away from borders (94 within 0.004 of a border) | PASS |
| Every region reachable, poles and back side included | Camera faced each region; raycast through screen centre | 252/252 at mid zoom and at closest zoom; poles are regions 24 and 173 | PASS |
| Scripted clicks at known screen positions return matching IDs | Real `user_mouse_input` clicks at projected region centres (front, south pole, back) | 20/20 on clean runs; raycast matched independent sphere math at all 21 checked pixels | PASS (see section 4) |
| Drag, wheel, keyboard | Mouse and keyboard input tools | Drag rotated without selecting; wheel 0.60→0.36; D rotated; Q 0.36→0.60 | PASS |
| Over the poles with no gimbal lock | W held in steps | Camera direction crossed the north pole and continued down the far side with no flip | PASS |
| Hover highlight | Client state during pointer moves | Hovered ID followed the pointer | PASS |
| Region data survives rejoin | Population 1,234 set on region 207; stop → start | Same seed, terrain checksum `a2a2de6a`, population {207: 1234} | PASS (Studio namespace) |
| Regions at all 5 stages, scaling with the planet | Fixed world camera, plus the strategic camera, at each threshold | `stage-1…5-*-fixed-camera.png` (radius 20 → 83 studs) and `*-strategic.png` | PASS |
| Three zoom levels | Strategic camera at zoom 1 / 0.5 / 0 | `zoom-max-whole-planet.png`, `zoom-mid.png`, `zoom-min-closest.png` | PASS |
| Frame rate at 252 regions | Client frame times while spinning, 8 s per zoom | 60 fps average (Studio cap), p95 17.8 ms, worst 19.3 ms | PASS (this desktop only) |

## 3. Untested assumptions

- **Phone performance and phone/tablet layouts.** No physical device and no emulator run. The 60 fps figure is
  this Windows desktop in Studio, capped at 60.
- **Touch drag, pinch and tap.** The code exists, but Studio MCP cannot send touch input.
- **Frame cost of a growth purchase.** Each growth rescales about 2,000 parts and redraws 750 border lines. The
  hitch was not measured.
- **Release build and live servers.**
- **Long sessions and leaks.** Not measured.

## 4. Known bugs and limitations

- **One click run was invalidated by outside input.** During the back-side run, someone was using the Studio window:
  9 growth purchases and 3 clicks reached the server that the test never sent, and the camera zoom changed. Two of six
  clicks missed in that run; the clean re-run passed 6/6. I counted only clean runs.
- **The phone layout still covers most of the planet.** Phase 5 work, as in Phase 2.
- **Flat facets differ slightly from curved borders.** Very close to a border (nearest-centre dot-product gap below 0.004),
  the clicked region can be the neighbour of the mathematically nearest centre (2.4% of random samples, all at borders). Selection always
  matches what is drawn, because it raycasts the drawn geometry.
- **Water barely changes the sea once capped.** Mature World is about 59% ocean plus polar ice. Water beyond the
  0.62 cap only adds size.
- **Phase 2's ball-based looks are gone.** Stage looks now come from region terrain plus the atmosphere and clouds;
  this is intended.
- **The Studio test profile was edited.** `SetGrowth` stepped it through every stage and restored Earth 45 /
  Water 34. Region 207 has test population 1,234. Live data was untouched.
- **`user_mouse_input` uses GUI coordinates** (viewport minus the 58 px top inset). This is noted for future tests.

## 5. Devices actually tested

Windows desktop, local Roblox Studio Play, one player, 1360×441 viewport. No physical phone or tablet, no device
emulation, and no published live server.

## 6. Economy snapshot

No economy changes in Phase 3; Phase 2 values stand. New config:

| Key | Value |
|---|---|
| Regions | frequency 5 → 252 regions, topologyVersion 1 |
| Ocean share | clamp(2 × Water / (Earth + Water), 0, 0.62) |
| Terrain rules | Volcanic lava 18%, Oceanic lava 5%, mountains 10%, ice at ≥66° latitude, desert where moisture ≤0.30 within 38° of the equator, forest where moisture ≥0.62 (Mature World) |
| Camera | zoom 1.3–4.4 radii, FOV 50, wheel step 0.08, drag 0.006 rad/px at widest |

Terrain at each stage threshold (seeded test planet): Barren 252 Rock. Volcanic 206 Basalt / 46 Lava.
Oceanic 137 Ocean / 102 Basalt / 13 Lava. Habitable 148 Ocean / 44 Grassland / 22 Mountains / 20 Ice / 18 Desert.
Mature World as Habitable, but 36 Grassland and 8 Forest.

## 7. Proposals needing owner approval

- **Region count 252** (frequency 5). It measured at the 60 fps cap on desktop. Options: 162 regions if phones
  struggle, or 362 for finer provinces.
- **The Goldberg-polyhedron region approach**, rendered with parts and picked by raycast.
- **The nine terrain types, the generation rules and the ocean-share formula** above.
- **Disabling avatars** for the strategic view.
- **The Phase 4 production table** has not been designed yet. `productionMultipliers` stays empty until then.

## 8. Blockers needing the owner

- [ ] Review this report and explicitly approve before Phase 4 begins.
- [ ] Optional: a phone test (physical or Studio device emulation) to confirm touch controls and the region count
  on mobile hardware.

## 9. Next phase proposal

After explicit approval only: Phase 4, civilization and economy. That means six eras, at least two buildings per
era built per region, terrain-based production (I'll propose the table), planet totals, era advancement and capped
offline income, all validated server-side including region IDs. Work is stopped at this gate.
