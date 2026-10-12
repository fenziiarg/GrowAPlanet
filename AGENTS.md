# AGENTS.md: Standing Rules for "Grow a Planet"

You are building **Grow a Planet**, a Roblox progression simulator with a Hearts of Iron 4-style strategic view, except the map is a planet. The player grows a barren rock into a living world, then develops its regions into a modern civilization. The full design is in `GAME_SPEC.md`. The work is split into phases in `PHASE_PROMPTS.md`. These rules apply to every phase and never expire.

Act as game designer, Luau engineer, technical artist, UI designer, and QA tester. Implement the real game with the connected tools, playtest it, and fix what you find. Do not stop at a design document, scaffolding, or a prototype.

---

## 1. Hard rules (never break these)

1. **Never overwrite or modify the existing "horns" project, the Roll & Grow project, or any unrelated asset.** Build the game in a separate, isolated place and repo.
2. **Never invent product, gamepass, asset, or universe IDs.** If something cannot be created with an authorized tool, add it to `docs/OWNER_SETUP.md` as a precise checklist item.
3. **Never spend money.** No credits, Robux, marketplace assets, subscriptions, paid AI model generation, or anything paid. If something would cost money, stop and report it as blocked.
4. **Never claim something is finished unless you tested it.** See section 6 (reporting).
5. **Stop at the end of every phase** and wait for the owner's approval (section 5).
6. **Do not expand scope.** Work only on the current phase. Never build anything on the Deferred list in `GAME_SPEC.md`, and do not start the next phase "while you're at it".
7. **The server is authoritative for everything that matters:** resources, region state, builds and upgrades, era advancement, offline income, ownership, saves. Never trust client-provided values.
8. **Never fake a system.** A stub, placeholder, or mock counts as NOT done. A plain orbiting camera around a textured sphere is not the planet map, and 2D buttons laid over the screen are not clickable regions. If you cannot build the real thing, report it as blocked.

---

## 2. Tools

Inspect all available tools and the current Studio place before changing anything. Report what is connected and what is missing.

| Tool | Use |
|---|---|
| **Roblox Studio MCP** | Inspecting and testing the experience, playtesting, screenshots, camera and click simulation where supported. |
| **Rojo + GitHub** | **Source of truth for all Luau code.** Code lives as files in the repo and syncs into Studio. Commit after every milestone with clear messages. |
| **Blender MCP** | Original models (planet, props, terrain pieces), mesh cleanup, UVs, materials, collision prep, optimization. Keep `.blend` sources in the repo. |
| **Free asset sourcing** | Original Blender models first, then verified free assets in the order specified in section 3. |
| **Check-UI-Clean-Roblox** | UI foundation: https://github.com/TemporaryLooker22/Check-UI-Clean-Roblox. Read its `SKILL.md`, `DESIGN_SYSTEM.md`, source modules, and examples **before writing any UI**. Adapt its design language into one cohesive interface. |
| **Free UI sources (GitHub and web)** | All UI is built from free resources: Check-UI first, then free open-source Roblox UI libraries and component kits, free UI kits, icon packs, and fonts found on GitHub or the web. License rules in section 3 apply. |

**Recommended toolchain (set up in Phase 0, record versions in `docs/SETUP.md`):**
- **Rokit** (or Aftman) to pin tool versions.
- **Wally** for Luau dependencies.
- **ProfileStore** (MadStudio) for session-locked, safe player data. Do not hand-roll data persistence.
- **StyLua** (format), **Selene** (lint), **luau-lsp** (type checking).
- **Jest-Lua or TestEZ** for unit tests on pure logic: big-number math and formatting, era thresholds, production formulas, offline income, purchase validation.
- **Free open-source UI library (optional):** if Check-UI alone is not enough, evaluate free libraries such as Fusion or React-Lua. Check the license and fit first, and record the choice in `docs/UI_NOTES.md`.

For every third-party dependency: check the license, record it in `docs/ASSET_MANIFEST.md`, and inspect for unexpected scripts.

---

## 3. Free asset sourcing and asset rules

Everything is free. Use these sources in priority order:

1. **Blender-built original models:** the default for the planet, props, and buildings. Keep editable `.blend` sources and production exports in the repo.
2. **Roblox Creator Store:** free models and audio only when the creator's license explicitly permits commercial use. Record the asset ID, creator, source URL, and license evidence. A free price alone is not license evidence.
3. **CC0 or public-domain models:** sites that clearly state the license for the selected asset, such as Poly Haven, Kenney, OpenGameArt, or Sketchfab filtered to CC0. Verify each asset individually.
4. **CC-BY models:** allowed only when the required credit can be shown in the game's credits. Record the exact license version, source and license URLs, author, required attribution text, and modifications. Ship the attribution in the in-game credits before using the asset in a release.
5. **Open-source GitHub code and assets:** permissive licenses only (MIT, Apache-2.0, BSD, CC0). Record the license and keep its notice.

**UI sources.** All UI (layouts, components, icons, fonts, images) is built from free resources found on GitHub or the web, plus original work. Build on Check-UI-Clean-Roblox first, then fill gaps from other free sources:
- Open-source Roblox UI libraries and component kits on GitHub (permissive licenses only).
- Free UI kits and icon packs with CC0 or permissive licenses (for example Kenney UI packs or Lucide icons; verify each one individually).
- Free fonts with a clear commercial-use license (SIL OFL or equivalent). Roblox's built-in fonts are always allowed.
- Never use paid UI kits, UI ripped from other games, or assets with non-commercial, no-derivatives, or unknown licenses.
- Uploading a free-licensed image to Roblox is allowed. Record the resulting asset ID and never invent one. If an upload would cost money, stop and report it as blocked.
- Log every UI source in `docs/ASSET_MANIFEST.md` and summarize the choices in `docs/UI_NOTES.md`.

Rules for every asset:

- Never use non-commercial licenses (including CC-BY-NC and CC-BY-NC-SA), no-derivatives (ND) licenses, or unknown licenses. Do not download anything paid.
- If the license is unclear, skip the asset and use an original Blender fallback. If Blender or import fails, use original stylized primitives; do not block a phase on art.
- Inspect every imported model for scripts, hidden objects, and unexpected content. Remove them before integrating the model, and record the audit result. Never execute imported model scripts to inspect them.
- Log every asset in `docs/ASSET_MANIFEST.md` with source URL, author/creator, license and evidence, date checked, and where it is used. Record original assets with their repo source paths and authorship. Do not invent IDs or license claims.
- Audio must be free and have verified permission for commercial use, recorded in the same manifest.
- Reuse meshes and materials, and keep collision geometry simple.
- **Blender crash prevention:** never use `bpy.data.libraries.write` or scene-copy operations. Build assets with a standalone script in a fresh background Blender process, save with `bpy.ops.wm.save_as_mainfile`, and export FBX or glTF. Reopen the saved blend and reimport the exports in a separate background process before treating the Blender step as verified. After a crash, inspect repo blend files for changes or corruption before running another build.

---

## 4. Code and security standards

- Modular, typed Luau where practical. Clear separation: `src/server`, `src/client`, `src/shared`.
- All economy values and formulas live in **central config modules** under `src/shared/config`. No magic numbers in gameplay code.
- Validate and rate-limit every remote. Reject malformed input, including invalid region IDs. Handle rapid repeated requests.
- Persist **versioned** player profiles. Prevent duplicate session writes. If a profile fails to load, **never overwrite it with empty defaults**; kick or retry safely.
- Save on leave and on server shutdown (`BindToClose`).
- Region data is saved compactly (terrain, population, building levels per region) and region IDs stay stable as the planet grows.
- No full-map scans every frame. Region picking uses raycasts and indexed lookups.
- Clean up connections and instances to avoid leaks (use a Janitor/Maid pattern).
- Run StyLua, Selene, and type checks before every commit.

---

## 5. Phase gates

Work happens in phases (see `PHASE_PROMPTS.md`). At the end of each phase:

1. Make sure everything is committed to GitHub.
2. Produce the **phase report** (section 6).
3. **Stop and wait for explicit owner approval** ("approved") before starting the next phase. Do not plan ahead or start the next phase while waiting.

Make routine implementation decisions yourself within the spec. Choose balance numbers, region count, terrain types and the terrain-to-production table yourself, put them in config, and list them in the report as **proposals** for the owner to approve. Ask the owner only when blocked by missing access, spending limits, or a genuine product conflict. Finish everything you can do independently before asking for owner-only actions.

---

## 6. Phase report format (required every phase)

Write to `docs/reports/phase-N.md` and summarize in chat:

1. **What was built** (short list).
2. **Verified behavior**: a table of each item tested, how it was tested (Studio playtest, unit test, scripted test, screenshot), the evidence, and the result.
3. **Untested assumptions**: anything not actually tested. Say so plainly. If you could not observe it, it goes here, never under Verified. Never write "should work" under Verified.
4. **Known bugs and limitations.**
5. **Devices actually tested.** Studio emulation is **not** a physical mobile device. State which real devices, if any, were used.
6. **Economy snapshot**: current key values from config and measured pacing against targets.
7. **Proposals needing owner approval**: balance numbers, region count, terrain types and production table, any spec deviations or cuts (following the cut list in `GAME_SPEC.md`).
8. **Blockers needing the owner**, as a short checklist.
9. **Next phase proposal.**

Never describe a placeholder, a failed asset import, or an untested system as finished.

---

## 7. Scope guardrails for this build

- No monetization in v1: no gamepasses, developer products, receipt handling, or price UI.
- No tabs, buttons, menus or "coming soon" screens for deferred features.
- Planet logic is per-planet-instance and player data is versioned and namespaced, so deferred systems can be added later. Do not write code for them.
- Debug tools (time-skip, autoplay, simulation bots) must be disabled in release builds.

---

## 8. Definition of "done" for the whole project

Every system in the current scope works, is tested, and is honestly reported. No dead buttons, fake counters, placeholder behavior, or unfinished panels in a release build.
