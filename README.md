# Grow a Planet

Roblox progression simulator. Phase 1 added the server resource engine, safe save sessions and a minimal test HUD.
Phase 2 added planet growth: Earth/Water purchases, five visual stages and an attribute-driven planet model.
Phase 3 adds the strategic view: 252 raycast-picked regions, generated terrain and a trackball camera.
Read AGENTS.md, GAME_SPEC.md and PHASE_PROMPTS.md before working. Each phase requires owner approval.

## Development

From this repository, run `./scripts/bootstrap.ps1`, then `./scripts/check.ps1`.
Start `./scripts/serve.ps1 -Development` and connect Studio's Rojo plugin to localhost:34872.
Play in Studio to run the development-only TestEZ suite. Use `./scripts/serve.ps1` for the release mapping.
Real Studio API access is required to join safely; there is no mock-save gameplay fallback.

- `src/server`, `src/client`, `src/shared/config`: source of truth for game code.
- `vendor/ProfileStore`: pinned official server-only persistence dependency.
- `tests`: Studio-only pipeline check; excluded from release builds.
- `assets`: original editable Blender source, FBX export and reproducible scripts.
- `docs/SETUP.md`: versions, installation and verification instructions.
- `docs/UI_NOTES.md`, `docs/ASSET_MANIFEST.md`: UI decisions and provenance.
- `docs/ENGINE.md`: numeric precision, resource authority, save lifecycle and debug tools.
- `docs/OWNER_SETUP.md`, `docs/reports/`: owner actions and per-phase evidence reports.

The approved place is 94365962623582, universe 10770529946. Do not connect to another experience.
Nothing in this repository authorizes public publication or purchases.
